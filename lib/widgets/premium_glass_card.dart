import 'dart:ui';
import 'package:flutter/material.dart';

class PremiumGlassCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double borderRadius;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final List<BoxShadow>? boxShadow;

  const PremiumGlassCard({
    super.key,
    required this.child,
    this.blur = 15.0,
    this.borderRadius = 20.0,
    this.color,
    this.borderColor,
    this.borderWidth = 1.2,
    this.padding,
    this.margin,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Glass effect: slight opacity variation by brightness
    final isDark = theme.brightness == Brightness.dark;
    final fallbackColor = color ?? theme.cardColor.withValues(alpha: isDark ? 0.65 : 0.75);

    final fallbackBorderColor = borderColor ?? theme.dividerColor;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: boxShadow ?? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: fallbackColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: fallbackBorderColor,
                width: borderWidth,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
