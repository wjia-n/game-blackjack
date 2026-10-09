import 'dart:math';
import 'package:flutter/material.dart';
import '../engine/blackjack_engine.dart';
import 'casino_themes.dart';

/// Shared casino UI kit: felt backdrops, brass buttons, physical playing
/// cards, poker chips. Pseudo-3D: real materials, depth, bevels, shadows.

class CasinoText {
  static TextStyle display(double size, CasinoThemeDef t) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: t.brassLight,
        letterSpacing: 1.2,
        shadows: const [
          Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 4)
        ],
      );

  static TextStyle label(double size, CasinoThemeDef t) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: t.brassLight,
        letterSpacing: 0.8,
      );

  static TextStyle body(double size, CasinoThemeDef t,
          {Color? color, FontStyle? style}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? t.ivory,
        fontStyle: style,
      );
}

/// Felt table backdrop with a wooden rail edge and soft vignette.
class FeltBackdrop extends StatelessWidget {
  final CasinoThemeDef theme;
  final Widget child;
  const FeltBackdrop({super.key, required this.theme, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.3),
          radius: 1.4,
          colors: [theme.felt, theme.feltDeep],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: theme.railDark, width: 10),
            left: BorderSide(color: theme.railDark.withValues(alpha: 0.4), width: 4),
            right: BorderSide(color: theme.railDark.withValues(alpha: 0.4), width: 4),
            bottom: BorderSide(color: theme.railDark, width: 10),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.rail.withValues(alpha: 0.55),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.25),
              ],
              stops: const [0.0, 0.08, 1.0],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Brass-rimmed casino button.
class CasinoButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final CasinoThemeDef theme;
  final bool primary;
  final bool enabled;
  final double fontSize;
  final double width;
  final IconData? icon;

  const CasinoButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.theme,
    this.primary = true,
    this.enabled = true,
    this.fontSize = 16,
    this.width = 220,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final on = enabled;
    return Opacity(
      opacity: on ? 1.0 : 0.45,
      child: GestureDetector(
        onTap: on ? onTap : null,
        child: Container(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: primary
                  ? [theme.brassLight, theme.brass, theme.brassDark]
                  : [
                      theme.rail.withValues(alpha: 0.9),
                      theme.railDark.withValues(alpha: 0.95),
                    ],
            ),
            border: Border.all(
              color: primary ? theme.brassLight : theme.brass.withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                offset: const Offset(0, 4),
                blurRadius: 8,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: on ? 0.18 : 0.05),
                offset: const Offset(0, 1),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: fontSize + 2,
                    color: primary ? theme.ink : theme.brassLight),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                    color: primary ? theme.ink : theme.brassLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A physical playing card: beveled ivory face, soft shadow. Newly dealt
/// cards slide in on their own animation.
class PlayingCard extends StatefulWidget {
  final BjCard card;
  final bool faceDown;
  final CasinoThemeDef theme;
  final int cardBackStyle;
  final double width;
  final bool dimmed;

  const PlayingCard({
    super.key,
    required this.card,
    required this.theme,
    this.faceDown = false,
    this.cardBackStyle = 0,
    this.width = 58,
    this.dimmed = false,
  });

  @override
  State<PlayingCard> createState() => _PlayingCardState();
}

class _PlayingCardState extends State<PlayingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slide = Tween<double>(begin: -46, end: 0).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final h = widget.width * 1.42;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Opacity(
        opacity: (_fade.value * (widget.dimmed ? 0.55 : 1.0)).clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, _slide.value),
          child: child,
        ),
      ),
      child: Container(
        width: widget.width,
        height: h,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: widget.faceDown ? null : t.ivory,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: widget.faceDown
                ? Colors.white24
                : Colors.black.withValues(alpha: 0.25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              offset: const Offset(0, 4),
              blurRadius: 7,
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: widget.faceDown ? 0 : 0.25),
              offset: const Offset(0, 1),
              blurRadius: 0,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: widget.faceDown
            ? CustomPaint(
                painter: _CardBackPainter(
                  style: widget.cardBackStyle,
                ),
              )
            : _CardFace(card: widget.card, theme: t),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  final BjCard card;
  final CasinoThemeDef theme;
  const _CardFace({required this.card, required this.theme});

  @override
  Widget build(BuildContext context) {
    final color =
        card.red ? const Color(0xFFA31621) : const Color(0xFF1E2430);
    return Padding(
      padding: const EdgeInsets.all(5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.rankLabel,
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w900, color: color),
          ),
          Text(card.suitLabel,
              style: TextStyle(fontSize: 15, color: color)),
          const Spacer(),
          Center(
            child: Text(
              card.suitLabel,
              style: TextStyle(fontSize: 30, color: color),
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Column(
                children: [
                  Text(
                    card.rankLabel,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: color),
                  ),
                  Text(card.suitLabel,
                      style: TextStyle(fontSize: 11, color: color)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Painted card-back patterns (no images — physical print look).
class _CardBackPainter extends CustomPainter {
  final int style;
  const _CardBackPainter({required this.style});

  @override
  void paint(Canvas canvas, Size size) {
    final base = Color(CardBackStyles.baseColors[style]);
    final line = Color(CardBackStyles.lineColors[style]);
    final pattern = CardBackStyles.patterns[style];
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = base);
    final p = Paint()
      ..color = line.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final cx = size.width / 2;
    final cy = size.height / 2;
    switch (pattern) {
      case 'lattice':
        for (double x = -size.height; x < size.width + size.height; x += 9) {
          canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), p);
          canvas.drawLine(Offset(x + size.height, 0), Offset(x, size.height), p);
        }
      case 'medallion':
        for (var r = 6.0; r < size.width; r += 8) {
          canvas.drawCircle(Offset(cx, cy), r, p);
        }
        canvas.drawCircle(Offset(cx, cy), 4, Paint()..color = line);
      case 'diamond':
        for (double y = 0; y < size.height + 12; y += 12) {
          for (double x = 0; x < size.width + 12; x += 12) {
            canvas.drawPath(
                Path()
                  ..moveTo(x + 6, y)
                  ..lineTo(x + 12, y + 6)
                  ..lineTo(x + 6, y + 12)
                  ..lineTo(x, y + 6)
                  ..close(),
                p);
          }
        }
      case 'swirl':
        for (var r = 4.0; r < size.width * 1.2; r += 7) {
          canvas.drawArc(
              Rect.fromCircle(center: Offset(cx, cy), radius: r),
              r * 0.3,
              3.6,
              false,
              p);
        }
      case 'crest':
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset(cx, cy), width: 30, height: 44),
                const Radius.circular(6)),
            p..strokeWidth = 2);
        canvas.drawCircle(Offset(cx, cy), 7, p..strokeWidth = 1.4);
      case 'stripes':
        for (double x = 4; x < size.width; x += 10) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
        }
      case 'dots':
        for (double y = 6; y < size.height; y += 12) {
          for (double x = 6; x < size.width; x += 12) {
            canvas.drawCircle(Offset(x, y), 2.2, Paint()..color = line);
          }
        }
      case 'chevron':
        for (double y = 0; y < size.height + 14; y += 14) {
          canvas.drawPath(
              Path()
                ..moveTo(0, y + 7)
                ..lineTo(cx, y)
                ..lineTo(size.width, y + 7),
              p);
        }
    }
    // Ivory border frame.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(3, 3, size.width - 6, size.height - 6),
            const Radius.circular(7)),
        Paint()
          ..color = const Color(0xFFFBF7EC).withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2);
  }

  @override
  bool shouldRepaint(covariant _CardBackPainter old) =>
      old.style != style;
}

/// A physical poker chip with edge spots and a denomination label.
class PokerChip extends StatelessWidget {
  final int denom;
  final int chipStyle;
  final double size;
  final VoidCallback? onTap;
  final bool dimmed;

  const PokerChip({
    super.key,
    required this.denom,
    required this.chipStyle,
    this.size = 60,
    this.onTap,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final di = ChipStyles.denomIndex(denom);
    final base = Color(ChipStyles.colors[chipStyle][di]);
    final spot = Color(ChipStyles.spots[chipStyle][di]);
    final chip = Opacity(
      opacity: dimmed ? 0.4 : 1.0,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.25, -0.3),
            radius: 1.1,
            colors: [
              Color.lerp(base, Colors.white, 0.22)!,
              base,
              Color.lerp(base, Colors.black, 0.35)!,
            ],
          ),
          border: Border.all(color: Colors.white70, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              offset: const Offset(0, 4),
              blurRadius: 7,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: _ChipSpotsPainter(spot: spot),
            ),
            Container(
              width: size * 0.62,
              height: size * 0.62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.18),
                border: Border.all(color: Colors.white54, width: 1.5),
              ),
              child: Center(
                child: Text(
                  '$denom',
                  style: TextStyle(
                    fontSize: size * 0.26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: const [
                      Shadow(
                          color: Colors.black54,
                          offset: Offset(0, 1),
                          blurRadius: 2)
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return chip;
    return GestureDetector(onTap: onTap, child: chip);
  }
}

class _ChipSpotsPainter extends CustomPainter {
  final Color spot;
  const _ChipSpotsPainter({required this.spot});

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final paint = Paint()..color = spot;
    for (var i = 0; i < 8; i++) {
      final a = i * 3.14159 / 4;
      final inner = r * 0.78;
      final outer = r * 0.97;
      canvas.drawPath(
          Path()
            ..moveTo(r + inner * cos(a + 0.14), r + inner * sin(a + 0.14))
            ..lineTo(r + outer * cos(a + 0.14), r + outer * sin(a + 0.14))
            ..lineTo(r + outer * cos(a - 0.14), r + outer * sin(a - 0.14))
            ..lineTo(r + inner * cos(a - 0.14), r + inner * sin(a - 0.14))
            ..close(),
          paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChipSpotsPainter old) => old.spot != spot;
}
