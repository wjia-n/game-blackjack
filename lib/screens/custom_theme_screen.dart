import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/casino_themes.dart';
import '../theme/casino_ui.dart';

/// PRO-only custom theme creator: pick the felt, trim, rail and card colors
/// from casino-appropriate swatches. Persisted with the profile.
class CustomThemeScreen extends StatefulWidget {
  final BlackjackAudio audio;
  final BlackjackSettings settings;
  const CustomThemeScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  static const slots = [
    ('felt', 'Table Felt'),
    ('feltDeep', 'Felt Shadow'),
    ('rail', 'Wood Rail'),
    ('railDark', 'Rail Shadow'),
    ('brass', 'Brass Trim'),
    ('brassLight', 'Trim Highlight'),
    ('brassDark', 'Trim Shadow'),
    ('ivory', 'Card Ivory'),
    ('ink', 'Card Ink'),
    ('muted', 'Muted Text'),
  ];

  static const List<int> swatches = [
    0xFF1E5C43, 0xFF0F6B4A, 0xFF6E1E2A, 0xFF5A1A26, 0xFF1F3A5F, 0xFF16324F,
    0xFF4A2E6E, 0xFF1E5A56, 0xFF5E6238, 0xFF8A6A2E, 0xFF383838, 0xFF434C5E,
    0xFFC9A227, 0xFFD4AF37, 0xFFB87333, 0xFFC0C6D4, 0xFF7A5A2E, 0xFF8E1F2F,
    0xFFFBF7EC, 0xFFF5EFE0, 0xFF2E2118, 0xFF1E2430, 0xFFD8CFB8, 0xFF8A7E62,
    0xFF5C3A21, 0xFF3B2416, 0xFF4A2C14, 0xFF2A2A30, 0xFF3E3226, 0xFF26201A,
  ];

  String _slot = 'felt';

  CasinoThemeDef get _preview => widget.settings.customTheme;

  @override
  Widget build(BuildContext context) {
    final audio = widget.audio;
    final s = widget.settings;
    return ListenableBuilder(
      listenable: s,
      builder: (_, _) {
        final t = _preview;
        return FeltBackdrop(
          theme: t,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: t.brassLight),
                onPressed: () {
                  audio.click();
                  Navigator.of(context).pop();
                },
              ),
              title:
                  Text('My Creation', style: CasinoText.display(20, t)),
              centerTitle: true,
              actions: [
                TextButton(
                  onPressed: () async {
                    audio.click();
                    await s.setTheme('custom');
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: Text('Use it', style: CasinoText.label(14, t)),
                ),
              ],
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Live preview of a mini table.
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.3),
                          radius: 1.4,
                          colors: [t.felt, t.feltDeep],
                        ),
                        border: Border.all(color: t.railDark, width: 8),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 46,
                              height: 64,
                              decoration: BoxDecoration(
                                color: t.ivory,
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(
                                    color: Colors.black26, width: 1),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black45,
                                      offset: Offset(0, 3),
                                      blurRadius: 6)
                                ],
                              ),
                              child: Center(
                                child: Text('A♠',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: t.ink)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(colors: [
                                  t.brassLight,
                                  t.brass,
                                  t.brassDark
                                ]),
                                border: Border.all(
                                    color: Colors.white70, width: 2),
                              ),
                              child: Center(
                                child: Text('25',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: t.ink)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('Blackjack',
                                style: CasinoText.display(22, t)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('PICK A PART',
                        style: CasinoText.label(12, _slotTheme(t))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final slot in slots)
                          ChoiceChip(
                            label: Text(slot.$2,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: _slot == slot.$1
                                        ? t.ink
                                        : t.brassLight)),
                            selected: _slot == slot.$1,
                            selectedColor: t.brassLight,
                            backgroundColor:
                                Colors.black.withValues(alpha: 0.4),
                            side: BorderSide(
                                color: t.brass.withValues(alpha: 0.5)),
                            onSelected: (_) {
                              audio.click();
                              setState(() => _slot = slot.$1);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('PICK A COLOR',
                        style: CasinoText.label(12, _slotTheme(t))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final sw in swatches)
                          GestureDetector(
                            onTap: () {
                              audio.click();
                              s.setCustomColor(_slot, sw);
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(sw),
                                border: Border.all(
                                  color: s.customColors[_slot] == sw
                                      ? Colors.white
                                      : Colors.black38,
                                  width:
                                      s.customColors[_slot] == sw ? 3 : 1.5,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black45,
                                      offset: Offset(0, 2),
                                      blurRadius: 4)
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: CasinoButton(
                        label: 'Reset Colors',
                        onTap: () async {
                          audio.click();
                          await s.resetCustomColors();
                        },
                        theme: t,
                        primary: false,
                        width: 220,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Stable readable theme for the labels (the preview theme may be mid-edit).
  CasinoThemeDef _slotTheme(CasinoThemeDef t) => t;
}
