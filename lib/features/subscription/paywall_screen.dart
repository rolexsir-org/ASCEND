import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../app/app_services.dart';
import '../../core/theme/ascend_theme.dart';
import 'subscription_service.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});
  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  late Future<List<Package>> _packages;
  String? _message;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _packages = ref.read(appServicesProvider).subscriptions.loadProPackages();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(tooltip: 'Close and continue with free', onPressed: _close, icon: const Icon(Icons.close)),
      title: const Text('ASCEND Pro'),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
        children: [
          const Icon(Icons.workspace_premium_outlined, color: AscendColors.gold, size: 42),
          const SizedBox(height: 16),
          Text('More consistency. More context.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text('A clear set of tools for tracking your routines over time.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          _feature('Weekly rescans', 'Repeat local capture checks no more often than once a week.'),
          _feature('Historical comparisons', 'View two saved photos side by side, with no claim that differences prove biological change.'),
          _feature('Expanded routines', 'More daily tasks, goal combinations, and routine options.'),
          _feature('Optional reminders', 'Set local morning, evening, weekly, or rescan reminders.'),
          const SizedBox(height: 18),
          Text('Choose a plan', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          FutureBuilder<List<Package>>(
            future: _packages,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(22), child: Center(child: CircularProgressIndicator()));
              if (snapshot.hasError) return _storeUnavailable(context, 'Google Play plans could not be loaded. Check your connection and try again.');
              final packages = snapshot.data ?? const <Package>[];
              if (packages.isEmpty) return _storeUnavailable(context, 'Store products are not configured or are not available for this Google Play account. No purchase can be started from this screen.');
              final monthly = packages.where((p) => p.storeProduct.identifier == monthlyProductId).toList();
              final annual = packages.where((p) => p.storeProduct.identifier == annualProductId).toList();
              return Column(children: [
                if (monthly.isNotEmpty) _planOption(context, monthly.first, 'Monthly'),
                if (annual.isNotEmpty) _planOption(context, annual.first, 'Annual'),
                if (monthly.isEmpty || annual.isEmpty)
                  Padding(padding: const EdgeInsets.only(top: 8), child: Text('One or more configured products were not returned by the store. Product prices are never substituted.', style: Theme.of(context).textTheme.bodyMedium)),
              ]);
            },
          ),
          if (_message != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_message!, style: Theme.of(context).textTheme.bodyMedium)),
          if (_busy) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: _busy ? null : _restore, icon: const Icon(Icons.restore), label: const Text('Restore purchases')),
          const SizedBox(height: 14),
          Text('Subscriptions renew automatically until cancelled. Google Play displays the authoritative localized price, billing period, trial eligibility and conversion terms before confirmation. Cancel or manage subscriptions in Google Play settings. No trial is advertised by ASCEND unless a valid eligible store offer is configured.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          Wrap(alignment: WrapAlignment.center, spacing: 18, children: [
            TextButton(onPressed: () => context.push('/terms'), child: const Text('Terms')),
            TextButton(onPressed: () => context.push('/privacy'), child: const Text('Privacy')),
          ]),
          TextButton(onPressed: _close, child: const Text('Continue with free')),
        ],
      ),
    ),
  );

  Widget _feature(String title, String detail) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.check, color: AscendColors.gold, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 3), Text(detail, style: Theme.of(context).textTheme.bodyMedium)])),
    ]),
  );

  Widget _planOption(BuildContext context, Package package, String title) {
    final product = package.storeProduct;
    final suffix = title == 'Monthly' ? 'per month' : 'per year';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('${product.priceString} $suffix', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 4),
            Text(product.identifier, style: Theme.of(context).textTheme.bodyMedium),
          ])),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: _busy ? null : () => _purchase(package),
            child: const Text('Continue'),
          ),
        ]),
      ),
    );
  }

  Widget _storeUnavailable(BuildContext context, String message) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AscendColors.surface, borderRadius: BorderRadius.circular(AscendRadii.card), border: Border.all(color: AscendColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.storefront_outlined, color: AscendColors.gold),
      const SizedBox(height: 8),
      Text(message, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 10),
      OutlinedButton(onPressed: _busy ? null : () => setState(() { _packages = ref.read(appServicesProvider).subscriptions.loadProPackages(); _message = null; }), child: const Text('Try again')),
    ]),
  );

  Future<void> _purchase(Package package) async {
    setState(() { _busy = true; _message = null; });
    final result = await ref.read(appServicesProvider).subscriptions.purchase(package);
    if (!mounted) return;
    switch (result.state) {
      case PurchaseState.purchased:
        ref.invalidate(subscriptionStatusProvider);
        try { await ref.read(appServicesProvider).reminders.restoreScheduledReminders(); } on Object { /* Reminder setup is optional and does not roll back the verified purchase. */ }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ASCEND Pro is active.')));
        context.pop();
        break;
      case PurchaseState.pending:
        setState(() => _message = result.message ?? 'Purchase is pending store confirmation. Pro features stay locked until verified.');
        break;
      case PurchaseState.cancelled:
        setState(() => _message = 'Purchase cancelled. You can continue with the free product.');
        break;
      case PurchaseState.failed:
      case PurchaseState.unavailable:
        setState(() => _message = result.message ?? 'The purchase could not be verified.');
        break;
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _restore() async {
    setState(() { _busy = true; _message = null; });
    final result = await ref.read(appServicesProvider).subscriptions.restore();
    if (!mounted) return;
    if (result.state == PurchaseState.purchased) {
      ref.invalidate(subscriptionStatusProvider);
      try { await ref.read(appServicesProvider).reminders.restoreScheduledReminders(); } on Object { /* Reminder setup is optional. */ }
      if (!mounted) return;
      setState(() => _message = result.message ?? 'Purchase restored.');
    } else {
      setState(() => _message = result.message ?? 'No active purchase was found.');
    }
    setState(() => _busy = false);
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/coach');
    }
  }
}
