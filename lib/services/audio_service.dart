import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Procedural casino audio for Blackjack — all sounds synthesized in code as
/// WAV bytes. Card slides, chip clacks, felt thuds. No asset files.
///
/// Reliability design (copied from the ludo exemplar):
/// - Clips synthesized ONCE and cached; music start never blocks the UI after
///   the first build.
/// - A [_musicGen] generation counter serializes track changes: the LATEST
///   request always wins; overlapping calls can never swallow a start or
///   leave the player half-started. Music is app-scoped and never dies.
/// - Lifecycle uses pause()/resume() so interruptions resume where they
///   left off.
/// - Every public method catches player errors; audio can never crash the app.
class BlackjackAudio {
  static const int _rate = 22050;
  final AudioPlayer _sfx = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  final _rand = Random();

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;

  final Map<String, Uint8List> _cache = {};

  int _musicGen = 0;
  bool _musicBusy = false;
  String? _currentTrack; // 'menu' | 'game' | null
  bool _pausedByLifecycle = false;
  bool _disposed = false;

  BlackjackAudio() {
    _music.setReleaseMode(ReleaseMode.loop);
  }

  void configure(
      {required bool musicOn, required bool sfxOn, required double volume}) {
    this.musicOn = musicOn;
    this.sfxOn = sfxOn;
    volume = volume.clamp(0.0, 1.0);
    this.volume = volume;
    _music.setVolume(musicOn ? volume * 0.5 : 0.0);
    _sfx.setVolume(sfxOn ? volume : 0.0);
    if (!musicOn) {
      stopMusic();
    }
  }

  /// Pre-build music clips off the critical path. Safe to call any time.
  Future<void> prewarm() async {
    if (_disposed) return;
    await Future(() {});
    _menuBytes();
    _gameBytes();
  }

  // ---------------------------------------------------------- WAV synthesis
  Uint8List _wav(List<double> samples) {
    final n = samples.length;
    final data = ByteData(44 + n * 2);
    void writeStr(int o, String s) {
      for (int i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    writeStr(0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, _rate, Endian.little);
    data.setUint32(28, _rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    writeStr(36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (int i = 0; i < n; i++) {
      final v = samples[i].clamp(-1.0, 1.0);
      data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  double _env(int i, int n, {double attack = 0.02}) {
    final t = i / n;
    final a = (t / attack).clamp(0.0, 1.0);
    final d = pow(1 - t, 2.2).toDouble();
    return a * d;
  }

  List<double> _tone(double freq, double secs,
      {double freqEnd = 0, double attack = 0.02, double harmonics = 0.25}) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final f = freqEnd > 0 ? freq + (freqEnd - freq) * (i / n) : freq;
      final ph = 2 * pi * f * t;
      out[i] = _env(i, n, attack: attack) *
          (sin(ph) + harmonics * sin(2 * ph) + harmonics * 0.5 * sin(3 * ph));
    }
    return out;
  }

  /// Card sliding across felt: filtered noise with a downward whoosh.
  List<double> _cardSlide() {
    final n = (_rate * 0.22).round();
    final out = List<double>.filled(n, 0);
    var prev = 0.0;
    for (int i = 0; i < n; i++) {
      final t = i / n;
      final noise = _rand.nextDouble() * 2 - 1;
      prev = prev * 0.72 + noise * 0.28; // low-pass = felt friction
      final swell = sin(pi * t.clamp(0.0, 1.0));
      out[i] = prev * 0.75 * (0.3 + 0.7 * swell);
    }
    return out;
  }

  /// Card flip: soft paper snap.
  List<double> _cardFlip() {
    final n = (_rate * 0.12).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.004) *
          (0.55 * sin(2 * pi * 420 * t) * exp(-t * 45) +
              0.3 * (_rand.nextDouble() * 2 - 1) * exp(-t * 90));
    }
    return out;
  }

  /// Poker chip clack: two short ceramic clicks.
  List<double> _chipClack() {
    final n = (_rate * 0.18).round();
    final out = List<double>.filled(n, 0);
    for (final startF in [0.0, 0.35]) {
      final start = (n * startF).round();
      final len = (_rate * 0.07).round();
      for (int i = 0; i < len && start + i < n; i++) {
        final t = i / _rate;
        out[start + i] += _env(i, len, attack: 0.002) *
            (0.7 * sin(2 * pi * 2100 * t) * exp(-t * 80) +
                0.4 * sin(2 * pi * 3400 * t) * exp(-t * 110));
      }
    }
    return out;
  }

  /// Chips won: a small cascade of clacks.
  List<double> _chipsWon() {
    final n = (_rate * 0.5).round();
    final out = List<double>.filled(n, 0);
    for (int k = 0; k < 6; k++) {
      final start = (n * k / 8).round();
      final len = (_rate * 0.06).round();
      for (int i = 0; i < len && start + i < n; i++) {
        final t = i / _rate;
        out[start + i] += _env(i, len, attack: 0.002) *
            0.5 *
            sin(2 * pi * (1900 + k * 220) * t) *
            exp(-t * 70);
      }
    }
    return out;
  }

  /// Bust: low felt thud.
  List<double> _thud() {
    final n = (_rate * 0.25).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.004) *
          (0.9 * sin(2 * pi * 110 * t) * exp(-t * 22) +
              0.35 * sin(2 * pi * 220 * t) * exp(-t * 40));
    }
    return out;
  }

  /// Shuffle riffle: a flutter of short noise bursts.
  List<double> _shuffle() {
    final n = (_rate * 0.7).round();
    final out = List<double>.filled(n, 0);
    for (int burst = 0; burst < 9; burst++) {
      final start = (n * burst / 10).round();
      final len = (_rate * 0.035).round();
      for (int i = 0; i < len && start + i < n; i++) {
        final t = i / _rate;
        out[start + i] += (_rand.nextDouble() * 2 - 1) *
            exp(-t * 120) *
            (0.45 + 0.4 * sin(2 * pi * 1100 * t));
      }
    }
    return out;
  }

  /// Insurance bell: a soft casino ding.
  List<double> _ding() {
    final n = (_rate * 0.5).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.005) *
          (0.6 * sin(2 * pi * 880 * t) * exp(-t * 6) +
              0.25 * sin(2 * pi * 1320 * t) * exp(-t * 9));
    }
    return out;
  }

  List<double> _arp(List<double> freqs, double noteSecs, double gapSecs) {
    final out = <double>[];
    for (final f in freqs) {
      out.addAll(_tone(f, noteSecs, harmonics: 0.2));
      final gap = List<double>.filled((_rate * gapSecs).round(), 0);
      out.addAll(gap);
    }
    return out;
  }

  List<double> _swingBass(List<double> roots, double beatSecs) {
    final out = <double>[];
    for (final r in roots) {
      out.addAll(_tone(r, beatSecs * 0.55, harmonics: 0.35));
      out.addAll(_tone(r * 1.5, beatSecs * 0.45, harmonics: 0.3));
    }
    return out;
  }

  List<double> _padChord(List<double> freqs, double secs) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      double v = 0;
      for (final f in freqs) {
        final t = i / _rate;
        v += sin(2 * pi * f * t) + 0.3 * sin(2 * pi * f * 2 * t);
      }
      v /= freqs.length * 1.3;
      final t = i / n;
      final swell = sin(pi * t.clamp(0.0, 1.0));
      out[i] = v * (0.35 + 0.65 * swell);
    }
    return out;
  }

  Uint8List _clip(String key, List<double> Function() build) =>
      _cache.putIfAbsent(key, () => _wav(build()));

  Uint8List _menuBytes() => _clip('music_menu', () {
        // Lounge swing: walking bass under soft brass-ish chords, 16s loop.
        final roots = [110.0, 130.81, 98.0, 87.31]; // A C G F walk
        final bass = _swingBass(roots, 1.0); // 8 beats = 8s? extend below
        final chords = [
          [220.0, 277.18, 329.63], // A
          [261.63, 329.63, 392.0], // C
          [196.0, 246.94, 293.66], // G
          [174.61, 220.0, 261.63], // F
        ];
        final n = (_rate * 16).round();
        final out = List<double>.filled(n, 0);
        final bassRep = [...bass, ...bass];
        for (int i = 0; i < bassRep.length && i < n; i++) {
          out[i] += bassRep[i] * 0.4;
        }
        for (int c = 0; c < chords.length; c++) {
          final start = (n * c / 4).round();
          final pad = _padChord(chords[c], 4.0);
          for (int i = 0; i < pad.length && start + i < n; i++) {
            out[start + i] += pad[i] * 0.35;
          }
        }
        return out;
      });

  Uint8List _gameBytes() => _clip('music_game', () {
        // Soft late-night lounge: low piano-ish arps over a felt drone, 12s.
        final drone = _padChord([82.41, 123.47], 12.0);
        final notes = [
          220.0,
          261.63,
          293.66,
          329.63,
          293.66,
          261.63,
          246.94,
          220.0
        ];
        final n = (_rate * 12).round();
        final out = List<double>.from(drone);
        for (int k = 0; k < notes.length; k++) {
          final start = (n * k / notes.length).round();
          final tone = _tone(notes[k], 0.6, harmonics: 0.3);
          for (int i = 0; i < tone.length && start + i < n; i++) {
            out[start + i] += tone[i] * 0.28;
          }
        }
        return out;
      });

  // ------------------------------------------------------------------ SFX
  Future<void> _play(Uint8List bytes) async {
    if (!sfxOn || _disposed) return;
    try {
      await _sfx.play(BytesSource(bytes));
    } catch (_) {}
  }

  Future<void> click() =>
      _play(_clip('click', () => _tone(1150, 0.06)));
  Future<void> chip() => _play(_clip('chip', _chipClack));
  Future<void> chipsWon() => _play(_clip('chipswon', _chipsWon));
  Future<void> cardSlide() => _play(_clip('cardslide', _cardSlide));
  Future<void> cardFlip() => _play(_clip('cardflip', _cardFlip));
  Future<void> shuffle() => _play(_clip('shuffle', _shuffle));
  Future<void> bust() => _play(_clip('bust', _thud));
  Future<void> ding() => _play(_clip('ding', _ding));
  Future<void> invalid() =>
      _play(_clip('invalid', () => _tone(150, 0.16, harmonics: 0.5)));
  Future<void> gameStart() =>
      _play(_clip('start', () => _tone(420, 0.32, freqEnd: 840)));
  Future<void> win() => _play(_clip('win',
      () => _arp([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.16, 0.03)));
  Future<void> lose() => _play(_clip(
      'lose', () => _arp([392.0, 329.63, 261.63, 196.0], 0.22, 0.04)));
  Future<void> push() =>
      _play(_clip('push', () => _tone(520, 0.2, freqEnd: 520)));

  // ----------------------------------------------------------------- music
  Future<void> _startTrack(String track, Uint8List Function() bytes) async {
    if (_disposed) return;
    final gen = ++_musicGen;
    if (_currentTrack == track && !_pausedByLifecycle) {
      try {
        await _music.resume();
      } catch (_) {}
      return;
    }
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (gen != _musicGen || _disposed || !musicOn) return;
    _musicBusy = true;
    try {
      await _music.stop();
      if (gen != _musicGen || _disposed || !musicOn) return;
      _currentTrack = track;
      _pausedByLifecycle = false;
      await _music.play(BytesSource(bytes()));
    } catch (_) {
      if (gen == _musicGen) _currentTrack = null;
    } finally {
      _musicBusy = false;
    }
  }

  Future<void> startMenuMusic() => _startTrack('menu', _menuBytes);
  Future<void> startGameMusic() => _startTrack('game', _gameBytes);

  /// App-scoped stop: cancels any pending start, then stops. Used only when
  /// the user turns music OFF — never on screen navigation.
  Future<void> stopMusic() async {
    ++_musicGen;
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (_disposed) return;
    try {
      await _music.stop();
    } catch (_) {}
    _currentTrack = null;
    _pausedByLifecycle = false;
  }

  Future<void> onAppPaused() async {
    if (_disposed || _currentTrack == null) return;
    try {
      await _music.pause();
      _pausedByLifecycle = true;
    } catch (_) {}
  }

  Future<void> onAppResumed() async {
    if (_disposed || !musicOn || !_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    try {
      await _music.resume();
    } catch (_) {
      final track = _currentTrack;
      _currentTrack = null;
      if (track == 'menu') {
        await startMenuMusic();
      } else if (track == 'game') {
        await startGameMusic();
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _sfx.dispose();
      await _music.dispose();
    } catch (_) {}
  }
}
