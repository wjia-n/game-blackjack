import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/casino_themes.dart';
import '../theme/casino_ui.dart';

/// Settings: audio, volume, renameable seat names, stats, resets.
class SettingsScreen extends StatefulWidget {
  final BlackjackAudio audio;
  final BlackjackSettings settings;
  const SettingsScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrls =
      [TextEditingController(), TextEditingController(), TextEditingController()];

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 3; i++) {
      _nameCtrls[i].text = widget.settings.seatNames[i];
    }
  }

  @override
  void dispose() {
    for (final c in _nameCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  CasinoThemeDef get _t => CasinoThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  void _applyAudio() {
    final s = widget.settings;
    widget.audio.configure(
        musicOn: s.musicOn, sfxOn: s.sfxOn, volume: s.volume);
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
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
              widget.audio.click();
              Navigator.of(context).pop();
            },
          ),
          title: Text('Settings', style: CasinoText.display(22, t)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _section(t, 'SOUND'),
                  _switchRow(
                    t,
                    'Music',
                    Icons.music_note,
                    s.musicOn,
                    (v) async {
                      await s.setMusic(v);
                      _applyAudio();
                      if (v) widget.audio.startMenuMusic();
                    },
                  ),
                  _switchRow(
                    t,
                    'Sound effects',
                    Icons.volume_up,
                    s.sfxOn,
                    (v) async {
                      await s.setSfx(v);
                      _applyAudio();
                    },
                  ),
                  _sliderRow(t, s),
                  const SizedBox(height: 14),
                  _section(t, 'PLAYERS AT THE TABLE'),
                  Text(
                    'Rename every seat — names are saved and shown on the table.',
                    style: CasinoText.body(12, t,
                        color: t.muted, style: FontStyle.italic),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < 3; i++) _nameRow(t, s, i),
                  const SizedBox(height: 14),
                  _section(t, 'LIFETIME STATS'),
                  _statRow(t, 'Hands played', '${s.handsPlayed}'),
                  _statRow(t, 'Hands won', '${s.handsWon}'),
                  _statRow(t, 'Blackjacks', '${s.blackjacks}'),
                  _statRow(t, 'Biggest win', '${s.biggestWin} chips'),
                  const SizedBox(height: 14),
                  _section(t, 'RESET'),
                  Center(
                    child: Column(
                      children: [
                        CasinoButton(
                          label: 'Reset Bankrolls',
                          onTap: () async {
                            widget.audio.click();
                            await s.resetBanks();
                          },
                          theme: t,
                          primary: false,
                          width: 240,
                          fontSize: 15,
                        ),
                        const SizedBox(height: 8),
                        CasinoButton(
                          label: 'Reset Stats',
                          onTap: () async {
                            widget.audio.click();
                            await s.resetStats();
                          },
                          theme: t,
                          primary: false,
                          width: 240,
                          fontSize: 15,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(CasinoThemeDef t, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title, style: CasinoText.label(13, t)),
      );

  Widget _switchRow(CasinoThemeDef t, String label, IconData icon, bool value,
      Future<void> Function(bool) onChanged) {
    return _row(
      t,
      child: Row(
        children: [
          Icon(icon, color: t.brassLight, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: CasinoText.body(16, t))),
          Switch(
            value: value,
            activeThumbColor: t.brassLight,
            onChanged: (v) {
              widget.audio.click();
              onChanged(v);
            },
          ),
        ],
      ),
    );
  }

  Widget _sliderRow(CasinoThemeDef t, BlackjackSettings s) {
    return _row(
      t,
      child: Row(
        children: [
          Icon(Icons.tune, color: t.brassLight, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text('Volume', style: CasinoText.body(16, t))),
          Expanded(
            flex: 2,
            child: Slider(
              value: s.volume,
              activeColor: t.brassLight,
              inactiveColor: t.brass.withValues(alpha: 0.3),
              onChanged: (v) {
                s.setVolume(v);
                widget.audio.configure(
                    musicOn: s.musicOn,
                    sfxOn: s.sfxOn,
                    volume: v);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _nameRow(CasinoThemeDef t, BlackjackSettings s, int i) {
    return _row(
      t,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.brass.withValues(alpha: 0.35),
              border: Border.all(color: t.brass, width: 1.5),
            ),
            child: Center(
                child: Text('${i + 1}',
                    style: CasinoText.label(14, t))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _nameCtrls[i],
              style: CasinoText.body(16, t),
              decoration: InputDecoration(
                hintText: 'Seat ${i + 1} name',
                hintStyle: CasinoText.body(14, t,
                    color: t.muted, style: FontStyle.italic),
                border: InputBorder.none,
              ),
              onSubmitted: (v) {
                widget.audio.click();
                s.setSeatName(i, v);
              },
              // Persist on every keystroke and on focus loss — never lose
              // a rename, even if the app is killed mid-edit.
              onChanged: (v) => s.setSeatName(i, v),
            ),
          ),
          Text('💰 ${s.seatBanks[i]}',
              style: CasinoText.body(13, t, color: t.brassLight)),
          IconButton(
            icon: Icon(Icons.check, color: t.brassLight),
            onPressed: () {
              widget.audio.click();
              s.setSeatName(i, _nameCtrls[i].text);
              FocusScope.of(context).unfocus();
            },
          ),
        ],
      ),
    );
  }

  Widget _statRow(CasinoThemeDef t, String label, String value) {
    return _row(
      t,
      child: Row(
        children: [
          Expanded(child: Text(label, style: CasinoText.body(15, t))),
          Text(value,
              style: CasinoText.label(15, t)),
        ],
      ),
    );
  }

  Widget _row(CasinoThemeDef t, {required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.black.withValues(alpha: 0.32),
        border: Border.all(color: t.brass.withValues(alpha: 0.45), width: 1.2),
      ),
      child: child,
    );
  }
}
