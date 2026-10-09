import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/casino_themes.dart';
import '../theme/casino_ui.dart';

/// Blackjack PRO: Free-vs-Pro comparison, real purchase, restore, tip jar.
/// All prices come from the store — never hardcoded, never placeholders.
class ProScreen extends StatefulWidget {
  final BlackjackAudio audio;
  final BlackjackSettings settings;
  const ProScreen({super.key, required this.audio, required this.settings});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  final StoreService _store = StoreService();

  CasinoThemeDef get _t => CasinoThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  @override
  void initState() {
    super.initState();
    // init() is async; rebuild when it completes so real store prices
    // replace the "available after store setup" placeholder state.
    _store.init().then((_) {
      if (mounted) setState(() {});
    });
    _store.proPurchased.addListener(_onPro);
    _store.lastThanks.addListener(_onThanks);
  }

  void _onPro() {
    if (_store.proPurchased.value && mounted) {
      widget.settings.setPro(true);
      widget.audio.win();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PRO unlocked — enjoy everything!',
              style: CasinoText.body(15, _t)),
          backgroundColor: _t.railDark,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _store.proPurchased.value = false;
    }
  }

  void _onThanks() {
    final msg = _store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: CasinoText.body(15, _t)),
        backgroundColor: _t.railDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _store.lastThanks.value = null;
  }

  @override
  void dispose() {
    _store.proPurchased.removeListener(_onPro);
    _store.lastThanks.removeListener(_onThanks);
    _store.dispose();
    super.dispose();
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
          title: Text('Blackjack PRO', style: CasinoText.display(22, t)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              child: Column(
                children: [
                  _ComparisonCard(theme: t, isPro: s.isPro),
                  const SizedBox(height: 16),
                  _BuyCard(
                    theme: t,
                    settings: s,
                    store: _store,
                    audio: widget.audio,
                  ),
                  const SizedBox(height: 16),
                  _TipsCard(
                    theme: t,
                    store: _store,
                    audio: widget.audio,
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
}

// ---------------------------------------------------------------------------
/// Free vs Pro comparison table — buyers see the big difference.
class _ComparisonCard extends StatelessWidget {
  final CasinoThemeDef theme;
  final bool isPro;
  const _ComparisonCard({required this.theme, required this.isPro});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Complete Blackjack game', true, true),
      ('Insurance & even money', true, true),
      ('Double down & surrender', true, true),
      ('Renameable players', true, true),
      ('Music & sound effects', true, true),
      ('Dealer styles', '2', '3'),
      ('Pass-and-play seats', '1', '3'),
      ('Table themes', '4', '16+'),
      ('Card backs', '4', '8'),
      ('Chip styles', '4', '8'),
      ('Custom theme creator', false, true),
      ('High Roller table', false, true),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.rail.withValues(alpha: 0.85),
            theme.railDark.withValues(alpha: 0.9),
          ],
        ),
        border: Border.all(color: theme.brass, width: 2),
      ),
      child: Column(
        children: [
          Text('Free vs PRO', style: CasinoText.display(20, theme)),
          const SizedBox(height: 4),
          Text(
            'One purchase. Yours forever.',
            style: CasinoText.body(13,
                theme,
                color: theme.ivory.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(flex: 5, child: SizedBox()),
              Expanded(
                  flex: 2,
                  child: Text('FREE',
                      style: CasinoText.label(12, theme),
                      textAlign: TextAlign.center)),
              Expanded(
                  flex: 2,
                  child: Text('PRO',
                      style: CasinoText.label(12, theme),
                      textAlign: TextAlign.center)),
            ],
          ),
          const Divider(height: 14),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child:
                        Text(r.$1, style: CasinoText.body(13, theme)),
                  ),
                  Expanded(flex: 2, child: _Cell(value: r.$2, theme: theme)),
                  Expanded(flex: 2, child: _Cell(value: r.$3, theme: theme)),
                ],
              ),
            ),
          if (isPro)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: theme.brass.withValues(alpha: 0.25),
                  border: Border.all(color: theme.brassLight),
                ),
                child: Text('✦ PRO ACTIVE ✦',
                    style: CasinoText.label(14, theme)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final Object value; // bool | String
  final CasinoThemeDef theme;
  const _Cell({required this.value, required this.theme});

  @override
  Widget build(BuildContext context) {
    if (value is bool) {
      final v = value as bool;
      return Text(
        v ? '✓' : '—',
        style: CasinoText.body(15,
            theme,
            color: v
                ? theme.brassLight
                : theme.ivory.withValues(alpha: 0.4)),
        textAlign: TextAlign.center,
      );
    }
    return Text(
      value as String,
      style: CasinoText.label(12, theme),
      textAlign: TextAlign.center,
    );
  }
}

// ---------------------------------------------------------------------------
class _BuyCard extends StatelessWidget {
  final CasinoThemeDef theme;
  final BlackjackSettings settings;
  final StoreService store;
  final BlackjackAudio audio;
  const _BuyCard({
    required this.theme,
    required this.settings,
    required this.store,
    required this.audio,
  });

  @override
  Widget build(BuildContext context) {
    final pro = store.proProduct;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.rail.withValues(alpha: 0.85),
            theme.railDark.withValues(alpha: 0.9),
          ],
        ),
        border: Border.all(color: theme.brass, width: 2),
      ),
      child: Column(
        children: [
          Text('Unlock PRO', style: CasinoText.display(20, theme)),
          const SizedBox(height: 8),
          if (settings.isPro)
            Text('You already own PRO — thank you!',
                style: CasinoText.body(14, theme),
                textAlign: TextAlign.center)
          else if (!store.storeReady)
            Text(
              store.error ?? 'Available after store setup.',
              style: CasinoText.body(14,
                  theme,
                  color: theme.ivory.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            )
          else if (pro != null) ...[
            Text(pro.description.isNotEmpty
                ? pro.description
                : 'Unlock everything in Blackjack, forever.',
                style: CasinoText.body(14, theme),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ValueListenableBuilder<bool>(
              valueListenable: store.purchaseInProgress,
              builder: (_, busy, _) => CasinoButton(
                label: busy ? 'Working…' : 'Get PRO — ${pro.price}',
                width: 260,
                theme: theme,
                onTap: busy
                    ? () {}
                    : () {
                        audio.click();
                        store.buyPro();
                      },
              ),
            ),
          ],
          ValueListenableBuilder<String?>(
            valueListenable: store.purchaseError,
            builder: (_, err, _) => err == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(err,
                        style: CasinoText.body(13,
                            theme,
                            color: const Color(0xFFE08A8A)),
                        textAlign: TextAlign.center),
                  ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              audio.click();
              store.restore();
            },
            child: Text('Restore purchases',
                style: CasinoText.label(13, theme)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Consumable tips — pure support, with real store prices.
class _TipsCard extends StatelessWidget {
  final CasinoThemeDef theme;
  final StoreService store;
  final BlackjackAudio audio;
  const _TipsCard(
      {required this.theme, required this.store, required this.audio});

  @override
  Widget build(BuildContext context) {
    final tips = [
      store.coffeeProduct,
      store.chocolateProduct,
    ].whereType<ProductDetails>().toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.rail.withValues(alpha: 0.85),
            theme.railDark.withValues(alpha: 0.9),
          ],
        ),
        border: Border.all(color: theme.brass, width: 2),
      ),
      child: Column(
        children: [
          Text('Tip the Maker', style: CasinoText.display(20, theme)),
          const SizedBox(height: 8),
          Text(
            'Blackjack is free forever. A small tip keeps new games coming!',
            style: CasinoText.body(14, theme),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (!store.storeReady)
            Text(
              store.error ?? 'Available after store setup.',
              style: CasinoText.body(13,
                  theme,
                  color: theme.ivory.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            )
          else if (tips.isEmpty)
            Text('Tips coming soon.',
                style: CasinoText.body(13,
                    theme,
                    color: theme.ivory.withValues(alpha: 0.6)))
          else
            Wrap(
              spacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final p in tips)
                  _TipChip(
                    theme: theme,
                    label:
                        '${p.id == StoreService.chocolateId ? '🍫' : '☕'} ${p.price}',
                    onTap: () {
                      audio.click();
                      store.buyTip(p);
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TipChip extends StatelessWidget {
  final CasinoThemeDef theme;
  final String label;
  final VoidCallback onTap;
  const _TipChip(
      {required this.theme, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.black.withValues(alpha: 0.3),
          border: Border.all(
              color: theme.brass.withValues(alpha: 0.6), width: 1.5),
        ),
        child: Text(label, style: CasinoText.label(14, theme)),
      ),
    );
  }
}
