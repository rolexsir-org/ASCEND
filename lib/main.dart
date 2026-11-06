import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_services.dart';
import 'app/ascend_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final services = await AppServices.initialize();
    runApp(ProviderScope(
      overrides: [appServicesProvider.overrideWithValue(services)],
      child: const AscendApp(),
    ));
  } on Object {
    runApp(const StartupFailureApp(
      message: 'ASCEND could not safely initialize its local services. Existing data was not intentionally erased. Check device storage and restart the app; if the issue persists, contact the app publisher.'
    ));
  }
}
