import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Variant of the Viva logo.
enum VivaLogoVariant {
  /// Deep maroon → red gradient mark with white letterform.
  /// Use on **light / white** backgrounds (login, app bar).
  gradient,

  /// Fully white mark (outline + letterform).
  /// Use on **dark / gradient** backgrounds (splash, welcome).
  white,
}

/// Viva brand logo widget.
///
/// Renders a circular mark containing a custom "V" constructed from
/// two diagonal strokes that form a heart-like downward chevron,
/// with a subtle decorative arc above — evoking a mangalsutra pendant.
///
/// [size]    — diameter of the circular mark.
/// [variant] — [VivaLogoVariant.gradient] (default) or [VivaLogoVariant.white].
/// [showWordmark] — if true, renders the "Viva" text below the mark.
/// [showTagline]  — if true (and [showWordmark] is true), also renders the tagline.
class VivaLogo extends StatelessWidget {
  const VivaLogo({
    super.key,
    this.size = 72,
    this.variant = VivaLogoVariant.gradient,
    this.showWordmark = false,
    this.showTagline = false,
  });

  final double size;
  final VivaLogoVariant variant;
  final bool showWordmark;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final mark = CustomPaint(
      size: Size(size, size),
      painter: _VivaMarkPainter(variant: variant),
    );

    if (!showWordmark) return mark;

    final isLight = variant == VivaLogoVariant.gradient;
    final wordmarkColor =
        isLight ? AppTheme.textPrimary : Colors.white;
    final taglineColor = isLight
        ? AppTheme.textSecondary
        : Colors.white.withOpacity(0.85);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(height: size * 0.22),
        Text(
          'Viva',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: size * 0.56,
            fontWeight: FontWeight.w700,
            color: wordmarkColor,
            letterSpacing: size * 0.04,
          ),
        ),
        if (showTagline) ...[
          SizedBox(height: size * 0.08),
          Text(
            'Find someone who feels like home.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: size * 0.19,
              color: taglineColor,
              fontStyle: FontStyle.italic,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Painter ──────────────────────────────────────────────────────────────────

class _VivaMarkPainter extends CustomPainter {
  const _VivaMarkPainter({required this.variant});

  final VivaLogoVariant variant;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    final bool isGradient = variant == VivaLogoVariant.gradient;

    // ── 1. Circle background ─────────────────────────────────────────────────
    final bgPaint = Paint()..style = PaintingStyle.fill;
    if (isGradient) {
      bgPaint.shader = LinearGradient(
        colors: [AppTheme.primaryDeep, AppTheme.primary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    } else {
      bgPaint.color = Colors.white.withOpacity(0.18);
    }
    canvas.drawCircle(Offset(cx, cy), r, bgPaint);

    // ── 2. Circle border ─────────────────────────────────────────────────────
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.025
      ..color = isGradient
          ? Colors.white.withOpacity(0.35)
          : Colors.white.withOpacity(0.55);
    canvas.drawCircle(Offset(cx, cy), r - size.width * 0.013, borderPaint);

    // ── 3. "V" mark ──────────────────────────────────────────────────────────
    //
    // The mark is two bold strokes descending from the upper thirds to a
    // pointed bottom-centre, like a pendant/chevron.  A small arc sits above
    // them (decorative mangalsutra-bead motif).
    //
    final markColor = Colors.white;
    final strokeW = size.width * 0.085;

    final markPaint = Paint()
      ..color = markColor
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Define key points relative to the circle
    final topY = cy - r * 0.28;
    final tipY = cy + r * 0.38;
    final leftX = cx - r * 0.40;
    final rightX = cx + r * 0.40;

    final path = Path()
      ..moveTo(leftX, topY)
      ..lineTo(cx, tipY)
      ..lineTo(rightX, topY);

    canvas.drawPath(path, markPaint);

    // ── 4. Decorative arc (bead / top flourish) ──────────────────────────────
    // A small semicircle arc above the V, centred horizontally
    final arcPaint = Paint()
      ..color = markColor.withOpacity(0.70)
      ..strokeWidth = size.width * 0.045
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final arcRect = Rect.fromCenter(
      center: Offset(cx, topY - size.width * 0.055),
      width: size.width * 0.32,
      height: size.width * 0.22,
    );
    // Draw top semicircle (180° arc)
    canvas.drawArc(arcRect, math.pi, math.pi, false, arcPaint);

    // ── 5. Small centre dot at the tip ───────────────────────────────────────
    final dotPaint = Paint()
      ..color = markColor.withOpacity(0.90)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, tipY), size.width * 0.042, dotPaint);
  }

  @override
  bool shouldRepaint(_VivaMarkPainter old) => old.variant != variant;
}
