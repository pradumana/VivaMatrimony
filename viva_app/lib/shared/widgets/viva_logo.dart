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
/// Renders the app logo image at [size] diameter.
/// [showWordmark] and [showTagline] are unused (the logo image already
/// contains the wordmark) but kept so all callers compile without changes.
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
    return Image.asset(
      'assets/images/app_icon.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
