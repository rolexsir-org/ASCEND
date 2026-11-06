import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_services.dart';
import '../../core/theme/ascend_theme.dart';
import '../../domain/models.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});
  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  late Future<_ProgressData> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ProgressData> _load() async {
    final services = ref.read(appServicesProvider);
    final repository = services.repository;
    final scans = await repository.getScans();
    final checkIns = await repository.getCheckIns();
    final plan = await repository.getLatestPlan();
    final pro = (await services.subscriptions.refreshStatus()).isPro;
    final milestones = await repository.readSetting('milestones');
    final completed = ((milestones?['completed'] as List?) ?? const []).whereType<String>().toSet();
    final tasks = plan?.tasks ?? const <DailyTask>[];
    return _ProgressData(
      scans: scans,
      checkIns: checkIns,
      completedTasks: tasks.where((task) => task.state == TaskState.completed).length,
      totalTasks: tasks.length,
      isPro: pro,
      completedMilestones: completed,
    );
  }

  Future<void> _reload() async {
    setState(() { _busy = true; _future = _load(); });
    try { await _future; } on Object { /* FutureBuilder renders the error state. */ }
    finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Progress'),
      actions: [
        IconButton(tooltip: 'Settings', onPressed: () => context.push('/settings'), icon: const Icon(Icons.tune)),
      ],
    ),
    body: FutureBuilder<_ProgressData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError || snapshot.data == null) {
          return _empty(context, 'Progress could not be loaded', 'Your encrypted data was preserved. Check available device storage and try again.', onRetry: _reload);
        }
        return _content(context, snapshot.data!);
      },
    ),
  );

  Widget _content(BuildContext context, _ProgressData data) => RefreshIndicator(
    onRefresh: _reload,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
      children: [
        Text('Progress, on your terms.', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text('Photos are private on this device. Comparison is a visual record, not proof of biological change.', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 18),
        _habitCard(context, data),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: Text('Weekly check-ins', style: Theme.of(context).textTheme.titleLarge)),
          FilledButton.tonalIcon(onPressed: _busy ? null : _addCheckIn, icon: const Icon(Icons.add), label: const Text('Add')),
        ]),
        if (data.checkIns.isEmpty)
          _empty(context, 'No check-ins yet', 'A brief note can help you notice which habits fit your life.')
        else
          for (final checkIn in data.checkIns) _checkInCard(context, checkIn),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: Text('Historical scans', style: Theme.of(context).textTheme.titleLarge)),
          if (data.scans.length >= 2)
            TextButton.icon(onPressed: _busy ? null : () => data.isPro ? _chooseComparison(data.scans) : context.push('/paywall'), icon: const Icon(Icons.compare), label: const Text('Compare')),
        ]),
        if (data.scans.length >= 2 && !data.isPro)
          Text('Historical side-by-side comparison is a Pro feature. Existing scans remain on this device.', style: Theme.of(context).textTheme.bodyMedium),
        if (data.scans.isEmpty)
          _empty(context, 'No saved scans', 'When you consent to and complete a scan, its encrypted photo and capture observations will appear here.')
        else
          for (final scan in data.scans) _scanCard(context, scan),
        const SizedBox(height: 18),
        Text('Milestone history', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (data.completedMilestones.isEmpty)
          Text('Milestones you mark complete in your plan will be listed here.', style: Theme.of(context).textTheme.bodyMedium)
        else
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final id in (data.completedMilestones.toList()..sort())) Chip(avatar: const Icon(Icons.check, size: 16), label: Text(_milestoneLabel(id))),
          ]),
        const SizedBox(height: 28),
        OutlinedButton.icon(
          onPressed: _busy || (data.scans.isEmpty && data.checkIns.isEmpty) ? null : () => _confirmDeleteProgress(data),
          icon: const Icon(Icons.delete_sweep_outlined),
          label: const Text('Delete progress history'),
        ),
        const SizedBox(height: 8),
        Text('This removes saved scans, their encrypted photos, and check-in notes. Your profile and 90-day routine plan are kept.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );

  Widget _habitCard(BuildContext context, _ProgressData data) {
    final percentage = data.totalTasks == 0 ? 0 : data.completedTasks / data.totalTasks;
    final thisWeek = data.checkIns.where((item) {
      final age = DateTime.now().difference(item.date).inDays;
      return age >= 0 && age < 7;
    }).length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AscendColors.surface, borderRadius: BorderRadius.circular(AscendRadii.card), border: Border.all(color: AscendColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Habit consistency', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Text('${(percentage * 100).round()}%', style: Theme.of(context).textTheme.headlineMedium)),
          Text('${data.completedTasks} of ${data.totalTasks} planned tasks', style: Theme.of(context).textTheme.bodyMedium),
        ]),
        const SizedBox(height: 10),
        ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: percentage.toDouble(), minHeight: 7, color: AscendColors.gold, backgroundColor: AscendColors.border)),
        const SizedBox(height: 12),
        Text('$thisWeek check-ins in the last 7 days. Missed days do not remove saved progress.', style: Theme.of(context).textTheme.bodyMedium),
      ]),
    );
  }

  Widget _scanCard(BuildContext context, ScanRecord scan) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(width: 78, height: 92, child: FutureBuilder<Uint8List>(
            future: ref.read(appServicesProvider).repository.readPhotoForScan(scan),
            builder: (context, snapshot) => snapshot.hasData
                ? Image.memory(snapshot.data!, fit: BoxFit.cover)
                : const ColoredBox(color: AscendColors.surfaceRaised, child: Center(child: Icon(Icons.lock_outline, color: AscendColors.gold))),
          )),
        ),
        const SizedBox(width: 12),
        Expanded(child: InkWell(
          onTap: () => context.push('/summary/${scan.id}'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_date(scan.createdAt), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 5),
            Text('${scan.measurements.faceCount} face · ${scan.measurements.landmarkCount} landmarks', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text('Capture observations only', style: Theme.of(context).textTheme.bodyMedium),
          ]),
        )),
        IconButton(tooltip: 'Delete scan photo and record', onPressed: _busy ? null : () => _deleteScan(scan), icon: const Icon(Icons.delete_outline)),
      ]),
    ),
  );

  Widget _checkInCard(BuildContext context, ProgressCheckIn checkIn) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: const Icon(Icons.event_note_outlined, color: AscendColors.gold),
      title: Text(_date(checkIn.date)),
      subtitle: Text(checkIn.note.isEmpty ? 'No note added' : checkIn.note, maxLines: 3, overflow: TextOverflow.ellipsis),
      trailing: IconButton(tooltip: 'Delete check-in', onPressed: _busy ? null : () => _deleteCheckIn(checkIn), icon: const Icon(Icons.delete_outline)),
    ),
  );

  Future<void> _addCheckIn() async {
    final controller = TextEditingController();
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Weekly check-in'),
        content: TextField(controller: controller, maxLength: 500, minLines: 2, maxLines: 5, decoration: const InputDecoration(hintText: 'What felt practical this week? (optional)')),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save check-in'))],
      ),
    );
    if (save == true && mounted) {
      setState(() => _busy = true);
      try {
        await ref.read(appServicesProvider).repository.addCheckIn(ProgressCheckIn(id: newLocalId(), date: DateTime.now(), note: controller.text.trim()));
        await _reload();
      } on Object {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The check-in could not be saved.')));
      } finally { if (mounted) setState(() => _busy = false); }
    }
    controller.dispose();
  }

  Future<void> _chooseComparison(List<ScanRecord> scans) async {
    final chosen = await showDialog<List<ScanRecord>>(
      context: context,
      builder: (context) => _ComparisonPicker(scans: scans),
    );
    if (chosen == null || chosen.length != 2 || !mounted) return;
    try {
      final repository = ref.read(appServicesProvider).repository;
      final left = await repository.readPhotoForScan(chosen[1]);
      final right = await repository.readPhotoForScan(chosen[0]);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Visual comparison', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text('Photos are shown side by side; differences do not prove biological change.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _comparisonImage(context, left, chosen[1])),
                const SizedBox(width: 8),
                Expanded(child: _comparisonImage(context, right, chosen[0])),
              ]),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
            ]),
          ),
        ),
      );
    } on Object {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The encrypted photos could not be opened.')));
    }
  }

  Widget _comparisonImage(BuildContext context, Uint8List bytes, ScanRecord scan) => Column(children: [
    AspectRatio(aspectRatio: .72, child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(bytes, fit: BoxFit.cover))),
    const SizedBox(height: 6),
    Text(_date(scan.createdAt), style: Theme.of(context).textTheme.bodyMedium),
  ]);

  Future<void> _deleteScan(ScanRecord scan) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Delete this scan?'),
      content: const Text('The encrypted photo and scan record will be deleted from this device.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))],
    ));
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(appServicesProvider).repository.deleteScan(scan.id);
      await _reload();
    } on Object {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scan deletion did not complete. Try again.')));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _deleteCheckIn(ProgressCheckIn checkIn) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Delete check-in?'),
      content: const Text('This note will be removed from local progress history.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))],
    ));
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(appServicesProvider).repository.deleteCheckIn(checkIn.id);
      await _reload();
    } on Object {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The check-in could not be deleted.')));
    }
  }

  Future<void> _confirmDeleteProgress(_ProgressData data) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Delete progress history?'),
      content: const Text('All saved scan photos and observations and all weekly check-in notes will be removed. Your onboarding preferences and routine plan will remain.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete history'))],
    ));
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(appServicesProvider).repository.deleteProgressHistory();
      await _reload();
    } on Object {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Progress deletion did not fully complete. Retry from this screen.')));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Widget _empty(BuildContext context, String title, String body, {VoidCallback? onRetry}) => Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 10),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: AscendColors.surface, borderRadius: BorderRadius.circular(AscendRadii.card), border: Border.all(color: AscendColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Text(body, style: Theme.of(context).textTheme.bodyMedium),
      if (onRetry != null) ...[const SizedBox(height: 10), OutlinedButton(onPressed: onRetry, child: const Text('Retry'))],
    ]),
  );

  String _date(DateTime date) => '${_month(date.month)} ${date.day}, ${date.year}';
  String _month(int month) => const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][month - 1];
  String _milestoneLabel(String value) => value.replaceAll('-', ' ').replaceAll('day 30', 'Day 30').replaceAll('day 60', 'Day 60').replaceAll('day 90', 'Day 90');
}

class _ProgressData {
  const _ProgressData({required this.scans, required this.checkIns, required this.completedTasks, required this.totalTasks, required this.isPro, required this.completedMilestones});
  final List<ScanRecord> scans;
  final List<ProgressCheckIn> checkIns;
  final int completedTasks;
  final int totalTasks;
  final bool isPro;
  final Set<String> completedMilestones;
}

class _ComparisonPicker extends StatefulWidget {
  const _ComparisonPicker({required this.scans});
  final List<ScanRecord> scans;
  @override
  State<_ComparisonPicker> createState() => _ComparisonPickerState();
}

class _ComparisonPickerState extends State<_ComparisonPicker> {
  String? _older;
  String? _newer;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Choose two scans'),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButtonFormField<String>(
        initialValue: _older,
        decoration: const InputDecoration(labelText: 'Earlier scan'),
        items: [for (final scan in widget.scans) DropdownMenuItem(value: scan.id, child: Text(_format(scan.createdAt)))],
        onChanged: (value) => setState(() => _older = value),
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: _newer,
        decoration: const InputDecoration(labelText: 'Later scan'),
        items: [for (final scan in widget.scans) DropdownMenuItem(value: scan.id, child: Text(_format(scan.createdAt)))],
        onChanged: (value) => setState(() => _newer = value),
      ),
    ]),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(
      onPressed: _older == null || _newer == null || _older == _newer ? null : () {
        final older = widget.scans.where((scan) => scan.id == _older).first;
        final newer = widget.scans.where((scan) => scan.id == _newer).first;
        final ordered = older.createdAt.isBefore(newer.createdAt) ? [older, newer] : [newer, older];
        Navigator.pop(context, ordered);
      },
      child: const Text('Compare'),
    )],
  );

  String _format(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
