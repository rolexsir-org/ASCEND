import 'package:ascend/main.dart' as ascend;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'fresh install completes consent onboarding and opens its saved plan',
    (tester) async {
      // Run on a disposable emulator/device with ASCEND app data cleared first.
      // No camera, billing account, purchase, or notification permission is needed.
      await ascend.main();
      await tester.pumpAndSettle();

      expect(find.text('A routine that fits your life.'), findsOneWidget);

      final ageConsent =
          find.text('I confirm that I am 18 years of age or older.');
      await tester.ensureVisible(ageConsent);
      await tester.tap(ageConsent);
      await tester.pumpAndSettle();

      final goal = find.text('Skincare habits');
      await tester.ensureVisible(goal);
      await tester.tap(goal);
      await tester.pumpAndSettle();

      final privacyConsent = find.text(
        'I have read the privacy explanation and consent to storing my selected preferences locally.',
      );
      await tester.ensureVisible(privacyConsent);
      await tester.tap(privacyConsent);
      await tester.pumpAndSettle();

      final createPlan = find.text('Create my local plan');
      await tester.ensureVisible(createPlan);
      final actionButton =
          find.ancestor(of: createPlan, matching: find.byType(FilledButton));
      expect(tester.widget<FilledButton>(actionButton.first).onPressed, isNotNull);
      await tester.tap(createPlan);
      await tester.pumpAndSettle();

      expect(find.text('Your next steps'), findsOneWidget);
      final openPlan = find.text('Open your 90-day plan');
      await tester.ensureVisible(openPlan);
      await tester.tap(openPlan);
      await tester.pumpAndSettle();

      expect(find.text('90-day plan'), findsOneWidget);
      expect(find.text('A plan that adapts to real life.'), findsOneWidget);
      expect(find.text('Milestones'), findsOneWidget);
    },
  );
}
