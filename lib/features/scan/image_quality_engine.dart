import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../domain/models.dart';

class PixelQuality {
  const PixelQuality({required this.meanLuma, required this.laplacianVariance, required this.issues});
  final double meanLuma;
  final double laplacianVariance;
  final List<ScanIssue> issues;
}

abstract interface class ImageQualityEngine {
  Future<PixelQuality> inspect(Uint8List encodedImage);
}

class LocalImageQualityEngine implements ImageQualityEngine {
  const LocalImageQualityEngine();

  @override
  Future<PixelQuality> inspect(Uint8List encodedImage) =>
      compute(_inspectImageBytes, encodedImage);
}

PixelQuality _inspectImageBytes(Uint8List encoded) {
  final decoded = img.decodeImage(encoded);
  if (decoded == null || decoded.width < 100 || decoded.height < 100) {
    throw const FormatException('The captured image could not be decoded or is too small.');
  }
  final width = math.min(decoded.width, 240).toInt();
  final resized = img.copyResize(decoded, width: width);
  final luminance = List<double>.filled(resized.width * resized.height, 0);
  var sum = 0.0;
  var offset = 0;
  for (var y = 0; y < resized.height; y++) {
    for (var x = 0; x < resized.width; x++) {
      final pixel = resized.getPixel(x, y);
      final value = .2126 * pixel.r + .7152 * pixel.g + .0722 * pixel.b;
      luminance[offset++] = value;
      sum += value;
    }
  }
  final mean = sum / luminance.length;
  final laplacians = <double>[];
  final stride = resized.width;
  for (var y = 1; y < resized.height - 1; y += 2) {
    for (var x = 1; x < resized.width - 1; x += 2) {
      final i = y * stride + x;
      laplacians.add(
        luminance[i - stride] + luminance[i + stride] +
        luminance[i - 1] + luminance[i + 1] - 4 * luminance[i],
      );
    }
  }
  final lapMean = laplacians.isEmpty ? 0 : laplacians.reduce((a, b) => a + b) / laplacians.length;
  final variance = laplacians.isEmpty
      ? 0.0
      : laplacians.map((v) => (v - lapMean) * (v - lapMean)).reduce((a, b) => a + b) / laplacians.length;
  final issues = <ScanIssue>[];
  // Heuristic thresholds are capture-quality guidance only; they do not measure skin or health.
  if (mean < 48) issues.add(ScanIssue.tooDark);
  if (mean > 238) issues.add(ScanIssue.tooBright);
  if (variance < 34) issues.add(ScanIssue.blurry);
  return PixelQuality(meanLuma: mean, laplacianVariance: variance, issues: issues);
}
