import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// Cards
// ---------------------------------------------------------------------------
class BjCard {
  final int rank; // 1=A .. 13=K
  final int suit; // 0=♠ 1=♥ 2=♦ 3=♣
  final int uid; // unique per shoe, stable identity for animations

  const BjCard(this.rank, this.suit, this.uid);

  String get rankLabel => rank == 1
      ? 'A'
      : rank == 11
          ? 'J'
          : rank == 12
              ? 'Q'
              : rank == 13
                  ? 'K'
                  : '$rank';
  String get suitLabel => '♠♥♦♣'[suit];
  bool get red => suit == 1 || suit == 2;
  bool get isAce => rank == 1;
}

/// Blackjack hand value. [soft] is true when an ace counts as 11.
({int value, bool soft}) handValue(List<BjCard> hand) {
  var total = 0;
  var aces = 0;
  for (final c in hand) {
    if (c.rank == 1) {
      aces++;
      total += 11;
    } else if (c.rank >= 10) {
      total += 10;
    } else {
      total += c.rank;
    }
  }
  while (total > 21 && aces > 0) {
    total -= 10;
    aces--;
  }
  return (value: total, soft: aces > 0 && total <= 21);
}

bool isBlackjack(List<BjCard> hand) =>
    hand.length == 2 && handValue(hand).value == 21;

// ---------------------------------------------------------------------------
// Dealer styles (RULES.md §11)
// ---------------------------------------------------------------------------
/// 0 = friendly, 1 = classic, 2 = high roller.
enum DealerStyle { friendly, classic, highRoller }

extension DealerStyleInfo on DealerStyle {
  String get name => ['Friendly Flo', 'Classic Vegas', 'High Roller'][index];
  String get blurb => [
        'Stands on all 17s · lets you surrender · no insurance tricks. The easy table.',
        'Hits soft 17 · offers insurance. The real Vegas rules.',
        'Hits soft 17 · insurance offered · deep 6-deck shoe. Not for the faint of heart.',
      ][index];
  bool get hitsSoft17 => this != DealerStyle.friendly;
  bool get offersInsurance => this != DealerStyle.friendly;
  bool get allowsSurrender => this == DealerStyle.friendly;
  int get decks => [1, 4, 6][index];
}

// ---------------------------------------------------------------------------
// Phases — owned entirely by the engine. The UI only renders.
// ---------------------------------------------------------------------------
enum BjPhase {
  betting, // humans place bets
  dealing, // animated deal, engine-driven
  insurance, // insurance / even-money decisions, human-gated
  playerTurn, // human decisions per seat
  dealerPlay, // animated dealer play, engine-driven
  settling, // payouts, engine-driven
  roundOver, // summary, human taps next
}

class BjSeat {
  String name;
  int bank;
  int bet = 0;
  final List<BjCard> hand = [];
  bool stood = false;
  bool doubled = false;
  bool surrendered = false;
  bool busted = false;
  bool natural = false; // player blackjack, already paid or pushed
  bool tookEvenMoney = false;
  int insuranceBet = 0;
  int lastDelta = 0;
  String lastOutcome = '';

  BjSeat({required this.name, required this.bank});

  bool get done =>
      busted || stood || surrendered || natural || tookEvenMoney;
  bool get active => !done;
}

enum BjEvent {
  shuffle,
  bet,
  deal,
  flip,
  hit,
  stand,
  double,
  surrender,
  bust,
  insurance,
  evenMoney,
  dealerReveal,
  dealerHit,
  natural,
  win,
  lose,
  push,
  roundStart,
  invalid,
}

// ---------------------------------------------------------------------------
// Engine
// ---------------------------------------------------------------------------
class BlackjackEngine extends ChangeNotifier {
  final List<BjSeat> seats;
  final DealerStyle dealerStyle;

  BjPhase phase = BjPhase.betting;
  final List<BjCard> dealerHand = [];
  bool dealerHoleHidden = true;
  int currentSeat = 0; // whose turn / insurance decision
  String banner = '';
  int shoePenetration = 0; // cards dealt from current shoe

  final List<BjCard> _shoe = [];
  final _rand = Random();
  Timer? _timer; // single phase-transition timer
  Timer? _watchdog; // stuck-state recovery
  bool _disposed = false;
  bool paused = false;

  /// UI hook for sounds / haptics. Set by the screen.
  void Function(BjEvent event)? onEvent;

  /// Test hook: when non-empty, the next shoe is built from these cards
  /// (in dealing order). Consumed on use.
  @visibleForTesting
  List<BjCard> riggedShoe = [];

  /// Test hooks: timer gaps. Tests shrink these so flows run fast.
  @visibleForTesting
  static int dealGapMs = 340;
  @visibleForTesting
  static int dealerGapMs = 800;
  @visibleForTesting
  static int startGapMs = 300;
  @visibleForTesting
  static int afterDealGapMs = 450;
  @visibleForTesting
  static int beginTurnsGapMs = 700;
  @visibleForTesting
  static int advanceGapMs = 900;
  @visibleForTesting
  static int standGapMs = 600;
  @visibleForTesting
  static int surrenderGapMs = 800;
  @visibleForTesting
  static int finishGapMs = 1400;
  @visibleForTesting
  static int settleGapMs = 800;

  /// Shrink every engine-driven gap for fast deterministic tests.
  @visibleForTesting
  static void useFastGaps() {
    dealGapMs = 1;
    dealerGapMs = 1;
    startGapMs = 1;
    afterDealGapMs = 1;
    beginTurnsGapMs = 1;
    advanceGapMs = 1;
    standGapMs = 1;
    surrenderGapMs = 1;
    finishGapMs = 1;
    settleGapMs = 1;
  }

  BlackjackEngine({required this.seats, required this.dealerStyle}) {
    banner = 'Place your bets!';
    _watchdog = Timer.periodic(const Duration(seconds: 3), (_) => _recover());
  }

  int get minBet => 10;

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }

  void _arm(Duration d, void Function() fn) {
    if (_disposed || paused) return;
    _timer?.cancel();
    _timer = Timer(d, () {
      _timer = null;
      if (!_disposed && !paused) fn();
    });
  }

  /// Pause: freeze the phase timer. Resume re-arms the current phase.
  void setPaused(bool v) {
    if (paused == v || _disposed) return;
    paused = v;
    if (v) {
      _timer?.cancel();
      _timer = null;
    } else {
      _recover();
    }
    notifyListeners();
  }

  /// Watchdog: if the single phase timer ever dies without progress, recover.
  /// Human-gated phases (betting, insurance, playerTurn, roundOver) are never
  /// touched — only engine-driven ones.
  void _recover() {
    if (_disposed || paused || _timer != null) return;
    if (phase == BjPhase.dealing && _dealQueue.isNotEmpty) {
      _dealNext();
    } else if (phase == BjPhase.dealerPlay && _dealerPending) {
      _dealerStep();
    } else if (phase == BjPhase.settling) {
      _finishRound();
    } else if (phase == BjPhase.playerTurn &&
        currentSeat >= 0 &&
        currentSeat < seats.length &&
        seats[currentSeat].done) {
      // A pause cancelled the seat-advance timer after a bust/double/stand/
      // surrender: the turn can never advance on its own, so advance it now.
      // Human-gated decisions (an active seat) are never touched.
      _advanceSeat();
    }
  }

  // ------------------------------------------------------------------ shoe
  void _buildShoe() {
    _shoe.clear();
    shoePenetration = 0;
    if (riggedShoe.isNotEmpty) {
      _shoe.addAll(riggedShoe.reversed);
      riggedShoe = [];
    } else {
      var uid = 0;
      for (var d = 0; d < dealerStyle.decks; d++) {
        for (var s = 0; s < 4; s++) {
          for (var r = 1; r <= 13; r++) {
            _shoe.add(BjCard(r, s, uid++));
          }
        }
      }
      _shoe.shuffle(_rand);
    }
    onEvent?.call(BjEvent.shuffle);
  }

  BjCard _draw() {
    if (_shoe.isEmpty) _buildShoe();
    shoePenetration++;
    return _shoe.removeLast();
  }

  bool get _shoeLow =>
      _shoe.length < dealerStyle.decks * 52 * 0.25;

  // ---------------------------------------------------------------- betting
  bool canBet(int seat, int amount) =>
      phase == BjPhase.betting &&
      amount > 0 &&
      seats[seat].bet + amount <= seats[seat].bank;

  void addChip(int seat, int amount) {
    if (!canBet(seat, amount)) {
      onEvent?.call(BjEvent.invalid);
      return;
    }
    seats[seat].bet += amount;
    onEvent?.call(BjEvent.bet);
    notifyListeners();
  }

  void clearBet(int seat) {
    if (phase != BjPhase.betting) return;
    seats[seat].bet = 0;
    onEvent?.call(BjEvent.bet);
    notifyListeners();
  }

  bool get canStartRound =>
      phase == BjPhase.betting &&
      seats.every((s) => s.bet >= minBet && s.bet <= s.bank);

  // ----------------------------------------------------------------- deal
  final List<(bool isDealer, int seat)> _dealQueue = [];

  void startRound() {
    if (!canStartRound) {
      onEvent?.call(BjEvent.invalid);
      return;
    }
    if (_shoeLow || _shoe.isEmpty) _buildShoe();
    for (final s in seats) {
      s.bank -= s.bet;
      s.hand.clear();
      s.stood = false;
      s.doubled = false;
      s.surrendered = false;
      s.busted = false;
      s.natural = false;
      s.tookEvenMoney = false;
      s.insuranceBet = 0;
      s.lastDelta = 0;
      s.lastOutcome = '';
    }
    dealerHand.clear();
    dealerHoleHidden = true;
    phase = BjPhase.dealing;
    banner = 'Dealing…';
    _dealQueue.clear();
    for (var round = 0; round < 2; round++) {
      for (var i = 0; i < seats.length; i++) {
        _dealQueue.add((false, i));
      }
      _dealQueue.add((true, -1));
    }
    onEvent?.call(BjEvent.roundStart);
    notifyListeners();
    _arm(Duration(milliseconds: startGapMs), _dealNext);
  }

  void _dealNext() {
    if (phase != BjPhase.dealing || _dealQueue.isEmpty) return;
    final (isDealer, seat) = _dealQueue.removeAt(0);
    final card = _draw();
    if (isDealer) {
      dealerHand.add(card);
      banner = 'Dealer deals…';
    } else {
      seats[seat].hand.add(card);
      banner = '${seats[seat].name} gets a card…';
    }
    onEvent?.call(BjEvent.deal);
    notifyListeners();
    if (_dealQueue.isEmpty) {
      _arm(Duration(milliseconds: afterDealGapMs), _afterDeal);
    } else {
      _arm(Duration(milliseconds: dealGapMs), _dealNext);
    }
  }

  void _afterDeal() {
    if (phase != BjPhase.dealing) return;
    final dealerShowsAce = dealerHand.isNotEmpty && dealerHand.first.isAce;
    if (dealerShowsAce && dealerStyle.offersInsurance) {
      _startInsurance();
      return;
    }
    _checkNaturalsAfterPeek(dealerBlackjack: false);
  }

  // -------------------------------------------------------------- insurance
  final List<int> _insuranceQueue = [];

  void _startInsurance() {
    phase = BjPhase.insurance;
    _insuranceQueue
      ..clear()
      ..addAll([for (var i = 0; i < seats.length; i++) i]);
    banner = 'Dealer shows an Ace — insurance?';
    onEvent?.call(BjEvent.insurance);
    _nextInsuranceSeat();
    notifyListeners();
  }

  void _nextInsuranceSeat() {
    if (phase != BjPhase.insurance) return;
    if (_insuranceQueue.isEmpty) {
      _resolveDealerPeek();
      return;
    }
    currentSeat = _insuranceQueue.first;
    final s = seats[currentSeat];
    banner = isBlackjack(s.hand)
        ? '${s.name} has Blackjack! Take even money?'
        : '${s.name}: insurance for ${s.bet ~/ 2}?';
    notifyListeners();
  }

  /// Insurance choice for the current seat. [take] = buy insurance (or take
  /// even money when holding blackjack).
  void decideInsurance(bool take) {
    if (phase != BjPhase.insurance || _insuranceQueue.isEmpty) {
      onEvent?.call(BjEvent.invalid);
      return;
    }
    final i = _insuranceQueue.removeAt(0);
    final s = seats[i];
    if (isBlackjack(s.hand)) {
      if (take) {
        s.tookEvenMoney = true;
        s.natural = true;
        final win = s.bet; // 1:1 even money
        s.bank += s.bet + win;
        s.lastDelta = win;
        s.lastOutcome = 'Even money +$win';
        onEvent?.call(BjEvent.evenMoney);
      }
    } else if (take) {
      // Clamp to what the seat can actually cover; clamp(1, 0) would throw
      // when the whole bank is on the main bet, so floor at 0.
      s.insuranceBet = (s.bet ~/ 2).clamp(0, s.bank);
      if (s.insuranceBet > 0) {
        s.bank -= s.insuranceBet;
        onEvent?.call(BjEvent.insurance);
      }
    }
    notifyListeners();
    _nextInsuranceSeat();
  }

  void _resolveDealerPeek() {
    dealerHoleHidden = false;
    onEvent?.call(BjEvent.flip);
    final dv = handValue(dealerHand).value;
    if (dv == 21) {
      // Dealer blackjack: insurance pays 2:1, naturals push, rest lose.
      banner = 'Dealer has Blackjack!';
      onEvent?.call(BjEvent.dealerReveal);
      for (final s in seats) {
        if (s.tookEvenMoney) continue; // already paid
        if (s.insuranceBet > 0) {
          final win = s.insuranceBet * 2;
          s.bank += s.insuranceBet + win;
          s.lastDelta += win;
          s.lastOutcome = 'Insurance pays +$win';
          onEvent?.call(BjEvent.insurance);
        }
        if (s.natural) continue;
        if (isBlackjack(s.hand)) {
          s.natural = true;
          s.bank += s.bet; // push: stake back
          s.lastDelta = 0;
          s.lastOutcome = 'Push — bet back';
          onEvent?.call(BjEvent.push);
        } else {
          s.busted = true;
          // Net of the insurance win (already banked above) minus the lost
          // main bet — RULES.md §7: insurance pays 2:1, main bet lost.
          s.lastDelta = (s.insuranceBet > 0 ? s.insuranceBet * 2 : 0) - s.bet;
          s.lastOutcome = s.insuranceBet > 0
              ? 'Dealer BJ — insurance won, main bet lost (${s.lastDelta >= 0 ? '+' : ''}${s.lastDelta})'
              : 'Dealer BJ −${s.bet}';
          onEvent?.call(BjEvent.lose);
        }
      }
      notifyListeners();
      phase = BjPhase.settling;
      _arm(Duration(milliseconds: finishGapMs), _finishRound);
      return;
    }
    // No dealer blackjack: insurance bets are collected.
    for (final s in seats) {
      if (s.insuranceBet > 0) {
        s.lastDelta -= s.insuranceBet;
        s.insuranceBet = 0;
      }
      if (isBlackjack(s.hand) && !s.tookEvenMoney) {
        s.natural = true;
        final win = (s.bet * 1.5).round(); // Blackjack pays 3:2
        s.bank += s.bet + win;
        s.lastDelta += win;
        s.lastOutcome = 'BLACKJACK +$win';
        onEvent?.call(BjEvent.natural);
      }
    }
    banner = 'No dealer blackjack — play on!';
    notifyListeners();
    _arm(Duration(milliseconds: beginTurnsGapMs), _beginPlayerTurns);
  }

  void _checkNaturalsAfterPeek({required bool dealerBlackjack}) {
    // Called when insurance was not offered (friendly table, or no ace).
    dealerHoleHidden = false;
    onEvent?.call(BjEvent.flip);
    final dv = handValue(dealerHand).value;
    var dealerBJ = dv == 21 && dealerHand.length == 2;
    if (dealerBJ) {
      banner = 'Dealer has Blackjack!';
      for (final s in seats) {
        if (isBlackjack(s.hand)) {
          s.natural = true;
          s.bank += s.bet;
          s.lastDelta = 0;
          s.lastOutcome = 'Push — bet back';
          onEvent?.call(BjEvent.push);
        } else {
          s.busted = true;
          s.lastDelta = -s.bet;
          s.lastOutcome = 'Dealer BJ −${s.bet}';
          onEvent?.call(BjEvent.lose);
        }
      }
      notifyListeners();
      phase = BjPhase.settling;
      _arm(Duration(milliseconds: finishGapMs), _finishRound);
      return;
    }
    for (final s in seats) {
      if (isBlackjack(s.hand)) {
        s.natural = true;
        final win = (s.bet * 1.5).round();
        s.bank += s.bet + win;
        s.lastDelta += win;
        s.lastOutcome = 'BLACKJACK +$win';
        onEvent?.call(BjEvent.natural);
      }
    }
    notifyListeners();
    _arm(Duration(milliseconds: beginTurnsGapMs), _beginPlayerTurns);
  }

  // ------------------------------------------------------------ player turn
  void _beginPlayerTurns() {
    if (_disposed) return;
    currentSeat = -1;
    _advanceSeat();
  }

  void _advanceSeat() {
    for (var i = currentSeat + 1; i < seats.length; i++) {
      if (seats[i].active && !isBlackjack(seats[i].hand)) {
        currentSeat = i;
        phase = BjPhase.playerTurn;
        final v = handValue(seats[i].hand).value;
        banner = '${seats[i].name}: $v — Hit or Stand?';
        notifyListeners();
        return;
      }
    }
    _beginDealerPlay();
  }

  BjSeat get _seat => seats[currentSeat];
  bool get _isFirstAction =>
      _seat.hand.length == 2 && !_seat.doubled && !_seat.surrendered;

  void hit() {
    if (phase != BjPhase.playerTurn || !_seat.active) {
      onEvent?.call(BjEvent.invalid);
      return;
    }
    _seat.hand.add(_draw());
    onEvent?.call(BjEvent.hit);
    final v = handValue(_seat.hand).value;
    if (v > 21) {
      _seat.busted = true;
      _seat.lastDelta = -_seat.bet;
      _seat.lastOutcome = 'Bust −${_seat.bet}';
      banner = '${_seat.name} busts with $v!';
      onEvent?.call(BjEvent.bust);
      notifyListeners();
      _arm(Duration(milliseconds: advanceGapMs), _advanceSeat);
    } else if (v == 21) {
      banner = '${_seat.name} hits 21!';
      _stand(silent: true);
    } else {
      banner = '${_seat.name}: $v — Hit or Stand?';
      notifyListeners();
    }
  }

  void stand() {
    if (phase != BjPhase.playerTurn || !_seat.active) {
      onEvent?.call(BjEvent.invalid);
      return;
    }
    _stand(silent: false);
  }

  void _stand({required bool silent}) {
    _seat.stood = true;
    final v = handValue(_seat.hand).value;
    banner = '${_seat.name} stands on $v.';
    if (!silent) onEvent?.call(BjEvent.stand);
    notifyListeners();
    _arm(Duration(milliseconds: standGapMs), _advanceSeat);
  }

  bool get canDouble =>
      phase == BjPhase.playerTurn &&
      _seat.active &&
      _isFirstAction &&
      _seat.bet <= _seat.bank;

  void doubleDown() {
    if (!canDouble) {
      onEvent?.call(BjEvent.invalid);
      return;
    }
    _seat.bank -= _seat.bet;
    _seat.bet *= 2;
    _seat.doubled = true;
    _seat.hand.add(_draw());
    onEvent?.call(BjEvent.double);
    final v = handValue(_seat.hand).value;
    if (v > 21) {
      _seat.busted = true;
      _seat.lastDelta = -_seat.bet;
      _seat.lastOutcome = 'Doubled… bust −${_seat.bet}';
      banner = '${_seat.name} doubles and busts with $v!';
      onEvent?.call(BjEvent.bust);
    } else {
      _seat.stood = true;
      banner = '${_seat.name} doubles to $v!';
    }
    notifyListeners();
    _arm(Duration(milliseconds: advanceGapMs), _advanceSeat);
  }

  bool get canSurrender =>
      phase == BjPhase.playerTurn &&
      _seat.active &&
      _isFirstAction &&
      dealerStyle.allowsSurrender;

  void surrender() {
    if (!canSurrender) {
      onEvent?.call(BjEvent.invalid);
      return;
    }
    _seat.surrendered = true;
    final back = _seat.bet ~/ 2;
    _seat.bank += back;
    _seat.lastDelta = -(back);
    _seat.lastOutcome = 'Surrendered −$back';
    banner = '${_seat.name} surrenders, keeps $back.';
    onEvent?.call(BjEvent.surrender);
    notifyListeners();
    _arm(Duration(milliseconds: surrenderGapMs), _advanceSeat);
  }

  // ------------------------------------------------------------ dealer play
  bool _dealerPending = false;

  void _beginDealerPlay() {
    // Dealer never draws when every seat already busted/surrendered.
    final live = seats.any(
        (s) => !s.busted && !s.surrendered && !s.tookEvenMoney && !s.natural);
    dealerHoleHidden = false;
    onEvent?.call(BjEvent.flip);
    final dv = handValue(dealerHand).value;
    if (!live) {
      banner = 'Dealer reveals $dv — table cleared.';
      notifyListeners();
      phase = BjPhase.settling;
      _arm(Duration(milliseconds: finishGapMs), _finishRound);
      return;
    }
    phase = BjPhase.dealerPlay;
    banner = 'Dealer reveals $dv…';
    notifyListeners();
    _dealerPending = true;
    _arm(Duration(milliseconds: dealerGapMs), _dealerStep);
  }

  bool _dealerMustHit() {
    final hv = handValue(dealerHand);
    if (hv.value < 17) return true;
    return hv.value == 17 && hv.soft && dealerStyle.hitsSoft17;
  }

  void _dealerStep() {
    if (phase != BjPhase.dealerPlay) return;
    if (!_dealerMustHit()) {
      _dealerPending = false;
      final dv = handValue(dealerHand).value;
      banner = 'Dealer stands on $dv.';
      onEvent?.call(BjEvent.dealerReveal);
      notifyListeners();
      phase = BjPhase.settling;
      _arm(Duration(milliseconds: settleGapMs), _settleBets);
      return;
    }
    final card = _draw();
    dealerHand.add(card);
    final dv = handValue(dealerHand).value;
    banner = 'Dealer hits… $dv${dv > 21 ? ' — BUST!' : ''}';
    onEvent?.call(BjEvent.dealerHit);
    notifyListeners();
    _arm(Duration(milliseconds: dealerGapMs), _dealerStep);
  }

  // ---------------------------------------------------------------- settle
  void _settleBets() {
    if (phase != BjPhase.settling) return;
    final dv = handValue(dealerHand).value;
    final dealerBust = dv > 21;
    for (final s in seats) {
      if (s.natural || s.tookEvenMoney || s.surrendered) continue;
      if (s.busted) {
        s.lastDelta = -s.bet;
        s.lastOutcome = 'Bust −${s.bet}';
        onEvent?.call(BjEvent.lose);
        continue;
      }
      final pv = handValue(s.hand).value;
      if (dealerBust) {
        s.bank += s.bet * 2;
        s.lastDelta = s.bet;
        s.lastOutcome = 'Dealer busts +${s.bet}';
        onEvent?.call(BjEvent.win);
      } else if (pv > dv) {
        s.bank += s.bet * 2;
        s.lastDelta = s.bet;
        s.lastOutcome = '$pv beats $dv +${s.bet}';
        onEvent?.call(BjEvent.win);
      } else if (pv < dv) {
        s.lastDelta = -s.bet;
        s.lastOutcome = '$dv beats $pv −${s.bet}';
        onEvent?.call(BjEvent.lose);
      } else {
        s.bank += s.bet;
        s.lastDelta = 0;
        s.lastOutcome = 'Push — bet back';
        onEvent?.call(BjEvent.push);
      }
    }
    // Insurance leftovers (should be zeroed already, but be safe).
    for (final s in seats) {
      s.insuranceBet = 0;
    }
    notifyListeners();
    _arm(Duration(milliseconds: finishGapMs), _finishRound);
  }

  void _finishRound() {
    if (_disposed) return;
    if (phase != BjPhase.settling && phase != BjPhase.dealerPlay) return;
    _dealerPending = false;
    phase = BjPhase.roundOver;
    final parts = <String>[];
    for (final s in seats) {
      parts.add('${s.name}: ${s.lastOutcome}');
    }
    banner = parts.join(' · ');
    notifyListeners();
  }

  /// Prepare the next hand. Keeps bankrolls; house tops up broke seats.
  void nextRound() {
    if (phase != BjPhase.roundOver) return;
    for (final s in seats) {
      s.bet = 0;
      s.hand.clear();
      s.stood = false;
      s.doubled = false;
      s.surrendered = false;
      s.busted = false;
      s.natural = false;
      s.tookEvenMoney = false;
      s.insuranceBet = 0;
      s.lastDelta = 0;
      s.lastOutcome = '';
      if (s.bank < minBet) s.bank = 1000; // house spots broke players
    }
    dealerHand.clear();
    dealerHoleHidden = true;
    currentSeat = 0;
    phase = BjPhase.betting;
    banner = 'Place your bets!';
    notifyListeners();
  }
}
