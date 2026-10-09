import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import '../engine/blackjack_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/casino_themes.dart';
import '../theme/casino_ui.dart';

/// The blackjack table: engine-driven play with fully visible dealer action,
/// animated deals, narration banner, betting, insurance, and payouts.
class GameScreen extends StatefulWidget {
  final BlackjackAudio audio;
  final BlackjackSettings settings;
  const GameScreen({super.key, required this.audio, required this.settings});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final BlackjackEngine _engine;
  int _bettingSeat = 0;
  bool _paused = false;
  bool _statsRecorded = false;
  int _reviewCounter = 0;

  CasinoThemeDef get _t => CasinoThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final s = widget.settings;
    _engine = BlackjackEngine(
      seats: [
        for (var i = 0; i < s.humanSeats; i++)
          BjSeat(name: s.seatNames[i], bank: s.seatBanks[i]),
      ],
      dealerStyle: DealerStyle.values[s.dealerStyle],
    );
    _engine.onEvent = _onEngineEvent;
    _engine.addListener(_onEngineChanged);
    widget.audio.startGameMusic();
  }

  /// Phase-change listener: records stats exactly once per finished round.
  void _onEngineChanged() {
    if (_engine.phase == BjPhase.roundOver && !_statsRecorded) {
      _statsRecorded = true;
      _recordStats();
    }
    if (_engine.phase == BjPhase.betting) {
      _statsRecorded = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _engine.dispose();
    widget.audio.startMenuMusic();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _engine.setPaused(true);
      widget.audio.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      _engine.setPaused(false);
      widget.audio.onAppResumed();
    }
  }

  void _onEngineEvent(BjEvent e) {
    final a = widget.audio;
    switch (e) {
      case BjEvent.shuffle:
        a.shuffle();
      case BjEvent.bet:
        a.chip();
      case BjEvent.deal:
      case BjEvent.hit:
        a.cardSlide();
      case BjEvent.flip:
        a.cardFlip();
      case BjEvent.stand:
        a.click();
      case BjEvent.double:
        a.chipsWon();
      case BjEvent.surrender:
        a.click();
      case BjEvent.bust:
        a.bust();
      case BjEvent.insurance:
      case BjEvent.evenMoney:
        a.ding();
      case BjEvent.dealerReveal:
        a.cardFlip();
      case BjEvent.dealerHit:
        a.cardSlide();
      case BjEvent.natural:
      case BjEvent.win:
        a.win();
        a.chipsWon();
      case BjEvent.lose:
        a.lose();
      case BjEvent.push:
        a.push();
      case BjEvent.roundStart:
        a.gameStart();
      case BjEvent.invalid:
        a.invalid();
    }
    if (e == BjEvent.win || e == BjEvent.natural) {
      _maybeReview();
    }
  }

  Future<void> _recordStats() async {
    final s = widget.settings;
    for (var i = 0; i < _engine.seats.length; i++) {
      final seat = _engine.seats[i];
      await s.setSeatBank(i, seat.bank);
      await s.recordHand(
        won: seat.lastDelta > 0,
        blackjack: seat.lastOutcome.startsWith('BLACKJACK'),
        winAmount: seat.lastDelta > 0 ? seat.lastDelta : 0,
      );
    }
  }

  Future<void> _maybeReview() async {
    _reviewCounter++;
    if (_reviewCounter % 6 != 0) return;
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
      }
    } catch (_) {
      // Graceful when not installed from Play.
    }
  }

  void _togglePause() {
    setState(() {
      _paused = !_paused;
      _engine.setPaused(_paused);
    });
    widget.audio.click();
  }

  void _quitToMenu() {
    widget.audio.click();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return FeltBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: t.brassLight),
            onPressed: _quitToMenu,
          ),
          title: Text('Blackjack', style: CasinoText.display(20, t)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(_paused ? Icons.play_arrow : Icons.pause,
                  color: t.brassLight),
              onPressed: _togglePause,
            ),
          ],
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _engine,
            builder: (_, _) => Stack(
              children: [
                Column(
                  children: [
                    _dealerZone(t),
                    _banner(t),
                    Expanded(child: _seatsZone(t)),
                    _actionZone(t),
                    const SizedBox(height: 10),
                  ],
                ),
                if (_paused) _pauseOverlay(t),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- dealer
  Widget _dealerZone(CasinoThemeDef t) {
    final dv = handValue(_engine.dealerHand);
    final showValue = !_engine.dealerHoleHidden && _engine.dealerHand.isNotEmpty;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.black.withValues(alpha: 0.3),
        border: Border.all(color: t.brass.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('🎩 ${_engine.dealerStyle.name}',
                  style: CasinoText.label(13, t)),
              const SizedBox(width: 10),
              if (showValue)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: t.brass.withValues(alpha: 0.85),
                  ),
                  child: Text(
                    dv.value == 21 && _engine.dealerHand.length == 2
                        ? 'BLACKJACK'
                        : '${dv.value}${dv.soft ? ' soft' : ''}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: t.ink),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 96,
            child: _engine.dealerHand.isEmpty
                ? Center(
                    child: Text('Dealer cards appear here…',
                        style: CasinoText.body(12, t,
                            color: t.muted,
                            style: FontStyle.italic)))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _engine.dealerHand.length; i++)
                        PlayingCard(
                          key: ValueKey('d${_engine.dealerHand[i].uid}'),
                          card: _engine.dealerHand[i],
                          theme: t,
                          faceDown:
                              _engine.dealerHoleHidden && i == 1,
                          cardBackStyle: widget.settings.cardBack,
                          width: 62,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _banner(CasinoThemeDef t) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: t.railDark.withValues(alpha: 0.85),
        border: Border.all(color: t.brass.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(Icons.campaign, color: t.brassLight, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _engine.banner,
              style: CasinoText.body(13, t, color: t.brassLight),
              textAlign: TextAlign.center,
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- seats
  Widget _seatsZone(CasinoThemeDef t) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      itemCount: _engine.seats.length,
      itemBuilder: (_, i) => _seatCard(t, i),
    );
  }

  Widget _seatCard(CasinoThemeDef t, int i) {
    final s = _engine.seats[i];
    final hv = handValue(s.hand);
    final isCurrent = _engine.phase == BjPhase.playerTurn &&
        _engine.currentSeat == i;
    final isBetting = _engine.phase == BjPhase.betting && _bettingSeat == i;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isCurrent
            ? t.brass.withValues(alpha: 0.28)
            : Colors.black.withValues(alpha: 0.25),
        border: Border.all(
          color: isCurrent
              ? t.brassLight
              : isBetting
                  ? t.brass.withValues(alpha: 0.7)
                  : t.brass.withValues(alpha: 0.35),
          width: isCurrent ? 2.5 : 1.2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${isCurrent ? '▶ ' : ''}${s.name}',
                  style: CasinoText.label(14, t),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (s.hand.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    color: t.ivory.withValues(alpha: 0.92),
                  ),
                  child: Text(
                    isBlackjack(s.hand) ? 'BJ!' : '${hv.value}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: t.ink),
                  ),
                ),
              const SizedBox(width: 8),
              Text('💰 ${s.bank}',
                  style: CasinoText.body(13, t, color: t.brassLight)),
              if (s.bet > 0) ...[
                const SizedBox(width: 8),
                Text('Bet ${s.bet}',
                    style: CasinoText.body(12, t, color: t.muted)),
              ],
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 88,
            child: s.hand.isEmpty
                ? Center(
                    child: _engine.phase == BjPhase.betting
                        ? Text('Waiting for bet…',
                            style: CasinoText.body(12, t,
                                color: t.muted,
                                style: FontStyle.italic))
                        : null,
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final c in s.hand)
                        PlayingCard(
                          key: ValueKey('s$i-${c.uid}'),
                          card: c,
                          theme: t,
                          cardBackStyle: widget.settings.cardBack,
                          width: 56,
                          dimmed: s.busted,
                        ),
                      if (s.doubled)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text('2×',
                              style: CasinoText.label(13, t)),
                        ),
                    ],
                  ),
          ),
          if (s.lastOutcome.isNotEmpty &&
              _engine.phase == BjPhase.roundOver)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(s.lastOutcome,
                  style: CasinoText.body(13, t,
                      color: s.lastDelta > 0
                          ? const Color(0xFF7FD67F)
                          : s.lastDelta < 0
                              ? const Color(0xFFE08A8A)
                              : t.muted)),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- actions
  Widget _actionZone(CasinoThemeDef t) {
    switch (_engine.phase) {
      case BjPhase.betting:
        return _bettingZone(t);
      case BjPhase.insurance:
        return _insuranceZone(t);
      case BjPhase.playerTurn:
        return _playerZone(t);
      case BjPhase.roundOver:
        return _roundOverZone(t);
      case BjPhase.dealing:
      case BjPhase.dealerPlay:
      case BjPhase.settling:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            _engine.phase == BjPhase.dealing
                ? 'Dealing… 🃏'
                : _engine.phase == BjPhase.dealerPlay
                    ? 'Dealer is playing… 🎩'
                    : 'Settling bets… 💰',
            style: CasinoText.body(14, t,
                color: t.muted, style: FontStyle.italic),
          ),
        );
    }
  }

  Widget _bettingZone(CasinoThemeDef t) {
    final seats = _engine.seats;
    return Column(
      children: [
        if (seats.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < seats.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(seats[i].name,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _bettingSeat == i ? t.ink : t.brassLight,
                            fontSize: 12)),
                    selected: _bettingSeat == i,
                    selectedColor: t.brassLight,
                    backgroundColor:
                        Colors.black.withValues(alpha: 0.4),
                    side: BorderSide(color: t.brass.withValues(alpha: 0.6)),
                    onSelected: (_) {
                      widget.audio.click();
                      setState(() => _bettingSeat = i);
                    },
                  ),
                ),
            ],
          ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final d in [10, 25, 50, 100])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: PokerChip(
                  denom: d,
                  chipStyle: widget.settings.chipStyle,
                  size: 58,
                  dimmed: !_engine.canBet(_bettingSeat, d),
                  onTap: () => _engine.addChip(_bettingSeat, d),
                ),
              ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _engine.clearBet(_bettingSeat),
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.45),
                  border: Border.all(
                      color: t.brass.withValues(alpha: 0.6), width: 2),
                ),
                child: Center(
                  child: Text('CLR',
                      style: CasinoText.label(12, t)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        CasinoButton(
          label: 'Deal! 🃏',
          onTap: _engine.canStartRound ? () => _engine.startRound() : () {},
          enabled: _engine.canStartRound,
          theme: t,
          width: 240,
          fontSize: 17,
        ),
      ],
    );
  }

  Widget _insuranceZone(CasinoThemeDef t) {
    final s = _engine.seats[_engine.currentSeat];
    final hasBJ = isBlackjack(s.hand);
    return Column(
      children: [
        Text(
          hasBJ
              ? '${s.name} has Blackjack — take even money (1:1)?'
              : 'Dealer shows an Ace. ${s.name}: buy insurance (${s.bet ~/ 2} chips)?',
          style: CasinoText.body(14, t),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CasinoButton(
              label: hasBJ ? 'Even Money ✓' : 'Insure 🛡',
              onTap: () => _engine.decideInsurance(true),
              theme: t,
              width: 160,
              fontSize: 15,
            ),
            const SizedBox(width: 10),
            CasinoButton(
              label: hasBJ ? 'Let it Ride' : 'No Thanks',
              onTap: () => _engine.decideInsurance(false),
              theme: t,
              primary: false,
              width: 150,
              fontSize: 15,
            ),
          ],
        ),
      ],
    );
  }

  Widget _playerZone(CasinoThemeDef t) {
    final s = _engine.seats[_engine.currentSeat];
    return Column(
      children: [
        Text('${s.name}\'s turn',
            style: CasinoText.label(14, t)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          alignment: WrapAlignment.center,
          children: [
            CasinoButton(
              label: 'Hit 👊',
              onTap: () => _engine.hit(),
              theme: t,
              width: 108,
              fontSize: 15,
            ),
            CasinoButton(
              label: 'Stand ✋',
              onTap: () => _engine.stand(),
              theme: t,
              primary: false,
              width: 118,
              fontSize: 15,
            ),
            CasinoButton(
              label: 'Double 2×',
              onTap: () => _engine.doubleDown(),
              theme: t,
              enabled: _engine.canDouble,
              width: 118,
              fontSize: 15,
            ),
            if (_engine.dealerStyle.allowsSurrender)
              CasinoButton(
                label: 'Give Up',
                onTap: () => _engine.surrender(),
                theme: t,
                primary: false,
                enabled: _engine.canSurrender,
                width: 110,
                fontSize: 15,
              ),
          ],
        ),
      ],
    );
  }

  Widget _roundOverZone(CasinoThemeDef t) {
    return CasinoButton(
      label: 'Next Hand 🔄',
      onTap: () {
        widget.audio.click();
        _engine.nextRound();
        setState(() => _bettingSeat = 0);
      },
      theme: t,
      width: 240,
      fontSize: 17,
    );
  }

  Widget _pauseOverlay(CasinoThemeDef t) {
    final s = widget.settings;
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 36),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [t.rail, t.railDark],
            ),
            border: Border.all(color: t.brass, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Paused', style: CasinoText.display(26, t)),
              const SizedBox(height: 14),
              _toggleRow(t, 'Music', Icons.music_note, s.musicOn, (v) async {
                await s.setMusic(v);
                widget.audio.configure(
                    musicOn: v, sfxOn: s.sfxOn, volume: s.volume);
                if (v) widget.audio.startGameMusic();
              }),
              _toggleRow(t, 'Sound FX', Icons.volume_up, s.sfxOn, (v) async {
                await s.setSfx(v);
                widget.audio.configure(
                    musicOn: s.musicOn, sfxOn: v, volume: s.volume);
              }),
              const SizedBox(height: 10),
              CasinoButton(
                label: 'Resume ▶',
                onTap: _togglePause,
                theme: t,
                width: 220,
              ),
              const SizedBox(height: 8),
              CasinoButton(
                label: 'Quit to Menu',
                onTap: _quitToMenu,
                theme: t,
                primary: false,
                width: 220,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggleRow(CasinoThemeDef t, String label, IconData icon, bool value,
      Future<void> Function(bool) onChanged) {
    return Row(
      children: [
        Icon(icon, color: t.brassLight, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: CasinoText.body(15, t))),
        Switch(
          value: value,
          activeThumbColor: t.brassLight,
          onChanged: (v) {
            widget.audio.click();
            onChanged(v);
          },
        ),
      ],
    );
  }
}
