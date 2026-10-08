import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const BlackjackApp());

class BlackjackApp extends StatelessWidget {
  const BlackjackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      variant: ShellVariant.softBlob,
      title: 'Blackjack',
      tagline: 'Beat the dealer to 21 — the house absolutely hates this one trick!',
      emoji: '🂡',
      slug: 'blackjack',
      howToPlay:
          '• Place your bet with the chips, then hit Deal! 🃏\n• HIT for another card, STAND to lock your total.\n• DOUBLE to double your bet for exactly one more card.\n• Dealer must hit until 17. Closest to 21 without busting wins.\n• Blackjack pays 3:2. Fun chips only — no real money, all glory! 💰',
      playerOptions: const [1],
      supportsBots: false,
      gameBuilder: (ctx, players, cb) => BlackjackScreen(players: players, callbacks: cb),
    );
  }
}
