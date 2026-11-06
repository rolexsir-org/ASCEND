import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_services.dart';
import '../../core/theme/ascend_theme.dart';
import '../../domain/models.dart';
import 'local_coach_engine.dart';

class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});
  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  late Future<_HomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeData> _load() async {
    final services = ref.read(appServicesProvider);
    final preferences = await services.repository.getPreferences();
    final plan = await services.repository.getLatestPlan();
    final scans = await services.repository.getScans();
    final pro = await services.subscriptions.refreshStatus();
    final rate = await services.repository.completionRate();
    final feedback = await services.repository.readSetting('coach_feedback');
    final scores = feedback == null ? <String, int>{} : Map<String, int>.from((feedback['scores'] as Map?) ?? const {});
    final recommendations = services.coach.buildRecommendations(
      preferences: preferences,
      validatedObservations: scans.isEmpty ? null : scans.first.measurements,
      completionRate: rate,
      userFeedback: scores,
    );
    final today = DateTime.now();
    final dayIndex = plan == null ? 0 : (DateTime(today.year, today.month, today.day).difference(DateTime(plan.startDate.year, plan.startDate.month, plan.startDate.day)).inDays + 1).clamp(1, 90).toInt();
    final tasks = plan?.tasks.where((task) => task.dayIndex == dayIndex).toList(growable: false) ?? const <DailyTask>[];
    final completedScans = await services.repository.completedScanCount();
    return _HomeData(recommendations, plan, tasks, pro.isPro, completedScans);
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('ASCEND'),
      actions: [
        IconButton(tooltip: 'Settings and privacy', onPressed: () => context.push('/settings'), icon: const Icon(Icons.tune)),
      ],
    ),
    body: FutureBuilder<_HomeData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError || snapshot.data == null) {
          return _error(context, 'Your local coach could not be loaded.', onRetry: _reload);
        }
        return _content(context, snapshot.data!);
      },
    ),
  );

  Widget _content(BuildContext context, _HomeData data) {
    final now = DateTime.now();
    final greeting = now.hour < 12 ? 'Good morning.' : now.hour < 18 ? 'Good afternoon.' : 'Good evening.';
    DailyTask? nextTask;
    for (final task in data.todayTasks) {
      if (task.state == TaskState.pending) { nextTask = task; break; }
    }
    final scanAvailable = data.isPro || data.scanCount == 0;
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Text(greeting, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('A few practical steps, chosen around your goals.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 22),
          _scanCard(context, data, scanAvailable),
          const SizedBox(height: 14),
          _routineCard(context, data.plan, nextTask),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: Text('Your next steps', style: Theme.of(context).textTheme.titleLarge)),
            IconButton(tooltip: 'Refresh coaching', onPressed: _reload, icon: const Icon(Icons.refresh)),
          ]),
          if (data.recommendations.isEmpty)
            _error(context, 'No coaching suggestions yet. Choose a goal in Settings to get started.')
          else
            for (final recommendation in data.recommendations.take(3)) _recommendation(context, recommendation),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AscendColors.surface, borderRadius: BorderRadius.circular(AscendRadii.card), border: Border.all(color: AscendColors.border)),
            child: Text('ASCEND does not score attractiveness or diagnose skin or hair conditions. Recommendations use your preferences and routine history—not inferred facial findings.', style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _scanCard(BuildContext context, _HomeData data, bool scanAvailable) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AscendColors.surface,
      borderRadius: BorderRadius.circular(AscendRadii.card),
      border: Border.all(color: AscendColors.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.face_retouching_natural, color: AscendColors.gold), const SizedBox(width: 8), Text('Private scan', style: Theme.of(context).textTheme.titleLarge)]),
      const SizedBox(height: 8),
      Text(
        scanAvailable ? 'Local-only capture checks. No face photo is sent to a server.' : 'Your included scan is complete. Pro unlocks weekly rescans and historical comparison.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: () => context.push(scanAvailable ? '/scan' : '/paywall'),
        icon: Icon(scanAvailable ? Icons.camera_alt_outlined : Icons.lock_outline),
        label: Text(scanAvailable ? (data.scanCount == 0 ? 'Start your first scan' : 'Start a Pro rescan') : 'Explore ASCEND Pro'),
      ),
    ]),
  );

  Widget _routineCard(BuildContext context, CoachingPlan? plan, DailyTask? task) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: AscendColors.surfaceRaised, borderRadius: BorderRadius.circular(AscendRadii.card)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.calendar_today_outlined, color: AscendColors.gold), const SizedBox(width: 8), Text('Today', style: Theme.of(context).textTheme.titleLarge)]),
      const SizedBox(height: 10),
      if (plan == null)
        Text('Create your routine plan in the Plan tab.', style: Theme.of(context).textTheme.bodyMedium)
      else if (task == null)
        Text('Your current plan day has no scheduled tasks. You can review the full calendar in Plan.', style: Theme.of(context).textTheme.bodyMedium)
      else ...[
        Text(task.title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text('${task.minutes} minutes · ${task.slot}', style: Theme.of(context).textTheme.bodyMedium),
      ],
      const SizedBox(height: 12),
      TextButton.icon(onPressed: () => context.go('/plan'), icon: const Icon(Icons.arrow_forward), label: const Text('Open your 90-day plan')),
    ]),
  );

  Widget _recommendation(BuildContext context, CoachingRecommendation item) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(item.title, style: Theme.of(context).textTheme.titleMedium)), Text('${item.minutes} min', style: Theme.of(context).textTheme.bodyMedium)]),
        const SizedBox(height: 8),
        Text(item.body, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Text(item.reason, style: const TextStyle(color: AscendColors.gold, fontSize: 12)),
      ]),
    ),
  );

  Widget _error(BuildContext context, String message, {VoidCallback? onRetry}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.info_outline, color: AscendColors.gold, size: 30),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        if (onRetry != null) ...[const SizedBox(height: 12), OutlinedButton(onPressed: onRetry, child: const Text('Retry'))],
      ]),
    ),
  );
}

class _HomeData {
  const _HomeData(this.recommendations, this.plan, this.todayTasks, this.isPro, this.scanCount);
  final List<CoachingRecommendation> recommendations;
  final CoachingPlan? plan;
  final List<DailyTask> todayTasks;
  final bool isPro;
  final int scanCount;
}
