import 'package:ascend/domain/models.dart';
import 'package:ascend/features/coach/local_coach_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = LocalCoachEngine();
  final preferences = UserPreferences(
    ageConfirmed: true,
    goals: const [CoachGoal.skincare, CoachGoal.hairstyle, CoachGoal.posture],
    dailyMinutes: 20,
    privacyConsent: true,
    onboardingComplete: true,
  );

  test('generates deterministic, local free and Pro task caps without appearance scores', () {
    final free = engine.createPlan(
      preferences: preferences,
      startDate: DateTime(2026, 1, 2),
      planId: 'free-test',
    );
    final pro = engine.createPlan(
      preferences: preferences,
      startDate: DateTime(2026, 1, 2),
      planId: 'pro-test',
      isPro: true,
    );

    expect(free.tasks, hasLength(90));
    expect(free.tasks.every((task) => task.dayIndex >= 1 && task.dayIndex <= 90), isTrue);
    expect(free.isProPlan, isFalse);
    expect(pro.isProPlan, isTrue);
    expect(pro.tasks, hasLength(270));
    expect(pro.tasks.map((task) => task.dayIndex).toSet(), hasLength(90));
    expect(pro.tasks.map((task) => task.dayIndex).toSet().every((day) =>
        pro.tasks.where((task) => task.dayIndex == day).length <= 3), isTrue);
    expect(free.toJson().keys, isNot(contains('attractivenessScore')));
    expect(free.toJson().keys, isNot(contains('diagnosis')));
  });

  test('requires goals and does not produce recommendations before consented onboarding', () {
    expect(
      engine.buildRecommendations(preferences: const UserPreferences()),
      isEmpty,
    );
    expect(
      () => engine.createPlan(preferences: const UserPreferences(), startDate: DateTime(2026)),
      throwsArgumentError,
    );
  });
}
