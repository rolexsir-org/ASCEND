import 'package:ascend/app/app_services.dart';
import 'package:ascend/app/ascend_app.dart';
import 'package:ascend/data/local_repository.dart';
import 'package:ascend/domain/models.dart';
import 'package:ascend/features/coach/local_coach_engine.dart';
import 'package:ascend/features/notifications/reminder_service.dart';
import 'package:ascend/features/scan/face_analysis_engine.dart';
import 'package:ascend/features/scan/image_quality_engine.dart';
import 'package:ascend/features/subscription/subscription_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryRepository extends Fake implements LocalRepository {
  @override
  Future<UserPreferences> getPreferences() async => const UserPreferences();
}

void main() {
  testWidgets('first launch shows local-consent onboarding without opening native services', (tester) async {
    final repository = _MemoryRepository();
    final services = AppServices(
      repository: repository,
      faceAnalysis: MediaPipeFaceAnalysisEngine(),
      imageQuality: const LocalImageQualityEngine(),
      faceGeometry: const FaceGeometryValidator(),
      coach: const LocalCoachEngine(),
      subscriptions: SubscriptionService(repository: repository),
      reminders: ReminderService(repository: repository),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [appServicesProvider.overrideWithValue(services)],
      child: const AscendApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('A routine that fits your life.'), findsOneWidget);
    final privacyText = find.textContaining('Face photographs are analyzed on this device only.');
    await tester.scrollUntilVisible(privacyText, 100);
    expect(privacyText, findsOneWidget);
    final submitButtonText = find.text('Create my local plan');
    await tester.scrollUntilVisible(submitButtonText, 100);
    expect(submitButtonText, findsOneWidget);
  });
}
