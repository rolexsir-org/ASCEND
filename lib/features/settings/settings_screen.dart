import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_services.dart';
import '../../core/theme/ascend_theme.dart';
import '../../domain/models.dart';
import '../notifications/reminder_service.dart';
import '../subscription/subscription_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late Future<UserPreferences> _preferencesFuture;
  late Future<Map<ReminderKind, ReminderPreference>> _remindersFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final services = ref.read(appServicesProvider);
    _preferencesFuture = services.repository.getPreferences();
    _remindersFuture = services.reminders.loadPreferences();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings & privacy')),
    body: RefreshIndicator(
      onRefresh: () async => setState(_load),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
        children: [
          Text('Your data stays yours.', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('No mandatory account. Scan images and observations stay on this device.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          _preferencesSection(context),
          const SizedBox(height: 18),
          _reminderSection(context),
          const SizedBox(height: 18),
          _subscriptionSection(context),
          const SizedBox(height: 18),
          Text('Privacy and local data', style: Theme.of(context).textTheme.titleLarge),
          Card(child: Column(children: [
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined, color: AscendColors.gold),
              title: const Text('Privacy policy'),
              subtitle: const Text('Local processing, storage, retention and billing data.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/privacy'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.description_outlined, color: AscendColors.gold),
              title: const Text('Terms of use'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/terms'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined, color: AscendColors.error),
              title: const Text('Delete progress history'),
              subtitle: const Text('Remove scans, photos and check-in notes; keep your plan and preferences.'),
              onTap: _busy ? null : _deleteProgress,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined, color: AscendColors.error),
              title: const Text('Delete all local data'),
              subtitle: const Text('Remove profile, photos, routines, progress, reminders and cached entitlement.'),
              onTap: _busy ? null : _deleteAllData,
            ),
          ])),
          const SizedBox(height: 10),
          Text('Photos are encrypted with AES-GCM in app-private storage. Structured personal data is encrypted before it is written to SQLite. Android Keystore-backed secure storage protects the data key.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          Text('ASCEND · Build yourself. Track your progress. Ascend.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          if (_busy) const Padding(padding: EdgeInsets.only(top: 16), child: Center(child: CircularProgressIndicator())),
        ],
      ),
    ),
  );

  Widget _preferencesSection(BuildContext context) => FutureBuilder<UserPreferences>(
    future: _preferencesFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const LinearProgressIndicator();
      if (snapshot.hasError || snapshot.data == null) return const ListTile(title: Text('Preferences unavailable'), subtitle: Text('Saved profile data could not be decrypted.'));
      final preferences = snapshot.data!;
      return Card(child: Column(children: [
        ListTile(
          leading: const Icon(Icons.tune, color: AscendColors.gold),
          title: const Text('Coaching preferences'),
          subtitle: Text('${preferences.goals.length} goals · ${preferences.dailyMinutes} min/day · ${_experience(preferences.experience)}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _busy ? null : () => _editPreferences(preferences),
        ),
        if (preferences.onboardingComplete)
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 14), child: Text('Changing goals updates local recommendations. Existing plan tasks remain unchanged unless you explicitly generate a new plan.', style: Theme.of(context).textTheme.bodyMedium)),
      ]));
    },
  );

  Widget _reminderSection(BuildContext context) => FutureBuilder<Map<ReminderKind, ReminderPreference>>(
    future: _remindersFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const LinearProgressIndicator();
      if (snapshot.hasError || snapshot.data == null) return _errorSetting(context);
      final settings = snapshot.data!;
      return Card(child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Optional reminders', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Reminders are local, private and off until you choose a schedule.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          for (final kind in ReminderKind.values)
            _reminderRow(context, kind, settings[kind]!),
        ]),
      ));
    },
  );

  Widget _reminderRow(BuildContext context, ReminderKind kind, ReminderPreference preference) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_reminderLabel(kind), style: Theme.of(context).textTheme.bodyLarge),
        Text(kind == ReminderKind.weeklyCheckIn || kind == ReminderKind.rescan ? 'Weekly' : 'Daily', style: Theme.of(context).textTheme.bodyMedium),
      ])),
      TextButton(
        onPressed: preference.enabled && !_busy ? () => _pickReminderTime(kind, preference) : null,
        child: Text(_time(preference.hour, preference.minute)),
      ),
      Switch(
        value: preference.enabled,
        onChanged: _busy ? null : (enabled) => _toggleReminder(kind, preference, enabled),
      ),
    ]),
  );

  Widget _subscriptionSection(BuildContext context) => FutureBuilder<SubscriptionStatus>(
    future: ref.watch(subscriptionStatusProvider.future),
    builder: (context, snapshot) {
      final status = snapshot.data;
      final isPro = status?.isPro == true;
      return Card(child: Column(children: [
        ListTile(
          leading: Icon(isPro ? Icons.workspace_premium : Icons.star_outline, color: AscendColors.gold),
          title: Text(isPro ? 'ASCEND Pro is active' : 'ASCEND Pro'),
          subtitle: Text(isPro ? 'Your store entitlement is active.' : 'View plans, restore a purchase or continue with free.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/paywall'),
        ),
        if (isPro) ListTile(
          leading: const Icon(Icons.manage_accounts_outlined),
          title: const Text('Manage subscription'),
          onTap: _openSubscriptionManagement,
        ),
        ListTile(
          leading: const Icon(Icons.restore),
          title: const Text('Restore purchases'),
          onTap: _busy ? null : _restorePurchases,
        ),
      ]));
    },
  );

  Widget _errorSetting(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Reminders are unavailable', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 6),
      Text('Notification setup failed. Core routines are still available in ASCEND.', style: Theme.of(context).textTheme.bodyMedium),
    ]),
  ));

  Future<void> _editPreferences(UserPreferences current) async {
    final updated = await showDialog<UserPreferences>(context: context, builder: (context) => _PreferencesDialog(current: current));
    if (updated == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(appServicesProvider).repository.savePreferences(updated);
      ref.invalidate(preferencesProvider);
      await _regeneratePlanPrompt(updated);
      setState(_load);
    } on Object {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preferences could not be saved securely.')));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _regeneratePlanPrompt(UserPreferences preferences) async {
    if (!preferences.onboardingComplete) return;
    final regenerate = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Update your 90-day plan?'),
      content: const Text('Your previous plan stays in local history. A new plan starts today with your updated goals; no completed task history is deleted.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep current plan')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create new plan'))],
    ));
    if (regenerate == true && mounted) {
      final services = ref.read(appServicesProvider);
      final plan = services.coach.createPlan(preferences: preferences, startDate: DateTime.now(), planId: 'plan-${newLocalId()}');
      await services.repository.savePlan(plan);
      ref.invalidate(planProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New plan created. The previous plan remains stored on this device.')));
    }
  }

  Future<void> _toggleReminder(ReminderKind kind, ReminderPreference old, bool enabled) async {
    if (enabled && !(await ref.read(appServicesProvider).subscriptions.refreshStatus()).isPro) {
      if (mounted) await context.push('/paywall');
      return;
    }
    if (enabled) {
      if (!mounted) return;
      final explained = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: const Text('Allow ASCEND reminders?'),
        content: const Text('ASCEND will schedule only the routine reminders you turn on. Notifications will not include photos or facial information.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue'))],
      ));
      if (explained != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final ok = await ref.read(appServicesProvider).reminders.setReminder(
        kind,
        ReminderPreference(enabled: enabled, hour: old.hour, minute: old.minute),
        permissionAlreadyExplained: enabled,
      );
      if (!ok && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification permission was not granted. You can still use all local routine features.')));
      setState(_load);
    } on Object {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The reminder schedule could not be saved.')));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _pickReminderTime(ReminderKind kind, ReminderPreference old) async {
    if (!(await ref.read(appServicesProvider).subscriptions.refreshStatus()).isPro) {
      if (mounted) await context.push('/paywall');
      return;
    }
    if (!mounted) return;
    final selected = await showTimePicker(context: context, initialTime: TimeOfDay(hour: old.hour, minute: old.minute));
    if (selected == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(appServicesProvider).reminders.setReminder(
        kind,
        ReminderPreference(enabled: true, hour: selected.hour, minute: selected.minute),
        permissionAlreadyExplained: true,
      );
      setState(_load);
    } on Object {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The reminder time could not be updated.')));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _restorePurchases() async {
    setState(() => _busy = true);
    final services = ref.read(appServicesProvider);
    final result = await services.subscriptions.restore();
    if (result.state == PurchaseState.purchased) {
      try { await services.reminders.restoreScheduledReminders(); } on Object { /* Reminders are optional; restore the verified subscription regardless. */ }
    }
    if (mounted) {
      ref.invalidate(subscriptionStatusProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message ?? (result.state == PurchaseState.purchased ? 'Purchase restored.' : 'No purchase was restored.'))));
      setState(() => _busy = false);
    }
  }

  Future<void> _openSubscriptionManagement() async {
    try { await ref.read(appServicesProvider).subscriptions.openSubscriptionManagement(); }
    on Object {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google Play subscription settings could not be opened on this device.')));
    }
  }

  Future<void> _deleteProgress() async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Delete progress history?'),
      content: const Text('This deletes saved scan photos, scan observations and weekly check-ins. Your preferences and plan will remain.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete history'))],
    ));
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(appServicesProvider).repository.deleteProgressHistory();
      setState(_load);
    } on Object {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Progress history could not be fully removed. Retry or use Delete all local data.')));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _deleteAllData() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Delete all local ASCEND data?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("This permanently removes profile choices, scans and photos, plans, routines, check-ins, reminders and ASCEND's local purchase cache from this device. It does not cancel a Google Play subscription; cancel separately in Google Play. A verified purchase can be restored later. Type DELETE to confirm."),
          const SizedBox(height: 12),
          TextField(controller: controller, onChanged: (_) => setDialogState(() {}), decoration: const InputDecoration(labelText: 'Type DELETE')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(
          onPressed: controller.text == 'DELETE' ? () => Navigator.pop(context, true) : null,
          child: const Text('Erase all local data'),
        )],
      ),
    ));
    final typed = controller.text;
    controller.dispose();
    if (confirmed != true || typed != 'DELETE' || !mounted) return;
    setState(() => _busy = true);
    try {
      final services = ref.read(appServicesProvider);
      await services.reminders.cancelAll();
      await services.subscriptions.invalidateLocalCustomerInfoCache();
      await services.repository.deleteAllLocalData();
      ref.invalidate(preferencesProvider);
      ref.invalidate(planProvider);
      ref.invalidate(subscriptionStatusProvider);
      if (mounted) context.go('/onboarding');
    } on Object {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data deletion did not complete. Encrypted data was preserved where possible. Retry this action.')));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  String _experience(ExperienceLevel value) => switch (value) {
    ExperienceLevel.newToRoutine => 'new to routines', ExperienceLevel.someExperience => 'some experience', ExperienceLevel.established => 'established routine',
  };

  String _reminderLabel(ReminderKind kind) => switch (kind) {
    ReminderKind.morning => 'Morning routine', ReminderKind.evening => 'Evening routine',
    ReminderKind.weeklyCheckIn => 'Weekly check-in', ReminderKind.rescan => 'Rescan reminder',
  };

  String _time(int hour, int minute) => TimeOfDay(hour: hour, minute: minute).format(context);
}

class _PreferencesDialog extends StatefulWidget {
  const _PreferencesDialog({required this.current});
  final UserPreferences current;
  @override
  State<_PreferencesDialog> createState() => _PreferencesDialogState();
}

class _PreferencesDialogState extends State<_PreferencesDialog> {
  late final Set<CoachGoal> _goals = {...widget.current.goals};
  late int _minutes = widget.current.dailyMinutes;
  late ExperienceLevel _experience = widget.current.experience;
  late String _hair = widget.current.hairStylePreference;
  late String _beard = widget.current.beardPreference;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Coaching preferences'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        const Text('Goals'),
        Wrap(spacing: 6, children: [for (final goal in CoachGoal.values) FilterChip(
          label: Text(_label(goal)), selected: _goals.contains(goal),
          onSelected: (selected) => setState(() => selected ? _goals.add(goal) : _goals.remove(goal)),
        )]),
        const SizedBox(height: 12),
        const Text('Daily time'),
        Wrap(spacing: 6, children: [for (final minutes in const [5, 10, 20, 30]) ChoiceChip(
          label: Text('$minutes min'), selected: _minutes == minutes, onSelected: (_) => setState(() => _minutes = minutes),
        )]),
        const SizedBox(height: 12),
        DropdownButtonFormField<ExperienceLevel>(
          initialValue: _experience,
          decoration: const InputDecoration(labelText: 'Experience'),
          items: const [
            DropdownMenuItem(value: ExperienceLevel.newToRoutine, child: Text('New to routines')),
            DropdownMenuItem(value: ExperienceLevel.someExperience, child: Text('Some experience')),
            DropdownMenuItem(value: ExperienceLevel.established, child: Text('Established routine')),
          ],
          onChanged: (value) => setState(() => _experience = value ?? _experience),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _hair,
          decoration: const InputDecoration(labelText: 'Hair preference'),
          items: const [
            DropdownMenuItem(value: 'open_to_suggestions', child: Text('Open to suggestions')),
            DropdownMenuItem(value: 'short', child: Text('Short')),
            DropdownMenuItem(value: 'medium', child: Text('Medium')),
            DropdownMenuItem(value: 'long', child: Text('Longer styles')),
            DropdownMenuItem(value: 'classic', child: Text('Classic')),
          ],
          onChanged: (value) => setState(() => _hair = value ?? _hair),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _beard,
          decoration: const InputDecoration(labelText: 'Facial-hair preference'),
          items: const [
            DropdownMenuItem(value: 'clean_shaven_or_flexible', child: Text('Flexible / deciding')),
            DropdownMenuItem(value: 'clean_shaven', child: Text('Clean-shaven')),
            DropdownMenuItem(value: 'short_beard', child: Text('Short beard')),
            DropdownMenuItem(value: 'mustache', child: Text('Mustache')),
          ],
          onChanged: (value) => setState(() => _beard = value ?? _beard),
        ),
      ])),
    ),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(
      onPressed: _goals.isEmpty ? null : () => Navigator.pop(context, widget.current.copyWith(
        goals: _goals.toList(), dailyMinutes: _minutes, experience: _experience,
        hairStylePreference: _hair, beardPreference: _beard,
      )),
      child: const Text('Save preferences'),
    )],
  );

  String _label(CoachGoal goal) => switch (goal) {
    CoachGoal.skincare => 'Skincare', CoachGoal.hairstyle => 'Hairstyle', CoachGoal.beard => 'Beard care',
    CoachGoal.personalStyle => 'Style', CoachGoal.posture => 'Posture',
  };
}
