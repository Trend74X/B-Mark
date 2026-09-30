import 'package:flutter/material.dart';

/// Shows a bookmark's thumbnail when available, otherwise the app's own
/// artwork so every card still has a recognisable image.
class ThumbnailPreview extends StatelessWidget {
  const ThumbnailPreview({
    super.key,
    required this.url,
    this.thumbnailUrl,
    this.size = 56,
    this.borderRadius = 10,
  });

  final String url;
  final String? thumbnailUrl;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: _buildImage(context),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    final image = thumbnailUrl;
    if (image == null || image.isEmpty) {
      return _assetPlaceholder(showSpinner: false);
    }

    return Image.network(
      image,
      width: size,
      height: size,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => _assetPlaceholder(showSpinner: false),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _assetPlaceholder(showSpinner: true);
      },
    );
  }

  /// App's own artwork, used whenever there is no remote thumbnail.
  Widget _assetPlaceholder({required bool showSpinner}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/playstore.png',
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
        if (showSpinner)
          Center(
            child: SizedBox(
              width: size * 0.35,
              height: size * 0.35,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(
                  Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
