import 'dart:convert';
import 'dart:math';

String newLocalId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

enum CoachGoal { skincare, hairstyle, beard, personalStyle, posture }

enum ExperienceLevel { newToRoutine, someExperience, established }

enum RoutineTime { fiveMinutes, tenMinutes, twentyMinutes, thirtyMinutes }

enum TaskState { pending, completed, skipped }

enum ScanIssue {
  tooDark,
  tooBright,
  blurry,
  noFace,
  multipleFaces,
  offCenter,
  tooSmall,
  tooLarge,
  headTurned,
  missingLandmarks,
  unsupportedModel,
  modelUnavailable,
}

String enumName(Object value) => value.toString().split('.').last;

T enumFromName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final value in values) {
    if (enumName(value) == name) return value;
  }
  return fallback;
}

Map<String, Object?> jsonMap(Object? value) =>
    Map<String, Object?>.from(value! as Map);

class UserPreferences {
  const UserPreferences({
    this.id = 'primary',
    this.ageConfirmed = false,
    this.goals = const [],
    this.hairStylePreference = 'open_to_suggestions',
    this.beardPreference = 'clean_shaven_or_flexible',
    this.groomingPreferences = const [],
    this.dailyMinutes = 10,
    this.experience = ExperienceLevel.newToRoutine,
    this.privacyConsent = false,
    this.privacyConsentAt,
    this.onboardingComplete = false,
  });

  final String id;
  final bool ageConfirmed;
  final List<CoachGoal> goals;
  final String hairStylePreference;
  final String beardPreference;
  final List<String> groomingPreferences;
  final int dailyMinutes;
  final ExperienceLevel experience;
  final bool privacyConsent;
  final DateTime? privacyConsentAt;
  final bool onboardingComplete;

  UserPreferences copyWith({
    String? id,
    bool? ageConfirmed,
    List<CoachGoal>? goals,
    String? hairStylePreference,
    String? beardPreference,
    List<String>? groomingPreferences,
    int? dailyMinutes,
    ExperienceLevel? experience,
    bool? privacyConsent,
    DateTime? privacyConsentAt,
    bool? onboardingComplete,
  }) => UserPreferences(
    id: id ?? this.id,
    ageConfirmed: ageConfirmed ?? this.ageConfirmed,
    goals: goals ?? this.goals,
    hairStylePreference: hairStylePreference ?? this.hairStylePreference,
    beardPreference: beardPreference ?? this.beardPreference,
    groomingPreferences: groomingPreferences ?? this.groomingPreferences,
    dailyMinutes: dailyMinutes ?? this.dailyMinutes,
    experience: experience ?? this.experience,
    privacyConsent: privacyConsent ?? this.privacyConsent,
    privacyConsentAt: privacyConsentAt ?? this.privacyConsentAt,
    onboardingComplete: onboardingComplete ?? this.onboardingComplete,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'ageConfirmed': ageConfirmed,
    'goals': goals.map(enumName).toList(),
    'hairStylePreference': hairStylePreference,
    'beardPreference': beardPreference,
    'groomingPreferences': groomingPreferences,
    'dailyMinutes': dailyMinutes,
    'experience': enumName(experience),
    'privacyConsent': privacyConsent,
    'privacyConsentAt': privacyConsentAt?.toUtc().toIso8601String(),
    'onboardingComplete': onboardingComplete,
  };

  factory UserPreferences.fromJson(Map<String, Object?> json) => UserPreferences(
    id: json['id'] as String? ?? 'primary',
    ageConfirmed: json['ageConfirmed'] as bool? ?? false,
    goals: (json['goals'] as List<Object?>? ?? const [])
        .map((name) => enumFromName(CoachGoal.values, name, CoachGoal.skincare))
        .toList(growable: false),
    hairStylePreference: json['hairStylePreference'] as String? ?? 'open_to_suggestions',
    beardPreference: json['beardPreference'] as String? ?? 'clean_shaven_or_flexible',
    groomingPreferences: (json['groomingPreferences'] as List<Object?>? ?? const [])
        .whereType<String>().toList(growable: false),
    dailyMinutes: (json['dailyMinutes'] as num?)?.toInt() ?? 10,
    experience: enumFromName(
      ExperienceLevel.values,
      json['experience'],
      ExperienceLevel.newToRoutine,
    ),
    privacyConsent: json['privacyConsent'] as bool? ?? false,
    privacyConsentAt: json['privacyConsentAt'] == null
        ? null
        : DateTime.tryParse(json['privacyConsentAt']! as String)?.toUtc(),
    onboardingComplete: json['onboardingComplete'] as bool? ?? false,
  );
}

class FaceObservations {
  const FaceObservations({
    required this.faceCount,
    required this.landmarkCount,
    required this.faceCenterX,
    required this.faceCenterY,
    required this.faceWidthRatio,
    required this.faceHeightRatio,
    required this.eyeLineTiltDegrees,
    required this.orientationProxy,
    required this.measurementsReliable,
  });

  final int faceCount;
  final int landmarkCount;
  final double? faceCenterX;
  final double? faceCenterY;
  final double? faceWidthRatio;
  final double? faceHeightRatio;
  final double? eyeLineTiltDegrees;
  final double? orientationProxy;
  final bool measurementsReliable;

  Map<String, Object?> toJson() => {
    'faceCount': faceCount,
    'landmarkCount': landmarkCount,
    'faceCenterX': faceCenterX,
    'faceCenterY': faceCenterY,
    'faceWidthRatio': faceWidthRatio,
    'faceHeightRatio': faceHeightRatio,
    'eyeLineTiltDegrees': eyeLineTiltDegrees,
    'orientationProxy': orientationProxy,
    'measurementsReliable': measurementsReliable,
  };

  factory FaceObservations.fromJson(Map<String, Object?> json) => FaceObservations(
    faceCount: (json['faceCount'] as num?)?.toInt() ?? 0,
    landmarkCount: (json['landmarkCount'] as num?)?.toInt() ?? 0,
    faceCenterX: (json['faceCenterX'] as num?)?.toDouble(),
    faceCenterY: (json['faceCenterY'] as num?)?.toDouble(),
    faceWidthRatio: (json['faceWidthRatio'] as num?)?.toDouble(),
    faceHeightRatio: (json['faceHeightRatio'] as num?)?.toDouble(),
    eyeLineTiltDegrees: (json['eyeLineTiltDegrees'] as num?)?.toDouble(),
    orientationProxy: (json['orientationProxy'] as num?)?.toDouble(),
    measurementsReliable: json['measurementsReliable'] as bool? ?? false,
  );
}

class ImageQualityReport {
  const ImageQualityReport({
    required this.issues,
    required this.meanLuma,
    required this.laplacianVariance,
    required this.observations,
  });

  final List<ScanIssue> issues;
  final double? meanLuma;
  final double? laplacianVariance;
  final FaceObservations observations;

  bool get accepted => issues.isEmpty && observations.faceCount == 1 &&
      observations.measurementsReliable;

  Map<String, Object?> toJson() => {
    'issues': issues.map(enumName).toList(),
    'meanLuma': meanLuma,
    'laplacianVariance': laplacianVariance,
    'observations': observations.toJson(),
  };

  factory ImageQualityReport.fromJson(Map<String, Object?> json) => ImageQualityReport(
    issues: (json['issues'] as List<Object?>? ?? const [])
        .map((name) => enumFromName(ScanIssue.values, name, ScanIssue.missingLandmarks))
        .toList(growable: false),
    meanLuma: (json['meanLuma'] as num?)?.toDouble(),
    laplacianVariance: (json['laplacianVariance'] as num?)?.toDouble(),
    observations: FaceObservations.fromJson(jsonMap(json['observations'])),
  );
}

class ScanRecord {
  const ScanRecord({
    required this.id,
    required this.createdAt,
    required this.quality,
    required this.measurements,
    required this.photoFileName,
    this.userNote = '',
  });

  final String id;
  final DateTime createdAt;
  final ImageQualityReport quality;
  final FaceObservations measurements;
  final String photoFileName;
  final String userNote;

  Map<String, Object?> toJson() => {
    'id': id,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'quality': quality.toJson(),
    'measurements': measurements.toJson(),
    'photoFileName': photoFileName,
    'userNote': userNote,
  };

  factory ScanRecord.fromJson(Map<String, Object?> json) => ScanRecord(
    id: json['id']! as String,
    createdAt: DateTime.parse(json['createdAt']! as String).toUtc(),
    quality: ImageQualityReport.fromJson(jsonMap(json['quality'])),
    measurements: FaceObservations.fromJson(jsonMap(json['measurements'])),
    photoFileName: json['photoFileName']! as String,
    userNote: json['userNote'] as String? ?? '',
  );
}

class DailyTask {
  const DailyTask({
    required this.id,
    required this.dayIndex,
    required this.goal,
    required this.title,
    required this.instruction,
    required this.minutes,
    required this.slot,
    this.state = TaskState.pending,
  });

  final String id;
  final int dayIndex;
  final CoachGoal goal;
  final String title;
  final String instruction;
  final int minutes;
  final String slot;
  final TaskState state;

  DailyTask copyWith({TaskState? state, String? title, String? instruction}) => DailyTask(
    id: id,
    dayIndex: dayIndex,
    goal: goal,
    title: title ?? this.title,
    instruction: instruction ?? this.instruction,
    minutes: minutes,
    slot: slot,
    state: state ?? this.state,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'dayIndex': dayIndex,
    'goal': enumName(goal),
    'title': title,
    'instruction': instruction,
    'minutes': minutes,
    'slot': slot,
    'state': enumName(state),
  };

  factory DailyTask.fromJson(Map<String, Object?> json) => DailyTask(
    id: json['id']! as String,
    dayIndex: (json['dayIndex'] as num).toInt(),
    goal: enumFromName(CoachGoal.values, json['goal'], CoachGoal.skincare),
    title: json['title']! as String,
    instruction: json['instruction']! as String,
    minutes: (json['minutes'] as num).toInt(),
    slot: json['slot']! as String,
    state: enumFromName(TaskState.values, json['state'], TaskState.pending),
  );
}

class CoachingPlan {
  const CoachingPlan({
    required this.id,
    required this.createdAt,
    required this.startDate,
    required this.tasks,
    required this.version,
    this.isProPlan = false,
    this.feedback = const {},
  });

  final String id;
  final DateTime createdAt;
  final DateTime startDate;
  final List<DailyTask> tasks;
  final int version;
  final bool isProPlan;
  final Map<String, int> feedback;

  Map<String, Object?> toJson() => {
    'id': id,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'startDate': DateTime(startDate.year, startDate.month, startDate.day).toIso8601String(),
    'tasks': tasks.map((task) => task.toJson()).toList(),
    'version': version,
    'isProPlan': isProPlan,
    'feedback': feedback,
  };

  factory CoachingPlan.fromJson(Map<String, Object?> json) => CoachingPlan(
    id: json['id']! as String,
    createdAt: DateTime.parse(json['createdAt']! as String).toUtc(),
    startDate: DateTime.parse(json['startDate']! as String),
    tasks: (json['tasks'] as List<Object?>)
        .map((task) => DailyTask.fromJson(jsonMap(task))).toList(growable: false),
    version: (json['version'] as num).toInt(),
    isProPlan: json['isProPlan'] as bool? ?? false,
    feedback: Map<String, int>.from(json['feedback'] as Map? ?? const {}),
  );
}

class ProgressCheckIn {
  const ProgressCheckIn({required this.id, required this.date, required this.note});
  final String id;
  final DateTime date;
  final String note;

  Map<String, Object?> toJson() => {
    'id': id, 'date': date.toUtc().toIso8601String(), 'note': note,
  };

  factory ProgressCheckIn.fromJson(Map<String, Object?> json) => ProgressCheckIn(
    id: json['id']! as String,
    date: DateTime.parse(json['date']! as String).toUtc(),
    note: json['note'] as String? ?? '',
  );
}

String encodeJson(Map<String, Object?> value) => jsonEncode(value);
