import 'package:flutter_test/flutter_test.dart';
import 'package:blackjack/engine/blackjack_engine.dart';

/// Engine tests for Blackjack (RULES.md §13).
///
/// Timers are shrunk via the @visibleForTesting gaps and driven with
/// tester.pump(), which advances the fake clock.
BjCard c(int rank, int suit, [int uid = 0]) => BjCard(rank, suit, uid);

BlackjackEngine makeEngine(DealerStyle style, List<BjCard> shoe) {
  BlackjackEngine.useFastGaps();
  final e = BlackjackEngine(
    seats: [BjSeat(name: 'Ruby', bank: 1000)],
    dealerStyle: style,
  );
  e.riggedShoe = shoe;
  return e;
}

void main() {
  test('hand values: blackjack, soft 21, bust', () {
    expect(handValue([c(1, 0), c(13, 1)]).value, 21);
    expect(isBlackjack([c(1, 0), c(13, 1)]), isTrue);
    final soft = handValue([c(1, 0), c(9, 2), c(1, 3)]);
    expect(soft.value, 21);
    expect(soft.soft, isTrue);
    expect(isBlackjack([c(1, 0), c(9, 2), c(1, 3)]), isFalse); // 3 cards: no BJ
    expect(handValue([c(10, 0), c(6, 1), c(7, 2)]).value, 23);
  });

  testWidgets('player blackjack pays 3:2 (RULES §7)', (tester) async {
    final e = makeEngine(DealerStyle.friendly, [
      c(1, 0, 1), // seat: A
      c(9, 2, 2), // dealer up: 9
      c(13, 1, 3), // seat: K -> blackjack
      c(7, 3, 4), // dealer hole: 7 -> 16
    ]);
    e.addChip(0, 100);
    e.startRound();
    await tester.pump(const Duration(milliseconds: 500));
    // After naturals: player paid 100 + 150, dealer never plays.
    expect(e.phase, BjPhase.roundOver);
    expect(e.seats[0].bank, 1150);
    expect(e.seats[0].lastOutcome, contains('BLACKJACK'));
    e.dispose();
  });

  testWidgets('dealer stands on soft 17 when friendly, hits when classic',
      (tester) async {
    // Friendly: dealer A+6 stands on 17 -> player 20 wins.
    var e = makeEngine(DealerStyle.friendly, [
      c(10, 0, 1), c(1, 0, 2), // seat 10, dealer A
      c(10, 1, 3), c(6, 2, 4), // seat 10 (20), dealer 6 -> soft 17
    ]);
    e.addChip(0, 100);
    e.startRound();
    await tester.pump(const Duration(milliseconds: 500));
    expect(e.phase, BjPhase.playerTurn);
    e.stand();
    await tester.pump(const Duration(milliseconds: 2000));
    expect(e.phase, BjPhase.roundOver);
    expect(e.seats[0].bank, 1100); // 20 beats soft 17
    e.dispose();

    // Classic: dealer hits soft 17, draws a 4 -> 21, player loses.
    // Dealer shows an Ace on the classic table, so insurance is offered
    // first (RULES §3) — the test declines it like a real player would.
    e = makeEngine(DealerStyle.classic, [
      c(10, 0, 1), c(1, 0, 2),
      c(10, 1, 3), c(6, 2, 4),
      c(4, 3, 5), // dealer hit card
    ]);
    e.addChip(0, 100);
    e.startRound();
    await tester.pump(const Duration(milliseconds: 500));
    expect(e.phase, BjPhase.insurance);
    e.decideInsurance(false); // decline insurance
    await tester.pump(const Duration(milliseconds: 500));
    expect(e.phase, BjPhase.playerTurn);
    e.stand();
    await tester.pump(const Duration(milliseconds: 2000));
    expect(e.phase, BjPhase.roundOver);
    expect(e.seats[0].bank, 900);
    e.dispose();
  });

  testWidgets('bust loses the bet', (tester) async {
    final e = makeEngine(DealerStyle.friendly, [
      c(10, 0, 1), c(9, 2, 2),
      c(6, 1, 3), c(7, 3, 4),
      c(8, 0, 5), // hit card -> 24 bust
    ]);
    e.addChip(0, 100);
    e.startRound();
    await tester.pump(const Duration(milliseconds: 500));
    e.hit();
    await tester.pump(const Duration(milliseconds: 2000));
    expect(e.seats[0].busted, isTrue);
    expect(e.seats[0].bank, 900);
    expect(e.phase, BjPhase.roundOver);
    e.dispose();
  });

  testWidgets('push returns the bet', (tester) async {
    final e = makeEngine(DealerStyle.friendly, [
      c(10, 0, 1), c(10, 2, 2),
      c(8, 1, 3), c(8, 3, 4), // player 18, dealer 18
    ]);
    e.addChip(0, 100);
    e.startRound();
    await tester.pump(const Duration(milliseconds: 500));
    e.stand();
    await tester.pump(const Duration(milliseconds: 2000));
    expect(e.seats[0].bank, 1000);
    expect(e.seats[0].lastOutcome, contains('Push'));
    e.dispose();
  });

  testWidgets('insurance pays 2:1 when dealer has blackjack', (tester) async {
    final e = makeEngine(DealerStyle.classic, [
      c(10, 0, 1), c(1, 0, 2), // seat 10, dealer Ace
      c(7, 1, 3), c(10, 3, 4), // seat 7 (17), dealer hole 10 -> BJ
    ]);
    e.addChip(0, 100);
    e.startRound();
    await tester.pump(const Duration(milliseconds: 500));
    expect(e.phase, BjPhase.insurance);
    e.decideInsurance(true); // buy 50 insurance
    await tester.pump(const Duration(milliseconds: 2000));
    expect(e.phase, BjPhase.roundOver);
    // 1000 - 100 bet - 50 insurance + 50 + 100 insurance win = 1000.
    expect(e.seats[0].bank, 1000);
    e.dispose();
  });

  testWidgets('even money pays 1:1 on player blackjack vs dealer ace',
      (tester) async {
    final e = makeEngine(DealerStyle.classic, [
      c(1, 0, 1), c(1, 2, 2), // seat A, dealer Ace
      c(13, 1, 3), c(9, 3, 4), // seat K -> BJ, dealer hole 9
    ]);
    e.addChip(0, 100);
    e.startRound();
    await tester.pump(const Duration(milliseconds: 500));
    expect(e.phase, BjPhase.insurance);
    e.decideInsurance(true); // even money
    await tester.pump(const Duration(milliseconds: 2000));
    expect(e.seats[0].bank, 1100);
    expect(e.seats[0].tookEvenMoney, isTrue);
    e.dispose();
  });

  testWidgets('double down doubles bet and stands after one card',
      (tester) async {
    final e = makeEngine(DealerStyle.friendly, [
      c(5, 0, 1), c(9, 2, 2),
      c(6, 1, 3), c(7, 3, 4), // player 11, dealer 16
      c(10, 0, 5), // double card -> 21
      c(10, 1, 6), // dealer hit -> 26 bust
    ]);
    e.addChip(0, 100);
    e.startRound();
    await tester.pump(const Duration(milliseconds: 500));
    e.doubleDown();
    await tester.pump(const Duration(milliseconds: 3000));
    expect(e.phase, BjPhase.roundOver);
    // Bet doubled to 200; dealer busts -> +200. Bank: 1000-100-100+400=1200.
    expect(e.seats[0].bank, 1200);
    e.dispose();
  });

  testWidgets('surrender returns half on the friendly table', (tester) async {
    final e = makeEngine(DealerStyle.friendly, [
      c(10, 0, 1), c(9, 2, 2),
      c(6, 1, 3), c(7, 3, 4),
    ]);
    e.addChip(0, 100);
    e.startRound();
    await tester.pump(const Duration(milliseconds: 500));
    expect(e.canSurrender, isTrue);
    e.surrender();
    await tester.pump(const Duration(milliseconds: 2000));
    expect(e.seats[0].bank, 950);
    e.dispose();
  });

  testWidgets('broke seat is spotted 1000 by the house on next hand',
      (tester) async {
    final e = makeEngine(DealerStyle.friendly, [
      c(10, 0, 1), c(9, 2, 2),
      c(6, 1, 3), c(7, 3, 4),
      c(8, 0, 5), // bust card
    ]);
    e.seats[0].bank = 50;
    e.addChip(0, 50);
    e.startRound();
    await tester.pump(const Duration(milliseconds: 500));
    e.hit(); // busts, bank 0
    await tester.pump(const Duration(milliseconds: 2000));
    expect(e.seats[0].bank, 0);
    e.nextRound();
    expect(e.seats[0].bank, 1000);
    e.dispose();
  });

  testWidgets('pause during a bust-transition recovers on resume (RULES §12)',
      (tester) async {
    final e = makeEngine(DealerStyle.friendly, [
      c(10, 0, 1), c(9, 2, 2),
      c(6, 1, 3), c(7, 3, 4),
      c(8, 0, 5), // bust card
    ]);
    e.addChip(0, 100);
    e.startRound();
    await tester.pump(const Duration(milliseconds: 500));
    e.hit(); // busts; seat-advance timer pending
    e.setPaused(true); // cancels the timer mid-transition
    await tester.pump(const Duration(milliseconds: 5000));
    expect(e.phase, isNot(BjPhase.roundOver)); // frozen, as it should be
    e.setPaused(false); // watchdog must recover the dropped transition
    await tester.pump(const Duration(milliseconds: 500));
    expect(e.phase, BjPhase.roundOver);
    e.dispose();
  });
}
