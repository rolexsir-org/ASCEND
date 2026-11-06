import '../../domain/models.dart';

class CoachingRecommendation {
  const CoachingRecommendation({
    required this.id,
    required this.title,
    required this.body,
    required this.minutes,
    required this.goal,
    required this.reason,
  });

  final String id;
  final String title;
  final String body;
  final int minutes;
  final CoachGoal goal;
  final String reason;
}

class LocalCoachEngine {
  const LocalCoachEngine();
  static const ruleVersion = 1;

  List<CoachingRecommendation> buildRecommendations({
    required UserPreferences preferences,
    FaceObservations? validatedObservations,
    double completionRate = 0,
    Map<String, int> userFeedback = const {},
  }) {
    if (!preferences.onboardingComplete || preferences.goals.isEmpty) return const [];
    final selected = preferences.goals.toSet().toList(growable: false);
    final rules = <CoachGoal, CoachingRecommendation>{
      CoachGoal.skincare: const CoachingRecommendation(
        id: 'skin-basics-v1', title: 'Keep skincare simple',
        body: 'Build a consistent morning and evening habit around gentle cleansing and daily sun protection. Introduce one new cosmetic product at a time; this is routine guidance, not medical advice.',
        minutes: 4, goal: CoachGoal.skincare, reason: 'You selected skincare habits.',
      ),
      CoachGoal.hairstyle: CoachingRecommendation(
        id: 'hair-exploration-v1', title: 'Explore a low-maintenance cut',
        body: _hairSuggestion(preferences.hairStylePreference), minutes: 5,
        goal: CoachGoal.hairstyle, reason: 'Based on the hairstyle preference you selected.',
      ),
      CoachGoal.beard: CoachingRecommendation(
        id: 'beard-maintenance-v1', title: 'Set a simple beard routine',
        body: _beardSuggestion(preferences.beardPreference), minutes: 5,
        goal: CoachGoal.beard, reason: 'Based on the grooming preference you selected.',
      ),
      CoachGoal.personalStyle: const CoachingRecommendation(
        id: 'style-edit-v1', title: 'Make one outfit easier to repeat',
        body: 'Choose a comfortable, well-fitting outfit you already own. Note what feels practical, then build one repeatable combination around your preferred colors and daily needs.',
        minutes: 8, goal: CoachGoal.personalStyle, reason: 'You selected personal style.',
      ),
      CoachGoal.posture: const CoachingRecommendation(
        id: 'posture-break-v1', title: 'Add a movement reset',
        body: 'During a long sitting block, stand, relax your shoulders, and move gently for a minute. Keep the movement comfortable; stop if it causes pain.',
        minutes: 2, goal: CoachGoal.posture, reason: 'You selected posture and everyday movement.',
      ),
    };

    final recommendations = selected.map((goal) => rules[goal]!).toList();
    recommendations.sort((a, b) {
      final aScore = (userFeedback[a.id] ?? 0) + (a.minutes <= preferences.dailyMinutes ? 2 : 0);
      final bScore = (userFeedback[b.id] ?? 0) + (b.minutes <= preferences.dailyMinutes ? 2 : 0);
      return bScore.compareTo(aScore);
    });

    // Completion history adjusts pacing only; it never creates a new facial finding.
    final adjusted = recommendations.map((item) {
      if (completionRate < .35 && item.minutes > 4) {
        return CoachingRecommendation(
          id: item.id, title: item.title, body: '${item.body} Keep the first step brief and repeatable.',
          minutes: item.minutes, goal: item.goal, reason: item.reason,
        );
      }
      return item;
    }).toList(growable: false);
    final scanIsValid = validatedObservations?.measurementsReliable == true &&
        validatedObservations?.faceCount == 1;
    // The scan is used only to disclose capture validity, never to rank or infer appearance.
    if (scanIsValid && adjusted.isNotEmpty) return adjusted.take(3).toList(growable: false);
    return adjusted.take(3).toList(growable: false);
  }

  CoachingPlan createPlan({
    required UserPreferences preferences,
    required DateTime startDate,
    double completionRate = 0,
    Map<String, int> userFeedback = const {},
    String? planId,
    bool isPro = false,
  }) {
    final goals = preferences.goals.toSet().toList(growable: false);
    if (goals.isEmpty) throw ArgumentError('At least one coaching goal is required.');
    final dayStart = DateTime(startDate.year, startDate.month, startDate.day);
    final idSuffix = goals.map(enumName).join('-');
    final resolvedPlanId = planId ?? 'plan-${dayStart.year}${dayStart.month.toString().padLeft(2, '0')}${dayStart.day.toString().padLeft(2, '0')}-$idSuffix';
    final maxTasksPerDay = isPro ? (preferences.dailyMinutes ~/ 5).clamp(1, 3).toInt() : 1;
    final tasks = <DailyTask>[];
    for (var day = 1; day <= 90; day++) {
      final phase = day <= 30 ? 1 : day <= 60 ? 2 : 3;
      final phaseGoalOffset = completionRate < .4 && phase > 1 ? 1 : 0;
      final count = goals.length < maxTasksPerDay ? goals.length : maxTasksPerDay;
      for (var slotIndex = 0; slotIndex < count; slotIndex++) {
        final goalIndex = (day + slotIndex + phaseGoalOffset - 1) % goals.length;
        final goal = goals[goalIndex];
        final slot = ((day + slotIndex) % 2 == 0) ? 'morning' : 'evening';
        final template = _taskFor(goal, phase, preferences);
        tasks.add(DailyTask(
          id: '$resolvedPlanId-day-$day-${enumName(goal)}-$slotIndex',
          dayIndex: day,
          goal: goal,
          title: template.$1,
          instruction: template.$2,
          minutes: template.$3.clamp(1, preferences.dailyMinutes).toInt(),
          slot: slot,
        ));
      }
    }
    return CoachingPlan(
      id: resolvedPlanId,
      createdAt: DateTime.now().toUtc(),
      startDate: dayStart,
      tasks: List.unmodifiable(tasks),
      version: ruleVersion,
      isProPlan: isPro,
      feedback: Map.unmodifiable(userFeedback),
    );
  }

  List<({int day, String title, String description})> milestones() => const [
    (day: 30, title: 'Foundation', description: 'Review which habits felt practical and keep the ones you can repeat.'),
    (day: 60, title: 'Development', description: 'Refine routines around your preferences and available time.'),
    (day: 90, title: 'Consistency', description: 'Choose a sustainable routine for the next month; missed days are expected and recoverable.'),
  ];

  (String, String, int) _taskFor(CoachGoal goal, int phase, UserPreferences preferences) {
    final detail = switch (goal) {
      CoachGoal.skincare => (
        'Follow your basic skincare habit',
        'Use the simple routine you chose. Avoid adding multiple new products at once. For skin concerns, consult a qualified clinician.',
        4,
      ),
      CoachGoal.hairstyle => (
        phase == 1 ? 'Save one haircut reference' : phase == 2 ? 'Compare two styling options' : 'Review your maintenance routine',
        _hairSuggestion(preferences.hairStylePreference),
        6,
      ),
      CoachGoal.beard => (
        'Maintain your preferred facial-hair routine',
        _beardSuggestion(preferences.beardPreference),
        5,
      ),
      CoachGoal.personalStyle => (
        phase == 1 ? 'Choose a reliable outfit' : phase == 2 ? 'Try one useful combination' : 'Review what you wear most',
        'Work with clothes you already own. Prioritize comfort, fit, care, and your own preferences rather than comparison.',
        8,
      ),
      CoachGoal.posture => (
        'Take a comfortable movement break',
        'Stand or change position during one long sitting block. Move gently and stop if uncomfortable.',
        2,
      ),
    };
    return detail;
  }

  static String _hairSuggestion(String preference) => switch (preference) {
    'short' => 'Explore short cuts that fit your styling time. Ask a barber about upkeep frequency before choosing.',
    'medium' => 'Collect medium-length styles that match your daily styling time and preferred texture.',
    'long' => 'Explore longer styles with practical care routines that fit your schedule.',
    'classic' => 'Save a classic, easy-to-maintain reference and discuss realistic upkeep with a barber.',
    _ => 'Save two styles you personally like, then compare their maintenance time with your routine.',
  };

  static String _beardSuggestion(String preference) => switch (preference) {
    'clean_shaven' => 'Use a gentle shaving routine that suits your preferences. Keep tools clean and avoid shaving over irritated skin.',
    'short_beard' => 'Choose a comfortable trim length and set a repeatable maintenance interval. Use clean tools.',
    'mustache' => 'Set a simple mustache tidy-up habit and keep tools clean.',
    _ => 'Choose the facial-hair style you prefer, then use a simple, comfortable maintenance routine.',
  };
}
