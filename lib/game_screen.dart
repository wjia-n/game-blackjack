import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

class _Card {
  final int rank; // 1=A .. 13=K
  final int suit;
  const _Card(this.rank, this.suit);
  String get rankLabel =>
      rank == 1 ? 'A' : rank == 11 ? 'J' : rank == 12 ? 'Q' : rank == 13 ? 'K' : '$rank';
  String get suitLabel => '♠♥♦♣'[suit];
  bool get red => suit == 1 || suit == 2;
}

int _handValue(List<_Card> h) {
  var total = 0;
  var aces = 0;
  for (final c in h) {
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
  return total;
}

enum _Phase { betting, player, dealer, done }

class BlackjackScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;
  const BlackjackScreen({super.key, required this.players, required this.callbacks});
  @override
  State<BlackjackScreen> createState() => _BlackjackScreenState();
}

class _BlackjackScreenState extends State<BlackjackScreen> {
  final _rnd = Random();
  int _bank = 1000;
  double _shownBank = 1000;
  Timer? _bankTimer;
  int _bet = 0;
  List<_Card> _deck = [];
  List<_Card> _player = [];
  List<_Card> _dealer = [];
  _Phase _phase = _Phase.betting;
  String _msg = 'Place your bet, high roller! 🎲';
  bool _over = false;

  @override
  void initState() {
    super.initState();
    _loadBank();
  }

  @override
  void dispose() {
    _bankTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBank() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _bank = p.getInt('bj_bank') ?? 1000;
      _shownBank = _bank.toDouble();
    });
  }

  Future<void> _saveBank() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('bj_bank', _bank);
  }

  void _animateBank(int to) {
    _bankTimer?.cancel();
    _bankTimer = Timer.periodic(const Duration(milliseconds: 40), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        final diff = to - _shownBank;
        if (diff.abs() < 1) {
          _shownBank = to.toDouble();
          t.cancel();
        } else {
          _shownBank += diff * 0.18;
        }
      });
    });
  }

  void _addChip(int v) {
    if (_phase != _Phase.betting || _bet + v > _bank) return;
    Sfx.tap();
    setState(() {
      _bet += v;
    });
  }

  void _clearBet() {
    if (_phase != _Phase.betting) return;
    Sfx.tap();
    setState(() => _bet = 0);
  }

  void _newDeck() {
    _deck = [];
    for (var s = 0; s < 4; s++) {
      for (var r = 1; r <= 13; r++) {
        _deck.add(_Card(r, s));
      }
    }
    _deck.shuffle(_rnd);
  }

  void _deal() {
    if (_bet <= 0 || _phase != _Phase.betting) return;
    Sfx.move();
    setState(() {
      _newDeck();
      _player = [_deck.removeLast(), _deck.removeLast()];
      _dealer = [_deck.removeLast(), _deck.removeLast()];
      _phase = _Phase.player;
      _msg = 'Your move, champ! 😎';
    });
    final pv = _handValue(_player);
    final dv = _handValue(_dealer);
    if (pv == 21 || dv == 21) {
      _settle(natural: true);
    }
  }

  void _hit() {
    if (_phase != _Phase.player) return;
    Sfx.tap();
    setState(() {
      _player.add(_deck.removeLast());
      if (_handValue(_player) > 21) {
        _msg = 'BUST! The dealer does a happy dance. 💃';
      } else if (_handValue(_player) == 21) {
        _msg = '21! Ice cold. 🧊';
      }
    });
    if (_handValue(_player) >= 21) _dealerPlay();
  }

  void _stand() {
    if (_phase != _Phase.player) return;
    Sfx.click();
    _dealerPlay();
  }

  void _double() {
    if (_phase != _Phase.player || _player.length != 2 || _bet * 2 > _bank) return;
    Sfx.move();
    setState(() {
      _bet *= 2;
      _player.add(_deck.removeLast());
      _msg = _handValue(_player) > 21 ? 'Doubled… and BUSTED! 😱' : 'Doubled down! Bold! 🔥';
    });
    _dealerPlay();
  }

  Future<void> _dealerPlay() async {
    setState(() => _phase = _Phase.dealer);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted || _over) return;
    while (_handValue(_dealer) < 17) {
      setState(() => _dealer.add(_deck.removeLast()));
      Sfx.tap();
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted || _over) return;
    }
    _settle();
  }

  void _settle({bool natural = false}) {
    final pv = _handValue(_player);
    final dv = _handValue(_dealer);
    final pBJ = _player.length == 2 && pv == 21;
    final dBJ = _dealer.length == 2 && dv == 21;
    var delta = 0;
    var msg = '';
    if (pv > 21) {
      delta = -_bet;
      msg = 'Bust! -$_bet chips 💸';
    } else if (dv > 21) {
      delta = _bet;
      msg = 'Dealer busts! +$_bet chips! 🎉';
    } else if (pBJ && !dBJ) {
      delta = (_bet * 1.5).round();
      msg = 'BLACKJACK! Pays 3:2 → +$delta! 🤑';
    } else if (dBJ && !pBJ) {
      delta = -_bet;
      msg = 'Dealer blackjack. Ouch. -$_bet 😤';
    } else if (pv > dv) {
      delta = _bet;
      msg = '$pv beats $dv! +$_bet! 🏆';
    } else if (pv < dv) {
      delta = -_bet;
      msg = '$dv beats $pv. -$_bet 😭';
    } else {
      msg = 'Push! Bet returned. 🤝';
    }
    final newBank = _bank + delta;
    if (delta > 0) {
      Sfx.win();
    } else if (delta < 0) {
      Sfx.lose();
    } else {
      Sfx.click();
    }
    setState(() {
      _msg = msg;
      _phase = _Phase.done;
    });
    _animateBank(newBank);
    setState(() => _bank = newBank);
    _saveBank();
    widget.players[0].score = _bank;
    widget.callbacks.refreshHud();
  }

  void _nextHand() {
    Sfx.tap();
    setState(() {
      _bet = 0;
      _player = [];
      _dealer = [];
      _phase = _Phase.betting;
      _msg = _bank < 10 ? 'Out of chips?!' : 'Place your bet, high roller! 🎲';
    });
  }

  void _cashOut() {
    if (_over) return;
    _over = true;
    Sfx.win();
    widget.callbacks.finish(
      headline: '💰 You cashed out with $_bank chips!',
      subline: _bank >= 1000
          ? 'The house is filing a complaint. Come back soon! 🤑'
          : 'The tables will miss you. Better luck next time! 🍀',
    );
  }

  Widget _card(_Card c, {bool faceDown = false, double w = 56}) {
    final t = ThemeController.of(context).theme;
    return Container(
      width: w,
      height: w * 1.42,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: faceDown ? null : Colors.white,
        gradient: faceDown ? t.headerGradient : null,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: faceDown ? Colors.white24 : Colors.black12, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 5, offset: const Offset(0, 3))
        ],
      ),
      child: faceDown
          ? const Center(child: Text('🂡', style: TextStyle(fontSize: 26)))
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(c.rankLabel,
                    style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: c.red ? Colors.red.shade700 : Colors.grey.shade900)),
                Text(c.suitLabel,
                    style: TextStyle(
                        fontSize: 20, color: c.red ? Colors.red.shade700 : Colors.grey.shade900)),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    final dealerShowsHole = _phase == _Phase.player;
    return Column(
      children: [
        // bankroll HUD
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(color: t.surface, borderRadius: t.radius),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('💰 ${_shownBank.round()}',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900, color: t.primary)),
              Text('Bet: $_bet',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: t.text)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(_msg,
            textAlign: TextAlign.center,
            style: TextStyle(color: t.text, fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 8),
        // dealer
        Text('🤵 Dealer${_phase == _Phase.player ? '' : ' • ${_handValue(_dealer)}'}',
            style: TextStyle(color: t.muted, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        SizedBox(
          height: 92,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _dealer.length; i++)
                _card(_dealer[i], faceDown: dealerShowsHole && i == 1),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // player
        Text('😎 You • ${_player.isEmpty ? '–' : _handValue(_player)}',
            style: TextStyle(color: t.muted, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        SizedBox(
          height: 92,
          child: _player.isEmpty
              ? Center(
                  child: Text('Your cards appear here… 🃏',
                      style: TextStyle(color: t.muted, fontStyle: FontStyle.italic)))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [for (final c in _player) _card(c)],
                ),
        ),
        const Spacer(),
        // actions
        if (_phase == _Phase.betting) ...[
          if (_bank < 10)
            WajihaButton(
              label: 'House spots you 1000 🤑',
              emoji: '🎰',
              onTap: () {
                Sfx.win();
                setState(() => _bank = 1000);
                _animateBank(1000);
                _saveBank();
              },
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final chip in [10, 25, 50, 100])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => _addChip(chip),
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: t.headerGradient,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                                color: t.primary.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4))
                          ],
                        ),
                        child: Center(
                            child: Text('$chip',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15))),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                WajihaButton(label: 'Clear', onTap: _clearBet, primary: false, fontSize: 15),
                const SizedBox(width: 10),
                WajihaButton(
                    label: 'Deal! 🃏', onTap: _bet > 0 ? _deal : () {}, primary: _bet > 0, fontSize: 17),
              ],
            ),
          ],
        ] else if (_phase == _Phase.player) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              WajihaButton(label: 'Hit 👊', onTap: _hit, fontSize: 16),
              const SizedBox(width: 8),
              WajihaButton(label: 'Stand ✋', onTap: _stand, primary: false, fontSize: 16),
              const SizedBox(width: 8),
              WajihaButton(
                label: '2x 🔥',
                onTap: _player.length == 2 && _bet * 2 <= _bank ? _double : () {},
                primary: _player.length == 2 && _bet * 2 <= _bank,
                fontSize: 16,
              ),
            ],
          ),
        ] else if (_phase == _Phase.done) ...[
          WajihaButton(label: 'Next Hand 🃏', emoji: '🔄', onTap: _nextHand),
        ] else ...[
          Text('Dealer is thinking… 🤔', style: TextStyle(color: t.muted)),
        ],
        const SizedBox(height: 8),
        TextButton(
          onPressed: _phase == _Phase.betting || _phase == _Phase.done ? _cashOut : null,
          child: Text('Cash Out 💰',
              style: TextStyle(
                  color: t.muted, fontWeight: FontWeight.w800, decoration: TextDecoration.underline)),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
