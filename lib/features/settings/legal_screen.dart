import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/ascend_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) => const _LegalScreen(
    title: 'Privacy policy',
    sections: [
      ('Local processing', 'Face photographs, image-quality checks, landmarks, and geometric capture observations are processed on the device. ASCEND does not send photographs, landmarks, facial measurements, or embeddings to cloud services.'),
      ('Storage and deletion', 'If you explicitly consent to save an accepted scan, the photo is encrypted with AES-256-GCM and kept in app-private storage. Structured profile, plan, scan, and progress payloads are encrypted in the local SQLite database. Delete individual scans or all app data from Settings. Android app uninstall also removes app-private files.'),
      ('Camera and permissions', 'Camera access is requested only when you open the scan flow. ASCEND does not use the camera in the background. Notifications are optional and requested from reminder settings. No contacts, location, microphone, or broad shared-storage permission is requested.'),
      ('Subscriptions', 'If Google Play billing is configured, RevenueCat and Google Play receive store transaction and entitlement information used to process and restore subscriptions; RevenueCat may also use an anonymous app-user identifier. No ASCEND account is required. Face photographs, landmarks, measurements, grooming preferences, and routine history are not sent to either service. Google Play purchase records remain with the store and can be restored after local data erasure.'),
      ('Network and analytics', 'The core coach, plan, image checks, and face analysis are designed to work offline. The Android build source replaces MediaPipe Tasks usage-metrics logging with a no-op logger, but the final APK has not yet passed network-capture verification; public release is blocked until the metrics sender is proven absent. ASCEND has no advertising SDK or general analytics integration. Subscription status may contact RevenueCat/Google Play when a purchase feature is used.'),
      ('Retention and control', 'Saved scans remain on this device until you delete them or uninstall the application. Reminders store only local schedule preferences. You can disable or cancel reminders at any time.'),
      ('Limitations', 'This policy screen is an implementation draft. The publisher must add its legal name, contact address, effective date, and jurisdiction-specific disclosures before public release.'),
    ],
  );
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) => const _LegalScreen(
    title: 'Terms of use',
    sections: [
      ('Scope', 'ASCEND provides general grooming, style, and habit-planning information. It is not medical, dermatological, psychological, or professional barbering advice.'),
      ('No diagnosis or ranking', 'ASCEND does not diagnose a health condition, identify a person, infer protected traits, or score attractiveness. Landmark observations describe capture geometry only and do not establish biological improvement.'),
      ('Subscriptions', 'Subscriptions, renewal timing, introductory offers, and cancellation are controlled by Google Play and the terms displayed by the store at purchase. Cancel through Google Play subscription settings. The app does not promise a trial unless an eligible store offer is displayed in the Google Play purchase flow.'),
      ('Responsible use', 'Use the app only for yourself or with clear permission from the person whose photograph is captured. Do not use it for surveillance, identification, or decisions about another person.'),
      ('Publisher review', 'These terms are a product draft and require review and completion with the publisher identity, governing law, and effective date before release.'),
    ],
  );
}

class _LegalScreen extends StatelessWidget {
  const _LegalScreen({required this.title, required this.sections});
  final String title;
  final List<(String, String)> sections;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), leading: IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Back',
      onPressed: () => context.pop(),
    )),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        children: [
          Text('ASCEND', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AscendColors.gold, letterSpacing: 2)),
          const SizedBox(height: 24),
          for (final (heading, body) in sections) ...[
            Text(heading, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(body, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),
          ],
        ],
      ),
    ),
  );
}
