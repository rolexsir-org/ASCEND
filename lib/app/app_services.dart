import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/security/secure_vault.dart';
import '../data/local_database.dart';
import '../data/local_repository.dart';
import '../domain/models.dart';
import '../features/coach/local_coach_engine.dart';
import '../features/notifications/reminder_service.dart';
import '../features/scan/face_analysis_engine.dart';
import '../features/scan/image_quality_engine.dart';
import '../features/subscription/subscription_service.dart';

class AppServices {
  AppServices({
    required this.repository,
    required this.faceAnalysis,
    required this.imageQuality,
    required this.faceGeometry,
    required this.coach,
    required this.subscriptions,
    required this.reminders,
  });

  final LocalRepository repository;
  final FaceAnalysisEngine faceAnalysis;
  final ImageQualityEngine imageQuality;
  final FaceGeometryValidator faceGeometry;
  final LocalCoachEngine coach;
  final SubscriptionService subscriptions;
  final ReminderService reminders;

  static Future<AppServices> initialize() async {
    final database = await LocalDatabase.open();
    final vault = SecureVault();
    final photos = PrivatePhotoStore(vault);
    final repository = LocalRepository(localDatabase: database, vault: vault, photos: photos);
    try { await photos.clearTransientCameraCaptures(); } on Object {
      // Cache cleanup is best-effort; the scan screen still deletes every live capture.
    }
    await repository.initialize();
    final services = AppServices(
      repository: repository,
      faceAnalysis: MediaPipeFaceAnalysisEngine(),
      imageQuality: const LocalImageQualityEngine(),
      faceGeometry: const FaceGeometryValidator(),
      coach: const LocalCoachEngine(),
      subscriptions: SubscriptionService(repository: repository),
      reminders: ReminderService(repository: repository),
    );
    await services.subscriptions.initialize();
    await services.reminders.initialize();
    try {
      if ((await services.subscriptions.refreshStatus()).isPro) {
        await services.reminders.restoreScheduledReminders();
      } else {
        await services.reminders.cancelAll();
      }
    } on Object {
      // Notifications are optional and must not prevent the local coach from opening.
    }
    return services;
  }
}

final appServicesProvider = Provider<AppServices>((ref) {
  throw StateError('AppServices must be initialized before rendering ASCEND.');
});

final preferencesProvider = FutureProvider<UserPreferences>((ref) =>
    ref.watch(appServicesProvider).repository.getPreferences());

final subscriptionStatusProvider = FutureProvider<SubscriptionStatus>((ref) =>
    ref.watch(appServicesProvider).subscriptions.refreshStatus());

final planProvider = FutureProvider<CoachingPlan?>((ref) =>
    ref.watch(appServicesProvider).repository.getLatestPlan());
