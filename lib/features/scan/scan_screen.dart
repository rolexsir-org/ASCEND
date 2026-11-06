import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_services.dart';
import '../../core/theme/ascend_theme.dart';
import '../../domain/models.dart';
import 'face_analysis_engine.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});
  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> with WidgetsBindingObserver {
  CameraController? _camera;
  XFile? _capture;
  bool _permissionExplained = false;
  bool _cameraBusy = false;
  bool _streamBusy = false;
  bool _consent = false;
  bool _analysisBusy = false;
  String? _error;
  String _lightingFeedback = 'Even, soft lighting works best.';
  DateTime _lastLumaUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      unawaited(_stopCamera());
    } else if (state == AppLifecycleState.resumed && _permissionExplained && _capture == null) {
      unawaited(_startCamera());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _camera;
    if (controller != null) unawaited(controller.dispose());
    final capture = _capture;
    if (capture != null) unawaited(_deleteTemporary(capture));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face scan'),
        actions: [
          IconButton(
            tooltip: 'Scan privacy information',
            onPressed: () => context.push('/privacy'),
            icon: const Icon(Icons.privacy_tip_outlined),
          ),
        ],
      ),
      body: SafeArea(child: _capture != null ? _buildReview(context) : _camera == null ? _buildIntro(context) : _buildPreview(context)),
    );
  }

  Widget _buildIntro(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const SizedBox(height: 12),
      Container(
        height: 230,
        decoration: BoxDecoration(
          color: AscendColors.surface,
          borderRadius: BorderRadius.circular(AscendRadii.card),
          border: Border.all(color: AscendColors.border),
        ),
        child: const Center(child: Icon(Icons.face_retouching_natural, size: 72, color: AscendColors.gold)),
      ),
      const SizedBox(height: 24),
      Text('A private capture, on your terms.', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 12),
      Text('The front camera is opened only after you continue. ASCEND checks capture framing and landmarks locally. Photos are never uploaded. Only an accepted scan is saved, encrypted, after this consent.', style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 16),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _consent,
        onChanged: (value) => setState(() => _consent = value ?? false),
        title: const Text('I consent to on-device image analysis and saving an accepted scan privately for progress tracking.'),
        controlAffinity: ListTileControlAffinity.leading,
      ),
      if (_error != null) _errorBox(_error!),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _consent && !_cameraBusy ? _startCamera : null,
        icon: _cameraBusy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.camera_alt_outlined),
        label: Text(_cameraBusy ? 'Opening camera…' : 'Continue to camera'),
      ),
      const SizedBox(height: 8),
      Text('You can retake or discard before analysis. The camera is not used in the background.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
    ],
  );

  Widget _buildPreview(BuildContext context) {
    final camera = _camera!;
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AscendRadii.card),
              child: Stack(fit: StackFit.expand, children: [
                CameraPreview(camera),
                IgnorePointer(child: CustomPaint(painter: _FaceGuidePainter())),
                Positioned(
                  top: 14, left: 14, right: 14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: .66), borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(children: [
                        const Icon(Icons.light_mode_outlined, color: AscendColors.gold, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_lightingFeedback, style: const TextStyle(color: Colors.white, fontSize: 13))),
                      ]),
                    ),
                  ),
                ),
                const Positioned(
                  bottom: 18, left: 16, right: 16,
                  child: Text('Face the camera. Keep your head level and leave a little space around your face.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, shadows: [Shadow(blurRadius: 8, color: Colors.black)])),
                ),
              ]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            IconButton.filledTonal(onPressed: _discardCamera, tooltip: 'Close camera', icon: const Icon(Icons.close)),
            Semantics(
              button: true,
              label: 'Capture scan photo',
              child: GestureDetector(
                onTap: _cameraBusy ? null : _takeCapture,
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AscendColors.gold, width: 4)),
                  child: Center(child: Container(width: 52, height: 52, decoration: const BoxDecoration(shape: BoxShape.circle, color: AscendColors.gold))),
                ),
              ),
            ),
            const SizedBox(width: 48),
          ]),
        ),
      ],
    );
  }

  Widget _buildReview(BuildContext context) {
    final capture = _capture!;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AscendRadii.card),
            child: Image.file(File(capture.path), fit: BoxFit.cover, errorBuilder: (_, _, _) => const Center(child: Text('Preview unavailable. Retake the photo.'))),
          ),
        ),
        const SizedBox(height: 18),
        Text('Review your capture', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('Nothing is analyzed or permanently saved until you continue. Retake or discard if you prefer.', style: Theme.of(context).textTheme.bodyMedium),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _consent,
          onChanged: (value) => setState(() => _consent = value ?? false),
          title: const Text('I consent to local face-landmark analysis and encrypted saving of this scan.'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (_error != null) _errorBox(_error!),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: _analysisBusy ? null : _retake, icon: const Icon(Icons.refresh), label: const Text('Retake'))),
          const SizedBox(width: 12),
          Expanded(child: FilledButton.icon(
            onPressed: !_consent || _analysisBusy ? null : _analyzeAndSave,
            icon: _analysisBusy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.lock_outline),
            label: Text(_analysisBusy ? 'Checking locally…' : 'Analyze & save'),
          )),
        ]),
        TextButton(onPressed: _analysisBusy ? null : _discardCapture, child: const Text('Discard photo')),
      ],
    );
  }

  Future<void> _startCamera() async {
    if (_cameraBusy) return;
    setState(() { _cameraBusy = true; _error = null; });
    try {
      final services = ref.read(appServicesProvider);
      final proStatus = await services.subscriptions.refreshStatus();
      final existingScans = await services.repository.getScans();
      if (!proStatus.isPro && existingScans.isNotEmpty) {
        if (mounted) context.go('/paywall');
        return;
      }
      if (proStatus.isPro && existingScans.isNotEmpty &&
          DateTime.now().toUtc().difference(existingScans.first.createdAt) < const Duration(days: 7)) {
        final nextDate = existingScans.first.createdAt.add(const Duration(days: 7));
        if (mounted) setState(() => _error = 'Your next weekly rescan is available after ${nextDate.toLocal().toString().substring(0, 10)}. Your existing scans remain available in Progress.');
        return;
      }
      final cameras = await availableCameras();
      final front = cameras.where((camera) => camera.lensDirection == CameraLensDirection.front).toList();
      if (front.isEmpty) {
        setState(() => _error = 'This device does not provide a front-facing camera. You can still use the plan and progress features.');
        return;
      }
      final controller = CameraController(
        front.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) { await controller.dispose(); return; }
      _camera = controller;
      _permissionExplained = true;
      await controller.startImageStream(_onPreviewFrame);
      setState(() {});
    } on CameraException catch (error) {
      final message = switch (error.code) {
        'CameraAccessDenied' || 'CameraAccessDeniedWithoutPrompt' || 'CameraAccessRestricted' =>
          'Camera permission was not granted. Enable camera access in Android Settings to scan, or continue using ASCEND without a scan.',
        _ => 'The camera could not start (${error.description ?? error.code}). Close other camera apps and try again.',
      };
      if (mounted) setState(() => _error = message);
    } on Object {
      if (mounted) setState(() => _error = 'No compatible camera could be opened. You can retry or continue without scanning.');
    } finally {
      if (mounted) setState(() => _cameraBusy = false);
    }
  }

  void _onPreviewFrame(CameraImage image) {
    if (_streamBusy || DateTime.now().difference(_lastLumaUpdate) < const Duration(milliseconds: 450)) return;
    _streamBusy = true;
    try {
      final plane = image.planes.first;
      final bytes = plane.bytes;
      if (bytes.isEmpty) return;
      final step = math.max(1, bytes.length ~/ 250).toInt();
      var total = 0;
      var count = 0;
      for (var i = 0; i < bytes.length; i += step) { total += bytes[i]; count++; }
      final luma = count == 0 ? 0.0 : total / count;
      final message = luma < 48
          ? 'Lighting is low. Face a brighter, even light source.'
          : luma > 225
              ? 'Lighting is strong. Turn away from direct glare.'
              : 'Lighting looks usable. Keep your head level.';
      _lastLumaUpdate = DateTime.now();
      if (mounted && message != _lightingFeedback) setState(() => _lightingFeedback = message);
    } finally {
      _streamBusy = false;
    }
  }

  Future<void> _takeCapture() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || _cameraBusy) return;
    setState(() { _cameraBusy = true; _error = null; });
    try {
      if (camera.value.isStreamingImages) await camera.stopImageStream();
      final file = await camera.takePicture();
      if (!mounted) { await _deleteTemporary(file); return; }
      setState(() { _capture = file; _consent = true; });
    } on CameraException catch (error) {
      if (mounted) setState(() => _error = 'The photo could not be captured (${error.description ?? error.code}). Please try again.');
      if (mounted && camera.value.isInitialized && !camera.value.isStreamingImages) {
        try { await camera.startImageStream(_onPreviewFrame); } on CameraException { /* Preview can be reopened by returning to the camera screen. */ }
      }
    } finally {
      if (mounted) setState(() => _cameraBusy = false);
    }
  }

  Future<void> _analyzeAndSave() async {
    final capture = _capture;
    if (capture == null || !_consent || _analysisBusy) return;
    setState(() { _analysisBusy = true; _error = null; });
    final services = ref.read(appServicesProvider);
    try {
      final bytes = await File(capture.path).readAsBytes();
      final pixels = await services.imageQuality.inspect(bytes);
      ImageQualityReport report;
      if (pixels.issues.isNotEmpty) {
        report = ImageQualityReport(
          issues: pixels.issues,
          meanLuma: pixels.meanLuma,
          laplacianVariance: pixels.laplacianVariance,
          observations: const FaceObservations(
            faceCount: 0, landmarkCount: 0, faceCenterX: null, faceCenterY: null,
            faceWidthRatio: null, faceHeightRatio: null, eyeLineTiltDegrees: null,
            orientationProxy: null, measurementsReliable: false,
          ),
        );
      } else {
        final landmarks = await services.faceAnalysis.analyzeImage(capture.path);
        final pixelReport = ImageQualityReport(
          issues: const [],
          meanLuma: pixels.meanLuma,
          laplacianVariance: pixels.laplacianVariance,
          observations: const FaceObservations(
            faceCount: 0, landmarkCount: 0, faceCenterX: null, faceCenterY: null,
            faceWidthRatio: null, faceHeightRatio: null, eyeLineTiltDegrees: null,
            orientationProxy: null, measurementsReliable: false,
          ),
        );
        report = services.faceGeometry.evaluate(pixelReport: pixelReport, result: landmarks);
      }
      if (!report.accepted) {
        await _deleteTemporary(capture);
        if (!mounted) return;
        setState(() {
          _capture = null;
          _error = _guidance(report.issues);
        });
        await _restartPreview();
        return;
      }
      final proStatus = await services.subscriptions.refreshStatus();
      final priorScans = await services.repository.getScans();
      final weeklyLimitReached = proStatus.isPro && priorScans.isNotEmpty &&
          DateTime.now().toUtc().difference(priorScans.first.createdAt) < const Duration(days: 7);
      final freeLimitReached = !proStatus.isPro && priorScans.isNotEmpty;
      if (weeklyLimitReached || freeLimitReached) {
        await _deleteTemporary(capture);
        if (mounted && freeLimitReached) context.go('/paywall');
        if (mounted && weeklyLimitReached) setState(() => _error = 'Weekly rescan limit reached. The photo was discarded; your existing scans are unchanged.');
        return;
      }
      final id = newLocalId();
      final record = ScanRecord(
        id: id,
        createdAt: DateTime.now().toUtc(),
        quality: report,
        measurements: report.observations,
        photoFileName: '',
      );
      await _deleteTemporary(capture);
      await services.repository.saveScan(record, bytes);
      if (!mounted) return;
      setState(() => _capture = null);
      ref.invalidate(preferencesProvider);
      ref.invalidate(subscriptionStatusProvider);
      context.go('/summary/$id');
    } on FaceModelUnavailableException catch (error) {
      await _deleteTemporary(capture);
      if (mounted) setState(() { _capture = null; _error = error.message; });
      await _restartPreview();
    } on FaceAnalysisFailure catch (error) {
      await _deleteTemporary(capture);
      if (mounted) setState(() { _capture = null; _error = '${error.message} Please retake in a clear, front-facing position.'; });
      await _restartPreview();
    } on FormatException catch (error) {
      await _deleteTemporary(capture);
      if (mounted) setState(() { _capture = null; _error = error.message; });
      await _restartPreview();
    } on Object {
      await _deleteTemporary(capture);
      if (mounted) setState(() { _capture = null; _error = 'The scan could not be safely saved. No accepted photo was kept. Please retry.'; });
      await _restartPreview();
    } finally {
      if (mounted) setState(() => _analysisBusy = false);
    }
  }

  String _guidance(List<ScanIssue> issues) {
    final guidance = <String>[];
    if (issues.contains(ScanIssue.tooDark)) guidance.add('Move toward brighter, even light.');
    if (issues.contains(ScanIssue.tooBright)) guidance.add('Avoid direct glare or a bright window behind you.');
    if (issues.contains(ScanIssue.blurry)) guidance.add('Hold the phone steady and pause before capture.');
    if (issues.contains(ScanIssue.noFace)) guidance.add('Place one face within the guide.');
    if (issues.contains(ScanIssue.multipleFaces)) guidance.add('Make sure only you are in the frame.');
    if (issues.contains(ScanIssue.offCenter)) guidance.add('Center your face in the guide.');
    if (issues.contains(ScanIssue.tooSmall)) guidance.add('Move a little closer.');
    if (issues.contains(ScanIssue.tooLarge)) guidance.add('Move a little farther away.');
    if (issues.contains(ScanIssue.headTurned)) guidance.add('Face forward and keep your head level.');
    if (issues.contains(ScanIssue.missingLandmarks)) guidance.add('Make sure your face is fully visible and try again.');
    return guidance.isEmpty ? 'The capture did not meet quality checks. Adjust the framing and try again.' : guidance.join(' ');
  }

  Future<void> _retake() async {
    final capture = _capture;
    if (capture != null) await _deleteTemporary(capture);
    setState(() { _capture = null; _error = null; _consent = true; });
    await _restartPreview();
  }

  Future<void> _discardCapture() async {
    final capture = _capture;
    if (capture != null) await _deleteTemporary(capture);
    if (mounted) setState(() { _capture = null; _error = null; _consent = false; });
    await _restartPreview();
  }

  Future<void> _restartPreview() async {
    final camera = _camera;
    if (camera != null && camera.value.isInitialized && !camera.value.isStreamingImages) {
      try { await camera.startImageStream(_onPreviewFrame); } on CameraException { await _stopCamera(); }
    }
  }

  Future<void> _discardCamera() async {
    await _stopCamera();
    if (mounted) setState(() { _consent = false; _error = null; });
  }

  Future<void> _stopCamera() async {
    final camera = _camera;
    _camera = null;
    if (camera != null) await camera.dispose();
    if (mounted) setState(() {});
  }

  Future<void> _deleteTemporary(XFile file) async {
    final image = File(file.path);
    if (await image.exists()) await image.delete();
  }

  Widget _errorBox(String message) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AscendColors.error.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
      child: Text(message, style: const TextStyle(color: AscendColors.textPrimary)),
    ),
  );
}

class _FaceGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AscendColors.gold.withValues(alpha: .9)..style = PaintingStyle.stroke..strokeWidth = 2;
    final rect = Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: size.width * .64, height: size.height * .59);
    final shade = Paint()..color = Colors.black.withValues(alpha: .16)..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), shade);
    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _FaceGuidePainter oldDelegate) => false;
}
