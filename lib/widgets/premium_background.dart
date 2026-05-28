import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pos_provider.dart';

class PremiumBackground extends StatefulWidget {
  final Widget child;
  const PremiumBackground({super.key, required this.child});

  @override
  State<PremiumBackground> createState() => _PremiumBackgroundState();
}

class _PremiumBackgroundState extends State<PremiumBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<POSProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (provider.optimizePerformance) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      return Stack(
        children: [
          CustomPaint(
            painter: _BackgroundPainter(
              progress: 0.0,
              isDark: isDark,
              staticOnly: true,
            ),
            child: Container(),
          ),
          widget.child,
        ],
      );
    } else {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
      return Stack(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: _BackgroundPainter(
                  progress: _controller.value,
                  isDark: isDark,
                  staticOnly: false,
                ),
                child: Container(),
              );
            },
          ),
          widget.child,
        ],
      );
    }
  }
}

class _BackgroundPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final bool staticOnly;

  _BackgroundPainter({required this.progress, required this.isDark, required this.staticOnly});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // 1. Draw base background gradient
    final bgGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [const Color(0xFF000000), const Color(0xFF000000)]
          : [const Color(0xFFFFFFFF), const Color(0xFFFFFFFF)],
    );
    paint.shader = bgGradient.createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);

    // Subtle neon orbs
    final double opacity = isDark ? 0.15 : 0.05; // Slightly more subtle for clean look
    final angle = staticOnly ? 0.0 : progress * 2 * math.pi;

    // Orb 1: Cyber Indigo
    final orb1Center = Offset(
      size.width * 0.25 + math.sin(angle) * (size.width * 0.15),
      size.height * 0.3 + math.cos(angle) * (size.height * 0.1),
    );
    _drawGlowingOrb(
      canvas,
      orb1Center,
      size.width * (isDark ? 0.45 : 0.35),
      isDark ? const Color(0xFF6366F1) : const Color(0xFF818CF8),
      opacity,
    );

    // Orb 2: Deep Blue
    final orb2Center = Offset(
      size.width * 0.75 + math.cos(angle + math.pi / 2) * (size.width * 0.12),
      size.height * 0.7 + math.sin(angle + math.pi / 2) * (size.height * 0.15),
    );
    _drawGlowingOrb(
      canvas,
      orb2Center,
      size.width * (isDark ? 0.5 : 0.4),
      isDark ? const Color(0xFF3B82F6) : const Color(0xFF93C5FD),
      opacity,
    );

    // Orb 3: Royal Violet
    final orb3Center = Offset(
      size.width * 0.5 + math.sin(angle + math.pi) * (size.width * 0.1),
      size.height * 0.55 + math.cos(angle + math.pi) * (size.height * 0.08),
    );
    _drawGlowingOrb(
      canvas,
      orb3Center,
      size.width * (isDark ? 0.35 : 0.25),
      isDark ? const Color(0xFF8B5CF6) : const Color(0xFFC7D2FE),
      opacity * 0.6,
    );
  }

  void _drawGlowingOrb(Canvas canvas, Offset center, double radius, Color color, double maxOpacity) {
    if (radius <= 0) return;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: maxOpacity),
          color.withValues(alpha: maxOpacity * 0.4),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark || oldDelegate.staticOnly != staticOnly;
  }
}
