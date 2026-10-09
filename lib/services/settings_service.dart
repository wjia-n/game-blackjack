import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/casino_themes.dart';

/// Persisted profile + settings for Blackjack. Survives app restarts.
///
/// EVERYTHING lives in ONE JSON string under [_kProfile]. Never use
/// setStringList for ordered data — Android backs StringLists with an
/// unordered StringSet and scrambles the order on every restart.
class BlackjackSettings extends ChangeNotifier {
  static const _kProfile = 'blackjack_profile_json';

  /// THE authoritative names store: one order-preserving JSON string via
  /// setString. NEVER setStringList — Android backs StringLists with an
  /// unordered StringSet and scrambles seat order on every restart.
  static const _kNames = 'blackjack_player_names_json';

  /// Legacy key from the pre-exemplar build: one shared bankroll int.
  static const _kLegacyBank = 'bj_bank';

  /// Legacy key from the very first build attempt: a StringList of seat
  /// names (unordered on Android). Read once for migration, then deleted.
  static const _kLegacyNameList = 'bj_seat_names';

  static const List<String> defaultSeatNames = ['Ruby', 'Sapphire', 'Amber'];
  static const int minBet = 10;

  /// Encode the whole profile as one JSON string (order-preserving).
  static String encodeProfile(Map<String, Object?> profile) =>
      jsonEncode(profile);

  /// Decode a persisted profile; returns {} on missing/corrupt data.
  static Map<String, Object?> decodeProfile(String? raw) {
    if (raw == null) return {};
    try {
      final d = jsonDecode(raw);
      if (d is Map<String, Object?>) return d;
      if (d is Map) return Map<String, Object?>.from(d);
    } catch (_) {}
    return {};
  }

  static String _cleanName(int i, Object? v) {
    final s = v is String ? v.trim() : '';
    return s.isEmpty ? defaultSeatNames[i % defaultSeatNames.length] : s;
  }

  // ------------------------------------------------------------- state
  String playerName = 'Player';
  List<String> seatNames = List.of(defaultSeatNames);
  List<int> seatBanks = [1000, 1000, 1000];
  int humanSeats = 1; // 1..3 pass-and-play (2+ is PRO)
  int dealerStyle = 1; // 0 friendly, 1 classic, 2 high roller (2 is PRO)
  String themeId = 'classic';
  int cardBack = 0;
  int chipStyle = 0;
  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  bool isPro = false;
  Map<String, int> customColors = Map.of(_defaultCustomColors);

  // Lifetime stats.
  int handsPlayed = 0;
  int handsWon = 0;
  int blackjacks = 0;
  int biggestWin = 0;

  static const Map<String, int> _defaultCustomColors = {
    'felt': 0xFF1E5C43,
    'feltDeep': 0xFF123B2B,
    'rail': 0xFF5C3A21,
    'railDark': 0xFF3B2416,
    'brass': 0xFFC9A227,
    'brassLight': 0xFFE8CE7A,
    'brassDark': 0xFF8A6D1A,
    'ivory': 0xFFFBF7EC,
    'ink': 0xFF2E2118,
    'muted': 0xFFD8CFB8,
  };

  CasinoThemeDef get customTheme {
    Color c(String k) => Color(customColors[k] ?? 0xFF000000);
    return CasinoThemeDef(
      id: 'custom',
      name: 'My Creation',
      felt: c('felt'),
      feltDeep: c('feltDeep'),
      rail: c('rail'),
      railDark: c('railDark'),
      brass: c('brass'),
      brassLight: c('brassLight'),
      brassDark: c('brassDark'),
      ivory: c('ivory'),
      ink: c('ink'),
      muted: c('muted'),
    );
  }

  SharedPreferences? _prefs;

  Map<String, Object?> _toJson() => {
        'playerName': playerName,
        'seatNames': seatNames,
        'seatBanks': seatBanks,
        'humanSeats': humanSeats,
        'dealerStyle': dealerStyle,
        'themeId': themeId,
        'cardBack': cardBack,
        'chipStyle': chipStyle,
        'musicOn': musicOn,
        'sfxOn': sfxOn,
        'volume': volume,
        'isPro': isPro,
        'custom': customColors,
        'stats': {
          'hands': handsPlayed,
          'wins': handsWon,
          'blackjacks': blackjacks,
          'biggestWin': biggestWin,
        },
      };

  void _fromJson(Map<String, Object?> m) {
    playerName = (m['playerName'] as String?)?.trim().isNotEmpty == true
        ? (m['playerName'] as String).trim()
        : 'Player';
    final names = m['seatNames'];
    seatNames = (names is List && names.length == 3)
        ? [for (int i = 0; i < 3; i++) _cleanName(i, names[i])]
        : List.of(defaultSeatNames);
    final banks = m['seatBanks'];
    seatBanks = (banks is List && banks.length == 3)
        ? [
            for (int i = 0; i < 3; i++)
              (banks[i] is int ? banks[i] as int : 1000).clamp(0, 9999999)
          ]
        : [1000, 1000, 1000];
    humanSeats = (m['humanSeats'] as int? ?? 1).clamp(1, 3);
    dealerStyle = (m['dealerStyle'] as int? ?? 1).clamp(0, 2);
    themeId = m['themeId'] as String? ?? 'classic';
    cardBack = (m['cardBack'] as int? ?? 0).clamp(0, 7);
    chipStyle = (m['chipStyle'] as int? ?? 0).clamp(0, 7);
    musicOn = m['musicOn'] as bool? ?? true;
    sfxOn = m['sfxOn'] as bool? ?? true;
    volume = ((m['volume'] as num?)?.toDouble() ?? 0.8).clamp(0.0, 1.0);
    isPro = m['isPro'] as bool? ?? false;
    final custom = m['custom'];
    if (custom is Map) {
      for (final k in _defaultCustomColors.keys) {
        final v = custom[k];
        customColors[k] =
            v is int ? v : _defaultCustomColors[k]!;
      }
    }
    final stats = m['stats'];
    if (stats is Map) {
      handsPlayed = (stats['hands'] as int?) ?? 0;
      handsWon = (stats['wins'] as int?) ?? 0;
      blackjacks = (stats['blackjacks'] as int?) ?? 0;
      biggestWin = (stats['biggestWin'] as int?) ?? 0;
    }
  }

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    final raw = p.getString(_kProfile);
    if (raw != null) {
      try {
        final d = jsonDecode(raw);
        if (d is Map<String, Object?>) {
          _fromJson(d);
        }
      } catch (_) {
        // Corrupt profile: fall through to defaults below.
      }
    } else {
      // One-time migration from the legacy pre-exemplar build.
      final legacyBank = p.getInt(_kLegacyBank);
      if (legacyBank != null) {
        seatBanks = [legacyBank.clamp(0, 9999999), 1000, 1000];
        await p.remove(_kLegacyBank);
        await _save();
      }
    }
    // Names live in their own order-preserving JSON key; migrate any
    // legacy storage into it exactly once.
    await _migrateNames(p);
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setString(_kProfile, encodeProfile(_toJson()));
  }

  /// Persist names under `blackjack_player_names_json` as ONE JSON string:
  /// {"seats": [a, b, c], "playerName": "..."} — order-preserving.
  Map<String, Object?> _namesJson() => {
        'seats': seatNames,
        'playerName': playerName,
      };

  Future<void> _saveNames() async {
    final p = _prefs;
    if (p == null) return;
    await p.setString(_kNames, jsonEncode(_namesJson()));
  }

  static Map<String, Object?> _decodeNames(String? raw) {
    final m = decodeProfile(raw);
    if (m.isEmpty) return {};
    final seats = m['seats'];
    final name = m['playerName'];
    if (seats is List &&
        seats.length == 3 &&
        name is String &&
        name.trim().isNotEmpty) {
      return {
        'seats': [
          for (int i = 0; i < 3; i++)
            seats[i] is String ? (seats[i] as String) : ''
        ],
        'playerName': name.trim(),
      };
    }
    return {};
  }

  /// One-time migration for names: dedicated key first, then the older
  /// profile-embedded seat names, then the ancient StringList key (whose
  /// order cannot be trusted), then defaults. Legacy keys are removed.
  Future<void> _migrateNames(SharedPreferences p) async {
    final decoded = _decodeNames(p.getString(_kNames));
    if (decoded.isNotEmpty) {
      seatNames = [
        for (int i = 0; i < 3; i++)
          _cleanName(i, (decoded['seats'] as List)[i])
      ];
      playerName = decoded['playerName'] as String;
      await _saveNames();
      return;
    }
    final profile = decodeProfile(p.getString(_kProfile));
    final profSeats = profile['seatNames'];
    if (profSeats is List && profSeats.length == 3) {
      seatNames = [
        for (int i = 0; i < 3; i++) _cleanName(i, profSeats[i])
      ];
      final pn = profile['playerName'];
      if (pn is String && pn.trim().isNotEmpty) playerName = pn.trim();
      await _saveNames();
      return;
    }
    final legacy = p.getStringList(_kLegacyNameList);
    if (legacy != null) {
      if (legacy.length == 3) {
        seatNames = [for (int i = 0; i < 3; i++) _cleanName(i, legacy[i])];
      }
      await p.remove(_kLegacyNameList);
      await _saveNames();
      return;
    }
    await _saveNames();
  }

  /// Free-tier limits: clamp pro-only choices back when not Pro.
  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (themeId == 'custom' || CasinoThemes.isProTheme(themeId)) {
      themeId = 'classic';
      changed = true;
    }
    if (CardBackStyles.isPro(cardBack)) {
      cardBack = 0;
      changed = true;
    }
    if (ChipStyles.isPro(chipStyle)) {
      chipStyle = 0;
      changed = true;
    }
    if (dealerStyle > 1) {
      dealerStyle = 1;
      changed = true;
    }
    if (humanSeats > 1) {
      humanSeats = 1;
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  /// Called on every keystroke AND on focus loss / keyboard-done: the
  /// dedicated `blackjack_player_names_json` key always holds the latest.
  Future<void> setPlayerName(String name) async {
    final clean = name.trim();
    playerName = clean.isEmpty ? 'Player' : clean;
    notifyListeners();
    await _saveNames();
    await _save();
  }

  /// Called on every keystroke AND on focus loss / keyboard-done.
  Future<void> setSeatName(int index, String name) async {
    if (index < 0 || index > 2) return;
    seatNames[index] = _cleanName(index, name);
    notifyListeners();
    await _saveNames();
    await _save();
  }

  Future<void> setSeatBank(int index, int bank) async {
    if (index < 0 || index > 2) return;
    seatBanks[index] = bank.clamp(0, 9999999);
    notifyListeners();
    await _save();
  }

  Future<void> setHumanSeats(int v) async {
    v = v.clamp(1, 3);
    if (!isPro && v > 1) return; // extra pass-and-play seats are PRO
    humanSeats = v;
    notifyListeners();
    await _save();
  }

  Future<void> setDealerStyle(int v) async {
    v = v.clamp(0, 2);
    if (!isPro && v > 1) return; // high roller dealer is PRO
    dealerStyle = v;
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    if (!isPro && (id == 'custom' || CasinoThemes.isProTheme(id))) return;
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setCardBack(int v) async {
    v = v.clamp(0, CardBackStyles.names.length - 1);
    if (!isPro && CardBackStyles.isPro(v)) return;
    cardBack = v;
    notifyListeners();
    await _save();
  }

  Future<void> setChipStyle(int v) async {
    v = v.clamp(0, ChipStyles.names.length - 1);
    if (!isPro && ChipStyles.isPro(v)) return;
    chipStyle = v;
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!isPro) return; // custom theme creator is a Pro feature
    if (!_defaultCustomColors.containsKey(key)) return;
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(_defaultCustomColors);
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  Future<void> recordHand({
    required bool won,
    required bool blackjack,
    required int winAmount,
  }) async {
    handsPlayed++;
    if (won) handsWon++;
    if (blackjack) blackjacks++;
    if (winAmount > biggestWin) biggestWin = winAmount;
    notifyListeners();
    await _save();
  }

  Future<void> resetStats() async {
    handsPlayed = 0;
    handsWon = 0;
    blackjacks = 0;
    biggestWin = 0;
    notifyListeners();
    await _save();
  }

  Future<void> resetBanks() async {
    seatBanks = [1000, 1000, 1000];
    notifyListeners();
    await _save();
  }
}
