import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// A skeleton loading placeholder widget using the shimmer package.
///
/// Usage:
///   HobifiShimmer(width: 200, height: 100)
///   HobifiShimmer.card()
///   HobifiShimmer.listTile()
///   HobifiShimmer.box(120, 80, radius: 8)
class HobifiShimmer extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const HobifiShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  /// Full activity card skeleton: image rectangle + three text lines.
  static Widget card() {
    return _ShimmerWrap(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image placeholder
          _ShimmerBox(width: double.infinity, height: 180, radius: 12),
          const SizedBox(height: 12),
          // Title line
          _ShimmerBox(width: 200, height: 16, radius: 4),
          const SizedBox(height: 8),
          // Subtitle line
          _ShimmerBox(width: 140, height: 12, radius: 4),
          const SizedBox(height: 6),
          // Detail line
          _ShimmerBox(width: 100, height: 12, radius: 4),
        ],
      ),
    );
  }

  /// Horizontal list tile skeleton: thumbnail + two text lines.
  static Widget listTile() {
    return _ShimmerWrap(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Thumbnail placeholder
          _ShimmerBox(width: 64, height: 64, radius: 8),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title line
                _ShimmerBox(width: double.infinity, height: 14, radius: 4),
                const SizedBox(height: 8),
                // Subtitle line
                _ShimmerBox(width: 120, height: 12, radius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Arbitrary rectangle skeleton with optional corner radius.
  static Widget box(double width, double height, {double radius = 8}) {
    return _ShimmerWrap(
      child: _ShimmerBox(width: width, height: height, radius: radius),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrap(
      child: _ShimmerBox(width: width, height: height, radius: borderRadius),
    );
  }
}

/// Wraps its child in a [Shimmer] widget, adapting colors for light/dark mode.
class _ShimmerWrap extends StatelessWidget {
  final Widget child;

  const _ShimmerWrap({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1E1E2A) : const Color(0xFFE8E8E8);
    final highlightColor =
        isDark ? const Color(0xFF2A2A3A) : const Color(0xFFF5F5F5);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: child,
    );
  }
}

/// A plain colored rectangle used as the shimmer child.
/// Must be an opaque widget so the shimmer gradient shows correctly.
class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
