import 'package:flutter/material.dart';

/// Variant of the Viva logo — kept for API compatibility with all callers.
enum VivaLogoVariant {
  /// Use on light / white backgrounds.
  gradient,

  /// Use on dark / gradient backgrounds.
  white,
}

/// Viva brand logo widget.
///
/// Renders the app logo image clipped to a circle at [size] diameter.
/// [variant] is accepted but currently unused — the single PNG asset works
/// on both light and dark backgrounds because call sites already control
/// the surrounding container colour.
/// [showWordmark] and [showTagline] are kept for API compatibility.
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
    return ClipOval(
      child: Image.asset(
        'assets/images/app_icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
