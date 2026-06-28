import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';

/// Draws the tactical reticle overlay on the camera preview —
/// corner brackets, crosshair, and subtle grid lines.
class TacticalOverlay extends StatelessWidget {
  const TacticalOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TacticalPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _TacticalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final bracketSize = min(size.width, size.height) * 0.35;
    final armLen = bracketSize * 0.35;

    // ── Corner brackets ──
    final bracketPaint = Paint()
      ..color = HaloColors.primary.withValues(alpha: 0.7)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(
      Offset(cx - bracketSize, cy - bracketSize),
      Offset(cx - bracketSize + armLen, cy - bracketSize),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(cx - bracketSize, cy - bracketSize),
      Offset(cx - bracketSize, cy - bracketSize + armLen),
      bracketPaint,
    );

    // Top-right
    canvas.drawLine(
      Offset(cx + bracketSize, cy - bracketSize),
      Offset(cx + bracketSize - armLen, cy - bracketSize),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(cx + bracketSize, cy - bracketSize),
      Offset(cx + bracketSize, cy - bracketSize + armLen),
      bracketPaint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(cx - bracketSize, cy + bracketSize),
      Offset(cx - bracketSize + armLen, cy + bracketSize),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(cx - bracketSize, cy + bracketSize),
      Offset(cx - bracketSize, cy + bracketSize - armLen),
      bracketPaint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(cx + bracketSize, cy + bracketSize),
      Offset(cx + bracketSize - armLen, cy + bracketSize),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(cx + bracketSize, cy + bracketSize),
      Offset(cx + bracketSize, cy + bracketSize - armLen),
      bracketPaint,
    );

    // ── Crosshair ──
    final crossPaint = Paint()
      ..color = HaloColors.primary.withValues(alpha: 0.25)
      ..strokeWidth = 0.5;

    final crossLen = bracketSize * 0.25;
    canvas.drawLine(Offset(cx - crossLen, cy), Offset(cx + crossLen, cy), crossPaint);
    canvas.drawLine(Offset(cx, cy - crossLen), Offset(cx, cy + crossLen), crossPaint);

    // ── Center dot ──
    final dotPaint = Paint()
      ..color = HaloColors.primary.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 3, dotPaint);

    // ── Subtle grid lines (inside brackets) ──
    final gridPaint = Paint()
      ..color = HaloColors.primary.withValues(alpha: 0.06)
      ..strokeWidth = 0.5;

    // Horizontal thirds
    for (var i = 1; i <= 2; i++) {
      final y = cy - bracketSize + (bracketSize * 2 * i / 3);
      canvas.drawLine(Offset(cx - bracketSize, y), Offset(cx + bracketSize, y), gridPaint);
    }
    // Vertical thirds
    for (var i = 1; i <= 2; i++) {
      final x = cx - bracketSize + (bracketSize * 2 * i / 3);
      canvas.drawLine(Offset(x, cy - bracketSize), Offset(x, cy + bracketSize), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Animated scanline that sweeps across a container.
class ScanlineOverlay extends StatefulWidget {
  final double opacity;
  const ScanlineOverlay({super.key, this.opacity = 0.08});

  @override
  State<ScanlineOverlay> createState() => _ScanlineOverlayState();
}

class _ScanlineOverlayState extends State<ScanlineOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ScanlinePainter(_controller.value, widget.opacity),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  final double progress;
  final double opacity;
  _ScanlinePainter(this.progress, this.opacity);

  @override
  void paint(Canvas canvas, Size size) {
    // Sweeping highlight line
    final y = progress * size.height;
    final highlightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          HaloColors.primary.withValues(alpha: 0),
          HaloColors.primary.withValues(alpha: opacity * 2),
          HaloColors.primary.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(0, y - 1, size.width, 2));
    canvas.drawRect(Rect.fromLTWH(0, y - 1, size.width, 2), highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
