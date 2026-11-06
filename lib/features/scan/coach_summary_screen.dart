import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_services.dart';
import '../../core/theme/ascend_theme.dart';
import '../../domain/models.dart';
import '../coach/local_coach_engine.dart';

class CoachSummaryScreen extends ConsumerStatefulWidget {
  const CoachSummaryScreen({required this.scanId, super.key});
  final String scanId;

  @override
  ConsumerState<CoachSummaryScreen> createState() => _CoachSummaryScreenState();
}

class _CoachSummaryScreenState extends ConsumerState<CoachSummaryScreen> {
  bool _paywallVisible = false;
  late Future<ScanRecord?> _recordFuture;
  UserPreferences? _preferences;
  List<CoachingRecommendation> _recommendations = const [];
  final Set<String> _rated = {};

  @override
  void initState() {
    super.initState();
    _recordFuture = _load();
  }

  Future<ScanRecord?> _load() async {
    final services = ref.read(appServicesProvider);
    final prefs = await services.repository.getPreferences();
    final scans = await services.repository.getScans();
    ScanRecord? scan;
    for (final item in scans) {
      if (item.id == widget.scanId) { scan = item; break; }
    }
    if (scan == null) return null;
    final rate = await services.repository.completionRate();
    final feedback = await services.repository.readSetting('coach_feedback');
    final scores = feedback == null
        ? <String, int>{}
        : Map<String, int>.from((feedback['scores'] as Map?) ?? const {});
    _preferences = prefs;
    _recommendations = services.coach.buildRecommendations(
      preferences: prefs,
      validatedObservations: scan.measurements,
      completionRate: rate,
      userFeedback: scores,
    );
    final isPro = (await services.subscriptions.refreshStatus()).isPro;
    _paywallVisible = !isPro && await services.repository.completedScanCount() == 1;
    return scan;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Coach summary'),
      actions: [
        IconButton(
          tooltip: 'Delete this scan',
          onPressed: _deleteScan,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    ),
    body: FutureBuilder<ScanRecord?>(
      future: _recordFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError || snapshot.data == null) {
          return _stateMessage(context, 'Scan unavailable', 'This scan may have been deleted or could not be decrypted. Your other local data has not been changed.', onAction: () => context.go('/coach'));
        }
        final scan = snapshot.data!;
        final prefs = _preferences ?? const UserPreferences();
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          children: [
            Text('Capture checks passed', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('Captured ${_dateLabel(scan.createdAt)} · processing and storage stayed on this device.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 18),
            _privatePhoto(scan),
            const SizedBox(height: 18),
            _observationsCard(context, scan),
            const SizedBox(height: 20),
            Text('Your selected goals', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final goal in prefs.goals)
                Chip(label: Text(_goalLabel(goal)), backgroundColor: AscendColors.surfaceRaised),
            ]),
            const SizedBox(height: 24),
            Text('Three useful next steps', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (_recommendations.isEmpty)
              _stateMessage(context, 'No recommendations yet', 'Choose a goal in Settings or onboarding to receive local coaching.')
            else
              for (final recommendation in _recommendations.take(3))
                _recommendationCard(context, recommendation),
            const SizedBox(height: 16),
            if (_paywallVisible) _proAfterFreeSummary(context),
            const SizedBox(height: 16),
            Text(
              'Limitations: landmark positions describe this capture only. They are not an attractiveness assessment, medical finding, identity signal, or proof of biological change. The local rules do not infer findings from your face.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(onPressed: () => context.go('/plan'), icon: const Icon(Icons.calendar_month_outlined), label: const Text('View my 90-day plan')),
            TextButton(onPressed: () => context.go('/coach'), child: const Text('Back to Coach')),
          ],
        );
      },
    ),
  );

  Widget _privatePhoto(ScanRecord scan) => FutureBuilder<Uint8List>(
    future: ref.read(appServicesProvider).repository.readPhotoForScan(scan),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError || snapshot.data == null) {
        return const SizedBox(height: 160, child: Center(child: Text('Encrypted photo unavailable. The scan record remains available.')));
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(AscendRadii.card),
        child: Image.memory(snapshot.data!, height: 280, fit: BoxFit.cover, gaplessPlayback: false),
      );
    },
  );

  Widget _observationsCard(BuildContext context, ScanRecord scan) {
    final observation = scan.measurements;
    final rows = <(String, String)>[
      ('Faces detected', '${observation.faceCount}'),
      ('Landmarks available', '${observation.landmarkCount} of 478 expected'),
      if (observation.faceCenterX != null && observation.faceCenterY != null)
        ('Face center in frame', 'x ${(observation.faceCenterX! * 100).round()}% · y ${(observation.faceCenterY! * 100).round()}%'),
      if (observation.faceWidthRatio != null && observation.faceHeightRatio != null)
        ('Face framing', '${(observation.faceWidthRatio! * 100).round()}% of frame width · ${(observation.faceHeightRatio! * 100).round()}% of frame height'),
      if (observation.eyeLineTiltDegrees != null)
        ('Eye-line tilt in this image', '${observation.eyeLineTiltDegrees!.toStringAsFixed(1)}° (capture geometry only)'),
      if (scan.quality.meanLuma != null)
        ('Average image brightness', '${scan.quality.meanLuma!.toStringAsFixed(0)} / 255'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AscendColors.surface, borderRadius: BorderRadius.circular(AscendRadii.card), border: Border.all(color: AscendColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Available scan observations', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        for (final (label, value) in rows) Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
            const SizedBox(width: 12),
            Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(color: AscendColors.textPrimary))),
          ]),
        ),
        const SizedBox(height: 8),
        Text('The framing guide is approximate; camera angle, lighting, and model error affect these observations.', style: Theme.of(context).textTheme.bodyMedium),
      ]),
    );
  }

  Widget _recommendationCard(BuildContext context, CoachingRecommendation recommendation) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.check_circle_outline, color: AscendColors.gold, size: 19),
          const SizedBox(width: 8),
          Expanded(child: Text(recommendation.title, style: Theme.of(context).textTheme.titleMedium)),
          Text('${recommendation.minutes} min', style: Theme.of(context).textTheme.bodyMedium),
        ]),
        const SizedBox(height: 8),
        Text(recommendation.body, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Text(recommendation.reason, style: const TextStyle(color: AscendColors.gold, fontSize: 12)),
        const SizedBox(height: 8),
        Row(children: [
          const Text('Was this useful?', style: TextStyle(fontSize: 12, color: AscendColors.textSecondary)),
          const Spacer(),
          IconButton(
            tooltip: 'Helpful',
            onPressed: _rated.contains(recommendation.id) ? null : () => _rate(recommendation.id, 1),
            icon: const Icon(Icons.thumb_up_outlined, size: 18),
          ),
          IconButton(
            tooltip: 'Not useful',
            onPressed: _rated.contains(recommendation.id) ? null : () => _rate(recommendation.id, -1),
            icon: const Icon(Icons.thumb_down_outlined, size: 18),
          ),
        ]),
      ]),
    ),
  );

  Widget _proAfterFreeSummary(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AscendColors.surfaceRaised,
      borderRadius: BorderRadius.circular(AscendRadii.card),
      border: Border.all(color: AscendColors.gold.withValues(alpha: .6)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('ASCEND PRO', style: TextStyle(color: AscendColors.gold, letterSpacing: 1.8, fontSize: 11, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('Build a longer view of your routine.', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text('Pro includes weekly scans, historical comparisons, expanded routines, and reminders. Your free summary remains available either way.', style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: FilledButton(onPressed: () => context.push('/paywall'), child: const Text('See Pro options'))),
        const SizedBox(width: 8),
        TextButton(onPressed: () => setState(() => _paywallVisible = false), child: const Text('Continue free')),
      ]),
    ]),
  );

  Widget _stateMessage(BuildContext context, String title, String body, {VoidCallback? onAction}) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: AscendColors.surface, borderRadius: BorderRadius.circular(AscendRadii.card), border: Border.all(color: AscendColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(body, style: Theme.of(context).textTheme.bodyMedium),
      if (onAction != null) ...[const SizedBox(height: 12), TextButton(onPressed: onAction, child: const Text('Return to Coach'))],
    ]),
  );

  Future<void> _rate(String id, int score) async {
    final repository = ref.read(appServicesProvider).repository;
    final current = await repository.readSetting('coach_feedback');
    final scores = Map<String, int>.from((current?['scores'] as Map?) ?? const {});
    scores[id] = score;
    await repository.saveSetting('coach_feedback', {'scores': scores});
    if (mounted) setState(() => _rated.add(id));
  }

  Future<void> _deleteScan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this scan?'),
        content: const Text('The encrypted photo and associated scan observations will be removed from this device.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep scan')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(appServicesProvider).repository.deleteScan(widget.scanId);
      ref.invalidate(planProvider);
      if (mounted) context.go('/progress');
    } on Object {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The scan could not be fully deleted. Try again from Progress.')));
    }
  }

  String _dateLabel(DateTime date) => '${_month(date.month)} ${date.day}, ${date.year}';
  String _month(int month) => const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][month - 1];
  String _goalLabel(CoachGoal goal) => switch (goal) {
    CoachGoal.skincare => 'Skincare', CoachGoal.hairstyle => 'Hairstyle', CoachGoal.beard => 'Beard care',
    CoachGoal.personalStyle => 'Personal style', CoachGoal.posture => 'Posture',
  };
}
