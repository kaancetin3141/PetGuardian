import 'package:flutter/material.dart';

/// A network image that degrades instead of throwing.
///
/// `Image.network('')` throws an assertion error at runtime, and a missing or
/// unreachable URL renders as a red error box. Every call site in this app reads
/// its URL straight out of Firestore, so the URL can legitimately be absent.
class AppNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final double? height;
  final double? width;
  final IconData placeholderIcon;

  const AppNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.height,
    this.width,
    this.placeholderIcon = Icons.pets,
  });

  @override
  Widget build(BuildContext context) {
    final hasUrl = url.isNotEmpty && (url.startsWith('http') || url.startsWith('assets/'));

    if (!hasUrl) {
      return _placeholder(context);
    }

    return Image.network(
      url,
      fit: fit,
      height: height,
      width: width,
      errorBuilder: (context, error, stackTrace) => _placeholder(context),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _placeholder(context, showSpinner: true);
      },
    );
  }

  Widget _placeholder(BuildContext context, {bool showSpinner = false}) {
    // Theme-aware: adapts to dark mode instead of hardcoding light greys.
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: height,
      width: width,
      color: colors.surfaceContainerHighest,
      alignment: Alignment.center,
      child: showSpinner
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(placeholderIcon, color: colors.onSurfaceVariant),
    );
  }
}