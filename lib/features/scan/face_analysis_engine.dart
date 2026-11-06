import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../../domain/models.dart';

class Landmark3D {
  const Landmark3D(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;
}

class FaceAnalysisResult {
  const FaceAnalysisResult({required this.faces, required this.modelVersion});
  final List<List<Landmark3D>> faces;
  final String modelVersion;
}

abstract interface class FaceAnalysisEngine {
  Future<FaceAnalysisResult> analyzeImage(String localImagePath);
}

class FaceModelUnavailableException implements Exception {
  const FaceModelUnavailableException(this.message);
  final String message;
  @override
  String toString() => message;
}

class FaceAnalysisFailure implements Exception {
  const FaceAnalysisFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class MediaPipeFaceAnalysisEngine implements FaceAnalysisEngine {
  MediaPipeFaceAnalysisEngine({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('ascend/face_analysis');

  static const modelVersion = 'mediapipe-face-landmarker-float16-v1';
  static const modelSha256 =
      '64184e229b263107bc2b804c6625db1341ff2bb731874b0bcc2fe6544e0bc9ff';
  final MethodChannel _channel;

  @override
  Future<FaceAnalysisResult> analyzeImage(String localImagePath) async {
    try {
      final raw = await _channel.invokeMapMethod<Object?, Object?>(
        'analyzeImage',
        {'path': localImagePath, 'expectedModelVersion': modelVersion},
      );
      if (raw == null) throw const FaceAnalysisFailure('Native analysis returned no result.');
      final version = raw['modelVersion'] as String?;
      if (version != modelVersion) {
        throw const FaceModelUnavailableException('The installed face model version is not supported.');
      }
      final rawFaces = raw['faces'] as List<Object?>? ?? const [];
      final faces = rawFaces.map((rawFace) {
        final points = (rawFace as List<Object?>).map((rawPoint) {
          final values = rawPoint as List<Object?>;
          if (values.length != 3) throw const FormatException('Invalid landmark payload.');
          return Landmark3D(
            (values[0] as num).toDouble(),
            (values[1] as num).toDouble(),
            (values[2] as num).toDouble(),
          );
        }).toList(growable: false);
        return points;
      }).toList(growable: false);
      return FaceAnalysisResult(faces: faces, modelVersion: version!);
    } on PlatformException catch (error) {
      if (error.code == 'MODEL_ASSET_MISSING' || error.code == 'MODEL_CHECKSUM_MISMATCH') {
        throw FaceModelUnavailableException(error.message ?? 'The local face model could not be validated.');
      }
      if (error.code == 'UNSUPPORTED_IMAGE') {
        throw const FaceAnalysisFailure('This image format or resolution is not supported.');
      }
      throw FaceAnalysisFailure(error.message ?? 'On-device face analysis failed.');
    } on MissingPluginException {
      throw const FaceModelUnavailableException('On-device face analysis is available on Android only.');
    } on FormatException {
      throw const FaceAnalysisFailure('The local face model returned invalid landmark data.');
    }
  }
}

class FaceGeometryValidator {
  const FaceGeometryValidator();

  ImageQualityReport evaluate({
    required ImageQualityReport pixelReport,
    required FaceAnalysisResult result,
  }) {
    final issues = <ScanIssue>[...pixelReport.issues];
    if (result.faces.isEmpty) {
      issues.add(ScanIssue.noFace);
      return ImageQualityReport(
        issues: _distinct(issues),
        meanLuma: pixelReport.meanLuma,
        laplacianVariance: pixelReport.laplacianVariance,
        observations: const FaceObservations(
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
    }
    if (result.faces.length > 1) issues.add(ScanIssue.multipleFaces);
    final points = result.faces.first;
    if (points.length < 468) issues.add(ScanIssue.missingLandmarks);
    if (points.isEmpty || points.any((point) =>
        !point.x.isFinite || !point.y.isFinite || point.x < -0.05 || point.x > 1.05 ||
        point.y < -0.05 || point.y > 1.05)) {
      issues.add(ScanIssue.missingLandmarks);
      return ImageQualityReport(
        issues: _distinct(issues),
        meanLuma: pixelReport.meanLuma,
        laplacianVariance: pixelReport.laplacianVariance,
        observations: FaceObservations(
          faceCount: result.faces.length,
          landmarkCount: points.length,
          faceCenterX: null,
          faceCenterY: null,
          faceWidthRatio: null,
          faceHeightRatio: null,
          eyeLineTiltDegrees: null,
          orientationProxy: null,
          measurementsReliable: false,
        ),
      );
    }

    final xs = points.map((p) => p.x).toList()..sort();
    final ys = points.map((p) => p.y).toList()..sort();
    // Robust percentile bounds reduce the influence of a few unstable contour points.
    final left = xs[(xs.length * .02).floor()];
    final right = xs[(xs.length * .98).floor()];
    final top = ys[(ys.length * .02).floor()];
    final bottom = ys[(ys.length * .98).floor()];
    final width = right - left;
    final height = bottom - top;
    final centerX = (left + right) / 2;
    final centerY = (top + bottom) / 2;
    if ((centerX - .5).abs() > .17 || centerY < .25 || centerY > .72) {
      issues.add(ScanIssue.offCenter);
    }
    if (height < .28 || width < .16) issues.add(ScanIssue.tooSmall);
    if (height > .78 || width > .88) issues.add(ScanIssue.tooLarge);

    double? tilt;
    double? orientation;
    if (points.length > 263) {
      final leftEye = points[33];
      final rightEye = points[263];
      final nose = points[1];
      tilt = math.atan2(rightEye.y - leftEye.y, rightEye.x - leftEye.x) * 180 / math.pi;
      final eyeMid = (leftEye.x + rightEye.x) / 2;
      final eyeWidth = (rightEye.x - leftEye.x).abs();
      if (eyeWidth > .01) orientation = (nose.x - eyeMid) / eyeWidth;
      // This is only a recapture heuristic, not a clinical or anatomical angle.
      if (orientation != null && orientation.abs() > .20) issues.add(ScanIssue.headTurned);
      if (tilt.abs() > 12) issues.add(ScanIssue.headTurned);
    } else {
      issues.add(ScanIssue.missingLandmarks);
    }

    final reliable = result.faces.length == 1 && points.length >= 468 &&
        !issues.contains(ScanIssue.offCenter) && !issues.contains(ScanIssue.tooSmall) &&
        !issues.contains(ScanIssue.tooLarge) && !issues.contains(ScanIssue.headTurned) &&
        !issues.contains(ScanIssue.missingLandmarks);
    return ImageQualityReport(
      issues: _distinct(issues),
      meanLuma: pixelReport.meanLuma,
      laplacianVariance: pixelReport.laplacianVariance,
      observations: FaceObservations(
        faceCount: result.faces.length,
        landmarkCount: points.length,
        faceCenterX: centerX,
        faceCenterY: centerY,
        faceWidthRatio: width,
        faceHeightRatio: height,
        eyeLineTiltDegrees: tilt,
        orientationProxy: orientation,
        measurementsReliable: reliable,
      ),
    );
  }

  List<ScanIssue> _distinct(List<ScanIssue> values) => values.toSet().toList(growable: false);
}
