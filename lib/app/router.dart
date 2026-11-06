import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/coach/coach_screen.dart';
import '../features/navigation/app_shell.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/plan/plan_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/scan/coach_summary_screen.dart';
import '../features/scan/scan_screen.dart';
import '../features/settings/legal_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/subscription/paywall_screen.dart';
import 'app_services.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final repository = ref.watch(appServicesProvider).repository;
  final router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      final preferences = await repository.getPreferences();
      final isOnboarding = state.matchedLocation == '/onboarding';
      final isPublicLegal = state.matchedLocation == '/privacy' || state.matchedLocation == '/terms';
      if (!preferences.onboardingComplete && !isOnboarding && !isPublicLegal) return '/onboarding';
      if (preferences.onboardingComplete && isOnboarding) return '/coach';
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (context, state) => '/coach'),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/paywall', builder: (context, state) => const PaywallScreen()),
      GoRoute(path: '/privacy', builder: (context, state) => const PrivacyPolicyScreen()),
      GoRoute(path: '/terms', builder: (context, state) => const TermsScreen()),
      GoRoute(
        path: '/summary/:scanId',
        builder: (context, state) => CoachSummaryScreen(scanId: state.pathParameters['scanId']!),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(
          currentPath: state.uri.path,
          child: child,
        ),
        routes: [
          GoRoute(path: '/coach', builder: (context, state) => const CoachScreen()),
          GoRoute(path: '/scan', builder: (context, state) => const ScanScreen()),
          GoRoute(path: '/plan', builder: (context, state) => const PlanScreen()),
          GoRoute(path: '/progress', builder: (context, state) => const ProgressScreen()),
          GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
