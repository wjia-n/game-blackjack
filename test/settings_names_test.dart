import 'package:flutter_test/flutter_test.dart';
import 'package:blackjack/services/settings_service.dart';

/// Profile persistence tests: the whole profile (incl. renameable seat
/// names in exact slot order) is stored as ONE JSON string. Android's
/// SharedPreferences backs StringLists with an unordered StringSet, so we
/// never use setStringList — these tests pin the order-preserving contract.
void main() {
  test('profile round-trip preserves seat name order and banks', () {
    final profile = {
      'playerName': 'Wajiha',
      'seatNames': ['Zara', 'Ali', 'Bot Bob'],
      'seatBanks': [1500, 800, 2300],
      'humanSeats': 3,
      'dealerStyle': 2,
      'themeId': 'montecarlo',
      'cardBack': 5,
      'chipStyle': 6,
      'musicOn': false,
      'sfxOn': true,
      'volume': 0.5,
      'isPro': true,
      'custom': {'felt': 1},
      'stats': {'hands': 10, 'wins': 6, 'blackjacks': 2, 'biggestWin': 400},
    };
    final raw = BlackjackSettings.encodeProfile(profile);
    final back = BlackjackSettings.decodeProfile(raw);
    expect(back['seatNames'], ['Zara', 'Ali', 'Bot Bob']);
    expect((back['seatNames'] as List)[0], 'Zara');
    expect((back['seatNames'] as List)[2], 'Bot Bob');
    expect(back['seatBanks'], [1500, 800, 2300]);
    expect(back['playerName'], 'Wajiha');
    expect(back['themeId'], 'montecarlo');
  });

  test('decodeProfile falls back to empty map on missing/corrupt data', () {
    expect(BlackjackSettings.decodeProfile(null), isEmpty);
    expect(BlackjackSettings.decodeProfile('definitely not json'), isEmpty);
    expect(BlackjackSettings.decodeProfile('["a","b"]'), isEmpty);
    expect(BlackjackSettings.decodeProfile('{"a":1}')['a'], 1);
  });

  test('encoded profile is a single JSON string (never a string list)', () {
    final raw = BlackjackSettings.encodeProfile({
      'seatNames': ['A', 'B', 'C'],
    });
    expect(raw, isA<String>());
    expect(raw.startsWith('{'), isTrue);
  });
}
