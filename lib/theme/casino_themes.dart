import 'package:flutter/material.dart';

/// Casino theme catalog for Blackjack.
///
/// Every theme lives inside a real casino material world — felt tables,
/// polished wood rails, brass trim, ivory cards. Variety comes from different
/// felt cloths, wood stains, metal trims and card stocks. No neon anywhere.
class CasinoThemeDef {
  final String id;
  final String name;
  final Color felt;
  final Color feltDeep;
  final Color rail;
  final Color railDark;
  final Color brass;
  final Color brassLight;
  final Color brassDark;
  final Color ivory;
  final Color ink;
  final Color muted;

  const CasinoThemeDef({
    required this.id,
    required this.name,
    required this.felt,
    required this.feltDeep,
    required this.rail,
    required this.railDark,
    required this.brass,
    required this.brassLight,
    required this.brassDark,
    required this.ivory,
    required this.ink,
    required this.muted,
  });
}

class CasinoThemes {
  /// First 4 are FREE starter themes. The rest are PRO.
  static const List<String> freeThemeIds = [
    'classic',
    'montecarlo',
    'midnight',
    'emerald',
  ];

  static const List<CasinoThemeDef> all = [
    CasinoThemeDef(
      id: 'classic',
      name: 'Classic Green',
      felt: Color(0xFF1E5C43),
      feltDeep: Color(0xFF123B2B),
      rail: Color(0xFF5C3A21),
      railDark: Color(0xFF3B2416),
      brass: Color(0xFFC9A227),
      brassLight: Color(0xFFE8CE7A),
      brassDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFFBF7EC),
      ink: Color(0xFF2E2118),
      muted: Color(0xFFD8CFB8),
    ),
    CasinoThemeDef(
      id: 'montecarlo',
      name: 'Monte Carlo',
      felt: Color(0xFF6E1E2A),
      feltDeep: Color(0xFF471218),
      rail: Color(0xFF4A2C14),
      railDark: Color(0xFF2E1B0C),
      brass: Color(0xFFD4AF37),
      brassLight: Color(0xFFF3DC8E),
      brassDark: Color(0xFF96702A),
      ivory: Color(0xFFF8F1E2),
      ink: Color(0xFF2A1C12),
      muted: Color(0xFFE3D2BE),
    ),
    CasinoThemeDef(
      id: 'midnight',
      name: 'Midnight Blue',
      felt: Color(0xFF1F3A5F),
      feltDeep: Color(0xFF13263F),
      rail: Color(0xFF2A2A30),
      railDark: Color(0xFF1A1A1E),
      brass: Color(0xFFC0C6D4),
      brassLight: Color(0xFFE8ECF5),
      brassDark: Color(0xFF7E8698),
      ivory: Color(0xFFF2EEE4),
      ink: Color(0xFF1E2430),
      muted: Color(0xFFC6CDDA),
    ),
    CasinoThemeDef(
      id: 'emerald',
      name: 'Emerald Club',
      felt: Color(0xFF0F6B4A),
      feltDeep: Color(0xFF094632),
      rail: Color(0xFF3B2416),
      railDark: Color(0xFF241309),
      brass: Color(0xFFB87333),
      brassLight: Color(0xFFE09E5A),
      brassDark: Color(0xFF7E4F22),
      ivory: Color(0xFFF5EFE0),
      ink: Color(0xFF26301E),
      muted: Color(0xFFD5DCC4),
    ),
    CasinoThemeDef(
      id: 'desert',
      name: 'Desert Gold',
      felt: Color(0xFF8A6A2E),
      feltDeep: Color(0xFF5C4518),
      rail: Color(0xFF4A2C14),
      railDark: Color(0xFF2E1B0C),
      brass: Color(0xFF7A5A2E),
      brassLight: Color(0xFFC49A5A),
      brassDark: Color(0xFF54401E),
      ivory: Color(0xFF2E2118),
      ink: Color(0xFF3A2C14),
      muted: Color(0xFF5A4A28),
    ),
    CasinoThemeDef(
      id: 'noir',
      name: 'Charcoal Noir',
      felt: Color(0xFF383838),
      feltDeep: Color(0xFF1E1E1E),
      rail: Color(0xFF242424),
      railDark: Color(0xFF121212),
      brass: Color(0xFFB87333),
      brassLight: Color(0xFFE09E5A),
      brassDark: Color(0xFF7E4F22),
      ivory: Color(0xFFF0EBE0),
      ink: Color(0xFF26221C),
      muted: Color(0xFFCFC6B4),
    ),
    CasinoThemeDef(
      id: 'royal',
      name: 'Royal Purple',
      felt: Color(0xFF4A2E6E),
      feltDeep: Color(0xFF301C48),
      rail: Color(0xFF3B2416),
      railDark: Color(0xFF241309),
      brass: Color(0xFFD4AF37),
      brassLight: Color(0xFFF3DC8E),
      brassDark: Color(0xFF96702A),
      ivory: Color(0xFFF8F1E2),
      ink: Color(0xFF2A1E3A),
      muted: Color(0xFFD9CBE8),
    ),
    CasinoThemeDef(
      id: 'riverboat',
      name: 'Riverboat Teal',
      felt: Color(0xFF1E5A56),
      feltDeep: Color(0xFF123A38),
      rail: Color(0xFF5E421E),
      railDark: Color(0xFF3A2812),
      brass: Color(0xFFC9A227),
      brassLight: Color(0xFFE8CE7A),
      brassDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFF0EDE2),
      ink: Color(0xFF1E2A26),
      muted: Color(0xFFCBD8CE),
    ),
    CasinoThemeDef(
      id: 'atlantic',
      name: 'Atlantic Navy',
      felt: Color(0xFF16324F),
      feltDeep: Color(0xFF0D2036),
      rail: Color(0xFF3E3226),
      railDark: Color(0xFF26201A),
      brass: Color(0xFFC9A227),
      brassLight: Color(0xFFE8CE7A),
      brassDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFF1EAD8),
      ink: Color(0xFF1E2A34),
      muted: Color(0xFFC4D0DE),
    ),
    CasinoThemeDef(
      id: 'oasis',
      name: 'Olive Oasis',
      felt: Color(0xFF5E6238),
      feltDeep: Color(0xFF3A3D20),
      rail: Color(0xFF4A2C14),
      railDark: Color(0xFF2E1B0C),
      brass: Color(0xFFC9A227),
      brassLight: Color(0xFFE8CE7A),
      brassDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFF1EAD8),
      ink: Color(0xFF2E3018),
      muted: Color(0xFFD8D4B8),
    ),
    CasinoThemeDef(
      id: 'ivoryhall',
      name: 'Ivory Hall',
      felt: Color(0xFF3E6E52),
      feltDeep: Color(0xFF2A4A38),
      rail: Color(0xFFE2D0A6),
      railDark: Color(0xFFC9B586),
      brass: Color(0xFF9A7B1E),
      brassLight: Color(0xFFD4AF37),
      brassDark: Color(0xFF6E5514),
      ivory: Color(0xFF2E2118),
      ink: Color(0xFFF5EFE0),
      muted: Color(0xFF8A7E62),
    ),
    CasinoThemeDef(
      id: 'saloon',
      name: 'Copper Saloon',
      felt: Color(0xFF4A5A2A),
      feltDeep: Color(0xFF2E3A18),
      rail: Color(0xFF6E3A1C),
      railDark: Color(0xFF471F0E),
      brass: Color(0xFFB87333),
      brassLight: Color(0xFFE09E5A),
      brassDark: Color(0xFF7E4F22),
      ivory: Color(0xFFF7EFE0),
      ink: Color(0xFF30241A),
      muted: Color(0xFFDCC9AE),
    ),
    CasinoThemeDef(
      id: 'reno',
      name: 'Slate Reno',
      felt: Color(0xFF434C5E),
      feltDeep: Color(0xFF2A303C),
      rail: Color(0xFF2E3440),
      railDark: Color(0xFF1A1E26),
      brass: Color(0xFFC9A227),
      brassLight: Color(0xFFE8CE7A),
      brassDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFECEFF4),
      ink: Color(0xFF242A34),
      muted: Color(0xFFC4CBD8),
    ),
    CasinoThemeDef(
      id: 'winecellar',
      name: 'Wine Cellar',
      felt: Color(0xFF3E1E3E),
      feltDeep: Color(0xFF281228),
      rail: Color(0xFF2E1A2E),
      railDark: Color(0xFF180E18),
      brass: Color(0xFFC9A227),
      brassLight: Color(0xFFE8CE7A),
      brassDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFF5EFE0),
      ink: Color(0xFF2E1E2E),
      muted: Color(0xFFDCC8E0),
    ),
    CasinoThemeDef(
      id: 'champagne',
      name: 'Champagne Room',
      felt: Color(0xFFB8894A),
      feltDeep: Color(0xFF7E5C2C),
      rail: Color(0xFF3B2416),
      railDark: Color(0xFF241309),
      brass: Color(0xFF6E4A1E),
      brassLight: Color(0xFFB98A4A),
      brassDark: Color(0xFF4A3012),
      ivory: Color(0xFF2E2118),
      ink: Color(0xFFFBF7EC),
      muted: Color(0xFF6E5A34),
    ),
    CasinoThemeDef(
      id: 'crimson',
      name: 'Crimson Velvet',
      felt: Color(0xFF5A1A26),
      feltDeep: Color(0xFF3A0F18),
      rail: Color(0xFF4A1420),
      railDark: Color(0xFF2A0A12),
      brass: Color(0xFFD4AF37),
      brassLight: Color(0xFFF3DC8E),
      brassDark: Color(0xFF96702A),
      ivory: Color(0xFFF8F1E2),
      ink: Color(0xFF33121A),
      muted: Color(0xFFE0C2C8),
    ),
  ];

  static CasinoThemeDef byId(String id, {CasinoThemeDef? custom}) {
    if (id == 'custom') {
      return custom ?? all.first;
    }
    return all.firstWhere((t) => t.id == id, orElse: () => all.first);
  }

  static bool isProTheme(String id) =>
      !freeThemeIds.contains(id) && id != 'custom';
}

/// Card-back designs. 0-3 = FREE, 4+ = PRO.
class CardBackStyles {
  static const names = [
    'Casino Red',
    'Bicycle Blue',
    'Felt Green',
    'Ivory Classic',
    'Gold Leaf',
    'Midnight',
    'Burgundy Crest',
    'Silver Diamond',
  ];
  static const patterns = [
    'lattice',
    'medallion',
    'diamond',
    'swirl',
    'crest',
    'stripes',
    'dots',
    'chevron',
  ];
  static const baseColors = [
    0xFFA31621,
    0xFF1D4E9E,
    0xFF1B7A4D,
    0xFFF0E6D2,
    0xFFC9A227,
    0xFF1C2438,
    0xFF5A1A26,
    0xFF9AA2B2,
  ];
  static const lineColors = [
    0xFFE8CE7A,
    0xFFE8ECF5,
    0xFFE8CE7A,
    0xFF8A6D1A,
    0xFF5E421E,
    0xFFC0C6D4,
    0xFFD4AF37,
    0xFF3A4048,
  ];

  static const freeCount = 4;
  static bool isPro(int index) => index >= freeCount;
}

/// Poker-chip color schemes. 0-3 = FREE, 4+ = PRO.
class ChipStyles {
  static const names = [
    'House Classic',
    'Monte Carlo',
    'Riverboat',
    'Desert Night',
    'Royal Court',
    'Emerald Isle',
    'Copper Mine',
    'Midnight Oil',
  ];

  /// Per-denomination chip colors: [10, 25, 50, 100, 500].
  static const List<List<int>> colors = [
    [0xFFA31621, 0xFF1D4E9E, 0xFF1B7A4D, 0xFF222222, 0xFF6E3A9E],
    [0xFFD4AF37, 0xFF8E1F2F, 0xFF1E3A5F, 0xFF2E2E2E, 0xFFB87333],
    [0xFF2E8B8B, 0xFFC9A227, 0xFF7A3B2E, 0xFF3B5E2E, 0xFFDCD6C4],
    [0xFFB87333, 0xFF4A2E6E, 0xFF1E5C43, 0xFF8E1F2F, 0xFF222222],
    [0xFF6E3A9E, 0xFFC9A227, 0xFF1D4E9E, 0xFFA31621, 0xFF1B7A4D],
    [0xFF1B7A4D, 0xFFD4AF37, 0xFF2E86C1, 0xFF8E1F2F, 0xFF2A2A2A],
    [0xFFB87333, 0xFF7E4F22, 0xFFD4AF37, 0xFF5E3A1C, 0xFF3A2A18],
    [0xFF1C2438, 0xFFC0C6D4, 0xFF8E1F2F, 0xFFC9A227, 0xFF2E8B8B],
  ];

  /// Edge-spot colors per style: [10, 25, 50, 100, 500].
  static const List<List<int>> spots = [
    [0xFFFBF7EC, 0xFFFBF7EC, 0xFFFBF7EC, 0xFFC9A227, 0xFFC9A227],
    [0xFF2E1B0C, 0xFFF8F1E2, 0xFFD4AF37, 0xFFD4AF37, 0xFFF8F1E2],
    [0xFFF0EDE2, 0xFF123A38, 0xFFE8CE7A, 0xFFE8CE7A, 0xFF123A38],
    [0xFF2E1B0C, 0xFFE8CE7A, 0xFFE8CE7A, 0xFFE8CE7A, 0xFFB87333],
    [0xFFE8CE7A, 0xFF301C48, 0xFFE8CE7A, 0xFFE8CE7A, 0xFFE8CE7A],
    [0xFFF5EFE0, 0xFF094632, 0xFFF5EFE0, 0xFFF5EFE0, 0xFFD4AF37],
    [0xFF3A2A18, 0xFFD4AF37, 0xFF5E3A1C, 0xFFD4AF37, 0xFFD4AF37],
    [0xFFC0C6D4, 0xFF1C2438, 0xFFE8ECF5, 0xFF1C2438, 0xFFE8ECF5],
  ];

  static const freeCount = 4;
  static bool isPro(int index) => index >= freeCount;

  static int denomIndex(int denom) {
    switch (denom) {
      case 10:
        return 0;
      case 25:
        return 1;
      case 50:
        return 2;
      case 100:
        return 3;
      default:
        return 4;
    }
  }
}
