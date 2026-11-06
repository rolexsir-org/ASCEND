import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_services.dart';
import '../../core/theme/ascend_theme.dart';
import '../../domain/models.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _adult = false;
  bool _consent = false;
  bool _saving = false;
  String _hair = 'open_to_suggestions';
  String _beard = 'clean_shaven_or_flexible';
  int _minutes = 10;
  ExperienceLevel _experience = ExperienceLevel.newToRoutine;
  final Set<CoachGoal> _goals = {};
  final Set<String> _preferences = {'simple', 'low_maintenance'};
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                  sliver: SliverList.list(children: [
                    const Text('ASCEND', style: TextStyle(color: AscendColors.gold, letterSpacing: 2.4, fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 32),
                    Text('A routine that fits your life.', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text('Build yourself. Track your progress. Ascend.', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 28),
                    _sectionTitle(context, 'First, a quick eligibility check'),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _adult,
                      onChanged: (value) => setState(() => _adult = value ?? false),
                      title: const Text('I confirm that I am 18 years of age or older.'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle(context, 'What would you like to work on?'),
                    Text('Choose one or more. You can change these later.', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 4, children: [
                      for (final goal in CoachGoal.values)
                        FilterChip(
                          label: Text(_goalLabel(goal)),
                          selected: _goals.contains(goal),
                          onSelected: (selected) => setState(() {
                            selected ? _goals.add(goal) : _goals.remove(goal);
                          }),
                        ),
                    ]),
                    const SizedBox(height: 20),
                    _sectionTitle(context, 'Style and grooming preferences'),
                    DropdownButtonFormField<String>(
                      initialValue: _hair,
                      decoration: const InputDecoration(labelText: 'Hair direction'),
                      items: const [
                        DropdownMenuItem(value: 'open_to_suggestions', child: Text('Open to suggestions')),
                        DropdownMenuItem(value: 'short', child: Text('Short and practical')),
                        DropdownMenuItem(value: 'medium', child: Text('Medium length')),
                        DropdownMenuItem(value: 'long', child: Text('Longer styles')),
                        DropdownMenuItem(value: 'classic', child: Text('Classic and low maintenance')),
                      ],
                      onChanged: (value) => setState(() => _hair = value ?? _hair),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _beard,
                      decoration: const InputDecoration(labelText: 'Facial-hair preference'),
                      items: const [
                        DropdownMenuItem(value: 'clean_shaven_or_flexible', child: Text('Flexible / still deciding')),
                        DropdownMenuItem(value: 'clean_shaven', child: Text('Clean-shaven')),
                        DropdownMenuItem(value: 'short_beard', child: Text('Short beard')),
                        DropdownMenuItem(value: 'mustache', child: Text('Mustache')),
                      ],
                      onChanged: (value) => setState(() => _beard = value ?? _beard),
                    ),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 4, children: [
                      for (final item in const {'simple', 'low_maintenance', 'classic', 'experimental'})
                        FilterChip(
                          label: Text(_preferenceLabel(item)),
                          selected: _preferences.contains(item),
                          onSelected: (selected) => setState(() {
                            selected ? _preferences.add(item) : _preferences.remove(item);
                          }),
                        ),
                    ]),
                    const SizedBox(height: 20),
                    _sectionTitle(context, 'How much time feels realistic?'),
                    Wrap(spacing: 8, children: [
                      for (final value in const [5, 10, 20, 30])
                        ChoiceChip(
                          label: Text('$value min'),
                          selected: _minutes == value,
                          onSelected: (_) => setState(() => _minutes = value),
                        ),
                    ]),
                    const SizedBox(height: 20),
                    _sectionTitle(context, 'Your starting point'),
                    DropdownButtonFormField<ExperienceLevel>(
                      initialValue: _experience,
                      items: const [
                        DropdownMenuItem(value: ExperienceLevel.newToRoutine, child: Text('New to routines')),
                        DropdownMenuItem(value: ExperienceLevel.someExperience, child: Text('I have tried a few things')),
                        DropdownMenuItem(value: ExperienceLevel.established, child: Text('I have routines already')),
                      ],
                      onChanged: (value) => setState(() => _experience = value ?? _experience),
                    ),
                    const SizedBox(height: 20),
                    _sectionTitle(context, 'Your privacy comes first'),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AscendColors.surface,
                        border: Border.all(color: AscendColors.border),
                        borderRadius: BorderRadius.circular(AscendRadii.card),
                      ),
                      child: Text(
                        'Face photographs are analyzed on this device only. They are never sent to ASCEND, an AI provider, or a cloud photo service. If you choose to save a scan, the photo is encrypted in app-private storage. You can delete scans or erase all local data in Settings. No account is required.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/privacy'),
                      child: const Text('Read the privacy policy'),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _consent,
                      onChanged: (value) => setState(() => _consent = value ?? false),
                      title: const Text('I have read the privacy explanation and consent to storing my selected preferences locally.'),
                      controlAffinity: ListTileControlAffinity.leading,
                      subtitle: const Text('Photo capture and analysis require a separate consent each time.'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: AscendColors.error)),
                    ],
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _saving || !_adult || !_consent || _goals.isEmpty ? null : _complete,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()) : const Text('Create my local plan'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('No sign-up. No appearance score. No pressure to keep a streak.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(value, style: Theme.of(context).textTheme.titleLarge),
  );

  String _goalLabel(CoachGoal goal) => switch (goal) {
    CoachGoal.skincare => 'Skincare habits',
    CoachGoal.hairstyle => 'Hairstyle',
    CoachGoal.beard => 'Beard / facial hair',
    CoachGoal.personalStyle => 'Personal style',
    CoachGoal.posture => 'Posture and movement',
  };

  String _preferenceLabel(String item) => switch (item) {
    'low_maintenance' => 'Low maintenance',
    'experimental' => 'Try new things',
    'classic' => 'Classic',
    _ => 'Simple',
  };

  Future<void> _complete() async {
    setState(() { _saving = true; _error = null; });
    try {
      final now = DateTime.now();
      final preferences = UserPreferences(
        ageConfirmed: _adult,
        goals: _goals.toList(growable: false),
        hairStylePreference: _hair,
        beardPreference: _beard,
        groomingPreferences: _preferences.toList(growable: false),
        dailyMinutes: _minutes,
        experience: _experience,
        privacyConsent: _consent,
        privacyConsentAt: now,
        onboardingComplete: true,
      );
      final services = ref.read(appServicesProvider);
      final plan = services.coach.createPlan(preferences: preferences, startDate: DateTime.now());
      await services.repository.saveOnboarding(preferences, plan);
      ref.invalidate(preferencesProvider);
      ref.invalidate(planProvider);
      if (mounted) context.go('/coach');
    } on Object {
      if (mounted) setState(() => _error = 'Your choices could not be saved securely. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
