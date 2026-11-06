import 'package:ascend/domain/models.dart';
import 'package:ascend/features/scan/face_analysis_engine.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('ascend/face_analysis');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('passes a local path and pinned model version, then decodes only landmarks', () async {
    const landmarks = [
      [0.25, 0.4, -0.01],
      [0.75, 0.4, 0.02],
    ];
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      captured = call;
      return <String, Object?>{
        'modelVersion': MediaPipeFaceAnalysisEngine.modelVersion,
        'faces': [landmarks],
      };
    });

    final result = await MediaPipeFaceAnalysisEngine().analyzeImage('/private/cache/capture.jpg');

    expect(captured?.method, 'analyzeImage');
    expect(captured?.arguments, {
      'path': '/private/cache/capture.jpg',
      'expectedModelVersion': MediaPipeFaceAnalysisEngine.modelVersion,
    });
    expect(result.faces, hasLength(1));
    expect(result.faces.single, hasLength(2));
    expect(result.faces.single.last.z, 0.02);
  });

  test('surfaces missing local model as unavailable, never as successful analysis', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      throw PlatformException(code: 'MODEL_CHECKSUM_MISMATCH', message: 'checksum');
    });

    await expectLater(
      MediaPipeFaceAnalysisEngine().analyzeImage('/private/cache/capture.jpg'),
      throwsA(isA<FaceModelUnavailableException>()),
    );
  });

  test('face geometry accepts only a centered, single-face capture with enough landmarks', () {
    final points = List<Landmark3D>.generate(478, (index) => Landmark3D(
      .35 + (index % 21) * .015,
      .30 + ((index ~/ 21) % 27) * .015,
      0,
    ));
    points[1] = const Landmark3D(.50, .55, 0);
    points[33] = const Landmark3D(.43, .47, 0);
    points[263] = const Landmark3D(.57, .47, 0);
    const pixelReport = ImageQualityReport(
      issues: [],
      meanLuma: 128,
      laplacianVariance: 80,
      observations: FaceObservations(
        faceCount: 0,
        landmarkCount: 0,
        faceCenterX: null,
        faceCenterY: null,
        faceWidthRatio: null,
        faceHeightRatio: null,
        eyeLineTiltDegrees: null,
        orientationProxy: null,
        measurementsReliable: false,
      ),
    );
    const validator = FaceGeometryValidator();

    final accepted = validator.evaluate(
      pixelReport: pixelReport,
      result: FaceAnalysisResult(
        faces: [points], modelVersion: MediaPipeFaceAnalysisEngine.modelVersion,
      ),
    );
    final multiple = validator.evaluate(
      pixelReport: pixelReport,
      result: FaceAnalysisResult(
        faces: [points, points], modelVersion: MediaPipeFaceAnalysisEngine.modelVersion,
      ),
    );

    expect(accepted.accepted, isTrue);
    expect(accepted.observations.landmarkCount, 478);
    expect(accepted.issues, isEmpty);
    expect(multiple.accepted, isFalse);
    expect(multiple.issues, contains(ScanIssue.multipleFaces));
  });
}
