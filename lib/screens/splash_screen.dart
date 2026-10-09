import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/casino_themes.dart';
import '../theme/casino_ui.dart';
import 'menu_screen.dart';

/// Launch splash (SINGLE screen, two moments):
/// 1. Company moment — the official WAJIHA logo, shown unchanged.
/// 2. Game splash — game logo + name, animated loading line, Credits: WAJIHA.
class SplashScreen extends StatefulWidget {
  final BlackjackAudio audio;
  final BlackjackSettings settings;
  const SplashScreen({super.key, required this.audio, required this.settings});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _loader;
  late final AnimationController _fade;
  bool _companyMoment = true;

  @override
  void initState() {
    super.initState();
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fade.forward();
    _run();
  }

  Future<void> _run() async {
    // Pre-warm audio while the splash shows, then start menu music.
    widget.audio.prewarm();
    widget.audio.startMenuMusic();
    // Company moment: hold the WAJIHA logo, then crossfade to the game.
    await Future.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    await _fade.reverse();
    if (!mounted) return;
    setState(() => _companyMoment = false);
    _fade.forward();
    _loader.forward();
    await Future.delayed(const Duration(milliseconds: 1900));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MenuScreen(
          audio: widget.audio,
          settings: widget.settings,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loader.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CasinoThemes.byId(
      widget.settings.themeId,
      custom: widget.settings.customTheme,
    );
    return Scaffold(
      backgroundColor: const Color(0xFF0E241B),
      body: FadeTransition(
        opacity: _fade,
        child: FeltBackdrop(
          theme: theme,
          child: Center(
            child: _companyMoment
                ? _companyMomentWidget(theme)
                : _gameMomentWidget(theme),
          ),
        ),
      ),
    );
  }

  /// Moment 1: the official WAJIHA company logo, copied unchanged.
  Widget _companyMomentWidget(CasinoThemeDef theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/wajiha_logo.png',
          width: 150,
          height: 150,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 18),
        Text('WAJIHA', style: CasinoText.display(30, theme)),
        const SizedBox(height: 6),
        Text(
          'INDIE GAMES',
          style: CasinoText.label(13, theme),
        ),
      ],
    );
  }

  /// Moment 2: game logo + name + animated loading line + credits.
  Widget _gameMomentWidget(CasinoThemeDef theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 190,
          height: 190,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: theme.brass, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                offset: const Offset(0, 10),
                blurRadius: 24,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset('assets/blackjack_logo.png', fit: BoxFit.cover),
        ),
        const SizedBox(height: 22),
        Text('Blackjack', style: CasinoText.display(52, theme)),
        const SizedBox(height: 6),
        Text(
          'BEAT THE DEALER TO 21',
          style: CasinoText.label(13, theme),
        ),
        const SizedBox(height: 30),
        // Animated loading line.
        SizedBox(
          width: 220,
          child: AnimatedBuilder(
            animation: _loader,
            builder: (_, _) => Column(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: Colors.black.withValues(alpha: 0.45),
                    border: Border.all(
                        color: theme.brass.withValues(alpha: 0.5)),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _loader.value.clamp(0.02, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: LinearGradient(
                          colors: [
                            theme.brassLight,
                            theme.brass,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _loader.value < 1 ? 'Shuffling the shoe…' : 'Ready!',
                  style: CasinoText.body(13, theme,
                      color: theme.ivory.withValues(alpha: 0.75)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 44),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/wajiha_logo.png',
              width: 30,
              height: 30,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            Text(
              'Credits: WAJIHA',
              style: CasinoText.label(14, theme),
            ),
          ],
        ),
      ],
    );
  }
}
