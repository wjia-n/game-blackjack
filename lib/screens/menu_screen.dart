import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/blackjack_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/casino_themes.dart';
import '../theme/casino_ui.dart';
import 'custom_theme_screen.dart';
import 'game_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';

const _storeUrl =
    'https://play.google.com/store/apps/details?id=com.gameswajiha.blackjack';

/// Main menu: dealer-style table picker, pass-and-play seats, name editing,
/// and the full menu grid.
class MenuScreen extends StatefulWidget {
  final BlackjackAudio audio;
  final BlackjackSettings settings;
  const MenuScreen({super.key, required this.audio, required this.settings});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.settings.playerName;
    widget.audio.startMenuMusic();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  CasinoThemeDef get _t => CasinoThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  void _play() {
    widget.audio.gameStart();
    widget.audio.startGameMusic();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          audio: widget.audio,
          settings: widget.settings,
        ),
      ),
    );
  }

  Future<void> _share() async {
    widget.audio.click();
    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              'I\'m playing Blackjack by WAJIHA — beat the dealer to 21! $_storeUrl',
          subject: 'Blackjack',
        ),
      );
    } catch (_) {}
  }

  Future<void> _rate() async {
    widget.audio.click();
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
      } else {
        await review.openStoreListing(appStoreId: 'com.gameswajiha.blackjack');
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    return FeltBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: t.brass, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.55),
                          offset: const Offset(0, 8),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset('assets/blackjack_logo.png',
                        fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 12),
                  Text('Blackjack', style: CasinoText.display(40, t)),
                  Text('BEAT THE DEALER TO 21',
                      style: CasinoText.label(12, t)),
                  const SizedBox(height: 18),
                  // Player name.
                  _panel(
                    t,
                    child: Row(
                      children: [
                        Icon(Icons.person, color: t.brassLight),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _nameCtrl,
                            style: CasinoText.body(16, t),
                            decoration: InputDecoration(
                              hintText: 'Your name',
                              hintStyle: CasinoText.body(15, t,
                                  color: t.muted,
                                  style: FontStyle.italic),
                              border: InputBorder.none,
                            ),
                            onSubmitted: (v) {
                              widget.audio.click();
                              s.setPlayerName(v);
                            },
                            // Save on every keystroke so the name can never
                            // be lost if the app is killed mid-edit.
                            onChanged: (v) => s.setPlayerName(v),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.check, color: t.brassLight),
                          onPressed: () {
                            widget.audio.click();
                            s.setPlayerName(_nameCtrl.text);
                            FocusScope.of(context).unfocus();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('CHOOSE YOUR TABLE',
                        style: CasinoText.label(13, t)),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < 3; i++)
                    _dealerCard(t, s, DealerStyle.values[i]),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('PLAYERS AT THE TABLE',
                        style: CasinoText.label(13, t)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 1; i <= 3; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: _seatChip(t, s, i),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.humanSeats == 1
                        ? 'Just you vs the dealer'
                        : 'Pass-and-play: ${s.humanSeats} players, one phone',
                    style: CasinoText.body(12, t,
                        color: t.muted, style: FontStyle.italic),
                  ),
                  const SizedBox(height: 18),
                  CasinoButton(
                    label: 'Take a Seat 🃏',
                    onTap: _play,
                    theme: t,
                    width: 260,
                    fontSize: 18,
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      _menuBtn(t, Icons.palette, 'Themes',
                          () => _open(const _ThemePickerSheet())),
                      _menuBtn(t, Icons.style, 'Cards & Chips',
                          () => _open(const _CardChipSheet())),
                      _menuBtn(t, Icons.settings, 'Settings', _openSettings),
                      _menuBtn(
                          t,
                          s.isPro ? Icons.verified : Icons.workspace_premium,
                          s.isPro ? 'PRO ✓' : 'Go PRO', _openPro),
                      _menuBtn(t, Icons.menu_book, 'How to Play', _howToPlay),
                      _menuBtn(t, Icons.share, 'Share', _share),
                      _menuBtn(t, Icons.star, 'Rate', _rate),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text('Chips are virtual — no real money, all glory.',
                      style: CasinoText.body(11, t,
                          color: t.muted, style: FontStyle.italic),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel(CasinoThemeDef t, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.black.withValues(alpha: 0.35),
        border: Border.all(color: t.brass.withValues(alpha: 0.6), width: 1.5),
      ),
      child: child,
    );
  }

  Widget _dealerCard(CasinoThemeDef t, BlackjackSettings s, DealerStyle d) {
    final selected = s.dealerStyle == d.index;
    final locked = d.index == 2 && !s.isPro;
    return GestureDetector(
      onTap: () {
        widget.audio.click();
        if (locked) {
          _openPro();
          return;
        }
        s.setDealerStyle(d.index);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: selected
                ? [
                    t.brass.withValues(alpha: 0.5),
                    t.brassDark.withValues(alpha: 0.55)
                  ]
                : [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.45),
                  ],
          ),
          border: Border.all(
            color: selected ? t.brassLight : t.brass.withValues(alpha: 0.4),
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Text(
              ['😌', '🎩', '🔥'][d.index],
              style: const TextStyle(fontSize: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(d.name,
                            style: CasinoText.label(15, t)),
                      ),
                      if (locked) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.lock,
                            size: 15,
                            color: t.brassLight.withValues(alpha: 0.8)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(d.blurb,
                      style: CasinoText.body(12, t,
                          color: t.ivory.withValues(alpha: 0.85))),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: t.brassLight, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _seatChip(CasinoThemeDef t, BlackjackSettings s, int count) {
    final selected = s.humanSeats == count;
    final locked = count > 1 && !s.isPro;
    return GestureDetector(
      onTap: () {
        widget.audio.click();
        if (locked) {
          _openPro();
          return;
        }
        s.setHumanSeats(count);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: selected
                    ? [t.brassLight, t.brass, t.brassDark]
                    : [
                        t.rail.withValues(alpha: 0.8),
                        t.railDark.withValues(alpha: 0.9)
                      ],
              ),
              border: Border.all(
                  color: selected
                      ? t.brassLight
                      : t.brass.withValues(alpha: 0.5),
                  width: 2),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    offset: const Offset(0, 3),
                    blurRadius: 6),
              ],
            ),
            child: Center(
              child: Text('$count',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: selected ? t.ink : t.brassLight)),
            ),
          ),
          if (locked)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.railDark,
                  border: Border.all(color: t.brass, width: 1.5),
                ),
                child: Icon(Icons.lock, size: 12, color: t.brassLight),
              ),
            ),
        ],
      ),
    );
  }

  Widget _menuBtn(CasinoThemeDef t, IconData icon, String label,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.black.withValues(alpha: 0.35),
          border:
              Border.all(color: t.brass.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: t.brassLight, size: 24),
            const SizedBox(height: 6),
            Text(label,
                style: CasinoText.label(11, t), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  void _open(Widget sheet) {
    widget.audio.click();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => sheet,
    );
  }

  void _openSettings() {
    widget.audio.click();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          audio: widget.audio,
          settings: widget.settings,
        ),
      ),
    );
  }

  void _openPro() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProScreen(
          audio: widget.audio,
          settings: widget.settings,
        ),
      ),
    );
  }

  void _howToPlay() {
    widget.audio.click();
    final t = _t;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.railDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: t.brass, width: 2),
        ),
        title: Text('How to Play', style: CasinoText.display(22, t)),
        content: SingleChildScrollView(
          child: Text(
            '• Place your bet with the chips, then tap Deal.\n\n'
            '• HIT for another card, STAND to lock your total.\n\n'
            '• DOUBLE to double your bet for exactly one more card.\n\n'
            '• SURRENDER (Friendly table) gives back half your bet.\n\n'
            '• When the dealer shows an Ace you may buy INSURANCE (pays 2:1 if the dealer has Blackjack).\n\n'
            '• Blackjack pays 3:2. Dealer plays after everyone.\n\n'
            '• Chips are virtual — no real money, all glory! 💰',
            style: CasinoText.body(14, t),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Got it', style: CasinoText.label(15, t)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Theme picker sheet (12+ themes + custom creator entry).
// ---------------------------------------------------------------------------
class _ThemePickerSheet extends StatelessWidget {
  const _ThemePickerSheet();

  @override
  Widget build(BuildContext context) {
    // Rebuild with current settings via a stateful wrapper.
    return _SheetShell(
      title: 'Table Themes',
      builder: (ctx, audio, s, t) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final th in CasinoThemes.all)
              _swatch(ctx, audio, s, t, th.id, th.name,
                  [th.felt, th.brass, th.rail]),
            _customSwatch(ctx, audio, s, t),
          ],
        );
      },
    );
  }

  Widget _swatch(BuildContext ctx, BlackjackAudio audio, BlackjackSettings s,
      CasinoThemeDef t, String id, String name, List<Color> colors) {
    final selected = s.themeId == id;
    final locked = CasinoThemes.isProTheme(id) && !s.isPro;
    return GestureDetector(
      onTap: () {
        audio.click();
        if (locked) {
          Navigator.of(ctx).pop();
          Navigator.of(ctx).push(MaterialPageRoute(
              builder: (_) =>
                  ProScreen(audio: audio, settings: s)));
          return;
        }
        s.setTheme(id);
      },
      child: Container(
        width: 104,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.black.withValues(alpha: 0.35),
          border: Border.all(
            color: selected ? t.brassLight : t.brass.withValues(alpha: 0.4),
            width: selected ? 2.5 : 1.2,
          ),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                        colors: [colors[0], colors[2]]),
                  ),
                  child: Center(
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors[1],
                        border: Border.all(color: Colors.white70, width: 2),
                      ),
                    ),
                  ),
                ),
                if (locked)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Icon(Icons.lock,
                        size: 14, color: t.brassLight),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(name,
                style: CasinoText.label(10, t),
                textAlign: TextAlign.center,
                maxLines: 2),
          ],
        ),
      ),
    );
  }

  Widget _customSwatch(BuildContext ctx, BlackjackAudio audio,
      BlackjackSettings s, CasinoThemeDef t) {
    final selected = s.themeId == 'custom';
    final locked = !s.isPro;
    return GestureDetector(
      onTap: () {
        audio.click();
        if (locked) {
          Navigator.of(ctx).pop();
          Navigator.of(ctx).push(MaterialPageRoute(
              builder: (_) =>
                  ProScreen(audio: audio, settings: s)));
          return;
        }
        Navigator.of(ctx).pop();
        Navigator.of(ctx).push(MaterialPageRoute(
            builder: (_) => CustomThemeScreen(
                audio: audio, settings: s)));
      },
      child: Container(
        width: 104,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.black.withValues(alpha: 0.35),
          border: Border.all(
            color: selected ? t.brassLight : t.brass.withValues(alpha: 0.4),
            width: selected ? 2.5 : 1.2,
          ),
        ),
        child: Column(
          children: [
            Container(
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(colors: [
                  Color(0xFFA31621),
                  Color(0xFF1D4E9E),
                  Color(0xFF1B7A4D),
                  Color(0xFFC9A227),
                ]),
              ),
              child: Center(
                child: locked
                    ? Icon(Icons.lock, color: t.brassLight, size: 18)
                    : Icon(Icons.brush,
                        color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(height: 6),
            Text('My Creation',
                style: CasinoText.label(10, t),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cards & chips sheet.
// ---------------------------------------------------------------------------
class _CardChipSheet extends StatelessWidget {
  const _CardChipSheet();

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: 'Cards & Chips',
      builder: (ctx, audio, s, t) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CARD BACKS', style: CasinoText.label(12, t)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < CardBackStyles.names.length; i++)
                  _styleChip(
                    ctx,
                    audio,
                    s,
                    t,
                    CardBackStyles.names[i],
                    selected: s.cardBack == i,
                    locked: CardBackStyles.isPro(i) && !s.isPro,
                    onTap: () => s.setCardBack(i),
                    preview: Container(
                      width: 40,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: Colors.white24, width: 1),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: CustomPaint(
                        painter: _PreviewBackPainter(style: i),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('CHIP STYLES', style: CasinoText.label(12, t)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < ChipStyles.names.length; i++)
                  _styleChip(
                    ctx,
                    audio,
                    s,
                    t,
                    ChipStyles.names[i],
                    selected: s.chipStyle == i,
                    locked: ChipStyles.isPro(i) && !s.isPro,
                    onTap: () => s.setChipStyle(i),
                    preview: PokerChip(
                        denom: 100, chipStyle: i, size: 44),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _styleChip(
    BuildContext ctx,
    BlackjackAudio audio,
    BlackjackSettings s,
    CasinoThemeDef t,
    String name, {
    required bool selected,
    required bool locked,
    required VoidCallback onTap,
    required Widget preview,
  }) {
    return GestureDetector(
      onTap: () {
        audio.click();
        if (locked) {
          Navigator.of(ctx).pop();
          Navigator.of(ctx).push(
              MaterialPageRoute(builder: (_) => ProScreen(audio: audio, settings: s)));
          return;
        }
        onTap();
      },
      child: Container(
        width: 104,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.black.withValues(alpha: 0.35),
          border: Border.all(
            color: selected ? t.brassLight : t.brass.withValues(alpha: 0.4),
            width: selected ? 2.5 : 1.2,
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: 56, child: Center(child: preview)),
            if (locked)
              Icon(Icons.lock, size: 13, color: t.brassLight),
            const SizedBox(height: 4),
            Text(name,
                style: CasinoText.label(10, t),
                textAlign: TextAlign.center,
                maxLines: 2),
          ],
        ),
      ),
    );
  }
}

class _PreviewBackPainter extends CustomPainter {
  final int style;
  const _PreviewBackPainter({required this.style});

  @override
  void paint(Canvas canvas, Size size) {
    final base = Color(CardBackStyles.baseColors[style]);
    final line = Color(CardBackStyles.lineColors[style]);
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = base);
    final p = Paint()
      ..color = line.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (double x = -size.height; x < size.width + size.height; x += 8) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), p);
    }
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 8, p);
  }

  @override
  bool shouldRepaint(covariant _PreviewBackPainter old) =>
      old.style != style;
}

/// Bottom sheet shell that re-resolves audio/settings/theme from context.
class _SheetShell extends StatefulWidget {
  final String title;
  final Widget Function(BuildContext, BlackjackAudio, BlackjackSettings,
      CasinoThemeDef) builder;
  const _SheetShell({required this.title, required this.builder});

  @override
  State<_SheetShell> createState() => _SheetShellState();
}

class _SheetShellState extends State<_SheetShell> {
  @override
  Widget build(BuildContext context) {
    // The menu passes these down through inherited lookup is overkill;
    // instead we climb to the MenuScreen state via a static accessor.
    final menu = context.findAncestorStateOfType<_MenuScreenState>()!;
    final audio = menu.widget.audio;
    final s = menu.widget.settings;
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, ctrl) => ListenableBuilder(
        listenable: s,
        builder: (_, _) {
          final t = CasinoThemes.byId(s.themeId,
              custom: s.customTheme);
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [t.railDark, t.feltDeep],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
              border: Border(
                  top: BorderSide(color: t.brass, width: 2)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: t.brass.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 12),
                Text(widget.title, style: CasinoText.display(22, t)),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    controller: ctrl,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 8),
                    child: widget.builder(context, audio, s, t),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}
