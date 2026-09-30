import 'package:flutter/material.dart';

/// Colour helpers for user-chosen category colours.
///
/// Category colours are stored as opaque ARGB values chosen in light mode
/// (e.g. TikTok is near-black). Rendered as-is they disappear on a dark
/// surface, so they are lightened for dark mode and given a readable
/// on-colour for filled backgrounds.
class CategoryColors {
  const CategoryColors._();

  /// A version of [raw] that stays legible on the current [brightness].
  static Color readable(Color raw, Brightness brightness) {
    if (brightness == Brightness.light) return raw;

    final hsl = HSLColor.fromColor(raw);
    // Very dark brand colours (TikTok, X) need a big lift; mid-tone ones
    // only need a small one, so brightness is scaled by how dark it is.
    final lightnessBoost = (0.62 - hsl.lightness).clamp(0.0, 0.45);
    return hsl
        .withLightness((hsl.lightness + lightnessBoost).clamp(0.0, 1.0))
        .withSaturation(hsl.saturation.clamp(0.35, 1.0))
        .toColor();
  }

  /// Foreground colour that reads well on top of [background].
  static Color onColor(Color background) =>
      background.computeLuminance() > 0.55 ? Colors.black87 : Colors.white;

  /// A subtle background tint derived from [raw].
  static Color surface(Color raw, Brightness brightness) {
    final base = readable(raw, brightness);
    return base.withValues(
      alpha: brightness == Brightness.dark ? 0.22 : 0.12,
    );
  }
}
