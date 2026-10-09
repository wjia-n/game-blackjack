import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'services/audio_service.dart';
import 'services/settings_service.dart';
import 'theme/casino_themes.dart';
import 'theme/casino_ui.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final settings = BlackjackSettings();
  await settings.load();
  final audio = BlackjackAudio();
  audio.configure(
    musicOn: settings.musicOn,
    sfxOn: settings.sfxOn,
    volume: settings.volume,
  );
  runApp(BlackjackApp(settings: settings, audio: audio));
}

class BlackjackApp extends StatefulWidget {
  final BlackjackSettings settings;
  final BlackjackAudio audio;
  const BlackjackApp({super.key, required this.settings, required this.audio});

  @override
  State<BlackjackApp> createState() => _BlackjackAppState();
}

class _BlackjackAppState extends State<BlackjackApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.audio.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause (not stop) on interruption so music resumes exactly where it
    // left off; the game screen additionally freezes its engine.
    if (state == AppLifecycleState.paused) {
      widget.audio.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (_, _) {
        final theme = CasinoThemes.byId(widget.settings.themeId,
            custom: widget.settings.customTheme);
        return MaterialApp(
          title: 'Blackjack',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: theme.feltDeep,
            colorScheme: ColorScheme.dark(
              primary: theme.brassLight,
              secondary: theme.brass,
              surface: theme.railDark,
            ),
            textTheme: TextTheme(
              bodyMedium: CasinoText.body(15, theme),
            ),
          ),
          home: SplashScreen(
              audio: widget.audio, settings: widget.settings),
        );
      },
    );
  }
}
