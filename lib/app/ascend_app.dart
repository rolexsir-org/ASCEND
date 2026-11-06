import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/ascend_theme.dart';
import 'router.dart';

class AscendApp extends ConsumerWidget {
  const AscendApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'ASCEND',
      debugShowCheckedModeBanner: false,
      theme: AscendTheme.dark,
      routerConfig: router,
    );
  }
}

class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({required this.message, super.key});
  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ASCEND',
    theme: AscendTheme.dark,
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined, size: 42, color: AscendColors.gold),
                const SizedBox(height: 20),
                Text('Your local data was not changed', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 20),
                Text(
                  'Restart after resolving the storage or migration issue. ASCEND will not erase existing data to recover automatically.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
