import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_services.dart';
import '../../core/theme/ascend_theme.dart';
import '../../domain/models.dart';

class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});
  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  late Future<_PlanData> _future;
  int? _selectedDay;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PlanData> _load() async {
    final services = ref.read(appServicesProvider);
    final repository = services.repository;
    var plan = await repository.getLatestPlan();
    final preferences = await repository.getPreferences();
    if (plan == null) {
      if (!preferences.onboardingComplete || preferences.goals.isEmpty) {
        return const _PlanData(null, 0, {});
      }
      final isPro = (await services.subscriptions.refreshStatus()).isPro;
      plan = services.coach.createPlan(preferences: preferences, startDate: DateTime.now(), isPro: isPro);
      await repository.savePlan(plan);
    } else if ((await services.subscriptions.refreshStatus()).isPro && !plan.isProPlan) {
      // Pro expansion creates a new encrypted plan; the earlier plan remains retained.
      plan = services.coach.createPlan(
        preferences: preferences,
        startDate: DateTime.now(),
        planId: 'plan-${newLocalId()}',
        isPro: true,
      );
      await repository.savePlan(plan);
    }
    final progress = plan.tasks.where((task) => task.state == TaskState.completed).length;
    final rate = plan.tasks.isEmpty ? 0.0 : progress / plan.tasks.length;
    final milestoneData = await repository.readSetting('milestones');
    final raw = milestoneData?['completed'] as List? ?? const [];
    return _PlanData(plan, rate, raw.whereType<String>().toSet());
  }

  Future<void> _reload() async {
    setState(() { _working = true; _error = null; _future = _load(); });
    try { await _future; } on Object { if (mounted) setState(() => _error = 'Plan data could not be loaded. Your saved data was not changed.'); }
    finally { if (mounted) setState(() => _working = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('90-day plan'), actions: [
      IconButton(tooltip: 'Plan information', onPressed: () => context.push('/privacy'), icon: const Icon(Icons.info_outline)),
    ]),
    body: FutureBuilder<_PlanData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError || snapshot.data == null) return _message(context, 'Plan unavailable', 'Your local plan could not be decrypted. Existing data was preserved.', action: _reload);
        final data = snapshot.data!;
        final plan = data.plan;
        if (plan == null) return _message(context, 'Choose your goals first', 'Complete onboarding before generating a personal plan.', action: () => context.go('/onboarding'));
        final today = DateTime.now();
        final computedDay = DateTime(today.year, today.month, today.day).difference(DateTime(plan.startDate.year, plan.startDate.month, plan.startDate.day)).inDays + 1;
        final day = _selectedDay ?? computedDay.clamp(1, 90).toInt();
        final tasks = plan.tasks.where((task) => task.dayIndex == day).toList(growable: false);
        final phase = day;
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
            children: [
              Text('A plan that adapts to real life.', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text('Missed days are recoverable. Choose any past day and continue without losing your history.', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              _progressCard(context, data),
              const SizedBox(height: 18),
              _phaseCard(context, phase),
              const SizedBox(height: 16),
              _milestoneSection(context, data),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: Text('Daily routine', style: Theme.of(context).textTheme.titleLarge)),
                DropdownButton<int>(
                  value: day,
                  underline: const SizedBox.shrink(),
                  items: [for (var index = 1; index <= 90; index++) DropdownMenuItem(value: index, child: Text('Day $index'))],
                  onChanged: (value) => setState(() => _selectedDay = value),
                ),
              ]),
              const SizedBox(height: 8),
              if (tasks.isEmpty)
                _message(context, 'Rest day', 'There are no tasks scheduled for this day. Return whenever you are ready.')
              else
                for (final task in tasks) _taskCard(context, task),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: AscendColors.error))),
              const SizedBox(height: 12),
              Text('Recommendations are general habit guidance, not medical advice. Adjust or skip any task that does not fit your needs.', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        );
      },
    ),
  );

  Widget _progressCard(BuildContext context, _PlanData data) {
    final plan = data.plan!;
    final completeDays = plan.tasks.where((task) => task.state == TaskState.completed).map((task) => task.dayIndex).toSet();
    final longest = _longestStreak(plan.tasks);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AscendColors.surface, borderRadius: BorderRadius.circular(AscendRadii.card), border: Border.all(color: AscendColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${(data.completionRate * 100).round()}% of planned tasks completed', style: Theme.of(context).textTheme.titleMedium)),
          const Icon(Icons.trending_up, color: AscendColors.gold),
        ]),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: data.completionRate, minHeight: 8, backgroundColor: AscendColors.border, color: AscendColors.gold)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Text('${completeDays.length} routine days with completed tasks', style: Theme.of(context).textTheme.bodyMedium)),
          Text('Longest streak: $longest', style: Theme.of(context).textTheme.bodyMedium),
        ]),
      ]),
    );
  }

  Widget _phaseCard(BuildContext context, int day) {
    final phase = day <= 30 ? 'Foundation' : day <= 60 ? 'Development' : 'Consistency';
    final range = day <= 30 ? 'Days 1–30' : day <= 60 ? 'Days 31–60' : 'Days 61–90';
    final copy = day <= 30
        ? 'Keep the first habits small and easy to repeat.'
        : day <= 60
            ? 'Refine the routines that fit your preferences and schedule.'
            : 'Build consistency around the parts that feel sustainable.';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AscendColors.surfaceRaised, borderRadius: BorderRadius.circular(AscendRadii.card)),
      child: Row(children: [
        Container(width: 42, height: 42, decoration: const BoxDecoration(color: AscendColors.gold, shape: BoxShape.circle), child: Center(child: Text(day <= 30 ? '01' : day <= 60 ? '02' : '03', style: const TextStyle(color: AscendColors.background, fontWeight: FontWeight.bold)))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$phase · $range', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 4), Text(copy, style: Theme.of(context).textTheme.bodyMedium)])),
      ]),
    );
  }

  Widget _milestoneSection(BuildContext context, _PlanData data) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Milestones', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 8),
    for (final milestone in _milestones())
      Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(data.completedMilestones.contains(milestone.$1) ? Icons.check_circle : Icons.radio_button_unchecked, color: AscendColors.gold),
          title: Text(milestone.$2),
          subtitle: Text(milestone.$3),
          trailing: TextButton(
            onPressed: _working ? null : () => _toggleMilestone(milestone.$1, data.completedMilestones),
            child: Text(data.completedMilestones.contains(milestone.$1) ? 'Undo' : 'Mark done'),
          ),
          isThreeLine: true,
        ),
      ),
  ]);

  List<(String, String, String)> _milestones() => [
    for (var week = 1; week <= 13; week++)
      ('week-$week', 'Week $week review', 'Check what felt manageable this week. Keep, edit, or skip tasks based on your routine.'),
    ('day-30', 'Day 30 · Foundation', 'Review the habits you were able to repeat.'),
    ('day-60', 'Day 60 · Development', 'Adjust routines to better fit your preferences.'),
    ('day-90', 'Day 90 · Consistency', 'Choose the sustainable habits you want to carry forward.'),
  ];

  Widget _taskCard(BuildContext context, DailyTask task) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(task.title, style: Theme.of(context).textTheme.titleMedium)),
          Text('${task.minutes} min · ${task.slot}', style: Theme.of(context).textTheme.bodyMedium),
        ]),
        const SizedBox(height: 8),
        Text(task.instruction, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Wrap(alignment: WrapAlignment.end, spacing: 4, children: [
          TextButton.icon(onPressed: _working ? null : () => _edit(task), icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edit')),
          TextButton(onPressed: _working ? null : () => _setState(task, task.state == TaskState.skipped ? TaskState.pending : TaskState.skipped), child: Text(task.state == TaskState.skipped ? 'Undo skip' : 'Skip')),
          FilledButton.tonalIcon(
            onPressed: _working ? null : () => _setState(task, task.state == TaskState.completed ? TaskState.pending : TaskState.completed),
            icon: Icon(task.state == TaskState.completed ? Icons.check_circle : Icons.check_circle_outline),
            label: Text(task.state == TaskState.completed ? 'Completed' : 'Complete'),
          ),
        ]),
      ]),
    ),
  );

  Future<void> _setState(DailyTask task, TaskState state) async {
    setState(() { _working = true; _error = null; });
    try {
      await ref.read(appServicesProvider).repository.updateTaskState(task.id, state);
      await _reload();
    } on Object {
      if (mounted) setState(() => _error = 'The task update could not be saved. Try again.');
    } finally { if (mounted) setState(() => _working = false); }
  }

  Future<void> _edit(DailyTask task) async {
    final title = TextEditingController(text: task.title);
    final instruction = TextEditingController(text: task.instruction);
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit routine task'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, maxLength: 100, decoration: const InputDecoration(labelText: 'Task name')),
          const SizedBox(height: 8),
          TextField(controller: instruction, maxLength: 500, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Instructions')),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save'))],
      ),
    );
    if (save == true && mounted) {
      try {
        await ref.read(appServicesProvider).repository.editTask(task.id, title: title.text, instruction: instruction.text);
        await _reload();
      } on Object {
        if (mounted) setState(() => _error = 'Task edits must include a title and instructions within the length limits.');
      }
    }
    title.dispose();
    instruction.dispose();
  }

  Future<void> _toggleMilestone(String id, Set<String> existing) async {
    final updated = {...existing};
    updated.contains(id) ? updated.remove(id) : updated.add(id);
    try {
      await ref.read(appServicesProvider).repository.saveSetting('milestones', {'completed': updated.toList()});
      await _reload();
    } on Object {
      if (mounted) setState(() => _error = 'The milestone could not be saved.');
    }
  }

  int _longestStreak(List<DailyTask> tasks) {
    final days = <int, List<DailyTask>>{};
    for (final task in tasks) { days.putIfAbsent(task.dayIndex, () => []).add(task); }
    var longest = 0;
    var run = 0;
    for (var day = 1; day <= 90; day++) {
      final dayTasks = days[day] ?? const <DailyTask>[];
      if (dayTasks.isNotEmpty && dayTasks.every((task) => task.state == TaskState.completed)) {
        run++;
        if (run > longest) longest = run;
      } else {
        run = 0;
      }
    }
    return longest;
  }

  Widget _message(BuildContext context, String title, String body, {VoidCallback? action}) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(body, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
      if (action != null) ...[const SizedBox(height: 12), FilledButton(onPressed: action, child: const Text('Try again'))],
    ]),
  );
}

class _PlanData {
  const _PlanData(this.plan, this.completionRate, this.completedMilestones);
  final CoachingPlan? plan;
  final double completionRate;
  final Set<String> completedMilestones;
}
