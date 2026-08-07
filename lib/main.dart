import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configuration comes from .env, through AppConfig, and nowhere else. A
  // missing or malformed value is a fatal startup error rather than something
  // to paper over with a default — unless the build was explicitly compiled
  // with --dart-define=USE_FALLBACK_CONFIG=true, in which case AppConfig fills
  // the gaps from FallbackConfig and says so in the log.
  //
  // Loading up front reports every problem at once, before any screen has a
  // chance to fail on whichever key it happens to touch first.
  try {
    await AppConfig.load();
  } on Object catch (error) {
    // A bare `throw` here would surface as a white screen in a release build,
    // which is the opposite of a clear error. Show the reason on the device.
    runApp(_ConfigurationErrorApp(message: '$error'));
    return;
  }

  runApp(const ProviderScope(child: MyApp()));
}

/// Shown in place of the app when `.env` cannot satisfy [AppConfig].
class _ConfigurationErrorApp extends StatelessWidget {
  const _ConfigurationErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1B1B1F),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFFF6B6B),
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Configuration error',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFD7D7DC),
                    fontSize: 13,
                    height: 1.5,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
