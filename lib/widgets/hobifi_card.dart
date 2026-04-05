import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hobby_haven/models/activity_model.dart';
import 'package:hobby_haven/widgets/hobifi_shimmer.dart';

/// A reusable activity card widget with two layout variants.
///
/// Use [HobifiCard] for the standard vertical-list card.
/// Use [HobifiCard.featured] for the compact horizontal-scroll card.
class HobifiCard extends StatelessWidget {
  final ActivityModel activity;
  final bool isLiked;
  final VoidCallback onTap;
  final VoidCallback onLikeTap;
  final bool featured;

  const HobifiCard({
    super.key,
    required this.activity,
    required this.isLiked,
    required this.onTap,
    required this.onLikeTap,
    this.featured = false,
  });

  /// Featured variant — compact card for horizontal scroll sections.
  const HobifiCard.featured({
    super.key,
    required this.activity,
    required this.isLiked,
    required this.onTap,
    required this.onLikeTap,
  }) : featured = true;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: featured
          ? _buildFeaturedCard(context)
          : _buildStandardCard(context),
    );
  }

  // ──────────────────────────────────────────────
  // Featured variant
  // ──────────────────────────────────────────────

  Widget _buildFeaturedCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SizedBox(
      width: 260,
      height: 340,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Hero image
            _HeroImage(imageUrl: activity.imageUrl),

            // Gradient scrim
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.4, 1.0],
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),

            // Like button — top-right
            Positioned(
              top: 12,
              right: 12,
              child: _LikeButton(isLiked: isLiked, onTap: onLikeTap),
            ),

            // Price badge — bottom-left (70px from bottom)
            Positioned(
              bottom: 70,
              left: 12,
              child: _PriceBadge(price: activity.price, colorScheme: cs),
            ),

            // Title + rating — very bottom
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    activity.title,
                    style: tt.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: cs.tertiary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        activity.rating.toStringAsFixed(1),
                        style: tt.bodySmall?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '(${activity.reviewCount})',
                        style: tt.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Standard variant
  // ──────────────────────────────────────────────

  Widget _buildStandardCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.3)
        : Colors.black.withValues(alpha: 0.06);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            offset: const Offset(0, 2),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image with overlays
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _HeroImage(imageUrl: activity.imageUrl),

                  // Like button — top-right
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _LikeButton(isLiked: isLiked, onTap: onLikeTap),
                  ),

                  // Price badge — bottom-left
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: _PriceBadge(price: activity.price, colorScheme: cs),
                  ),
                ],
              ),
            ),
          ),

          // Info section
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  activity.title,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Location
                Text(
                  activity.location,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Metadata row
                Row(
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: cs.tertiary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      activity.rating.toStringAsFixed(1),
                      style: tt.bodySmall,
                    ),
                    const SizedBox(width: 8),

                    // Category chip
                    _MetaChip(
                      label: activity.category,
                      backgroundColor: cs.primary.withValues(alpha: 0.08),
                      textColor: cs.primary,
                    ),

                    // Spots left pill — only when ≤5
                    if (activity.spotsLeft <= 5) ...[
                      const SizedBox(width: 6),
                      _MetaChip(
                        label: '${activity.spotsLeft} left',
                        backgroundColor:
                            const Color(0xFFE88B3C).withValues(alpha: 0.12),
                        textColor: const Color(0xFFE88B3C),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// _HeroImage
// ──────────────────────────────────────────────────────────────────────────────

class _HeroImage extends StatelessWidget {
  final String imageUrl;

  const _HeroImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final isEmpty =
        imageUrl.isEmpty || !imageUrl.startsWith('http');

    if (isEmpty) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
          child: Icon(Icons.image_outlined, size: 40, color: Colors.white54),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => HobifiShimmer.box(
        double.infinity,
        double.infinity,
        radius: 0,
      ),
      errorWidget: (context, url, error) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
          child: Icon(Icons.broken_image_outlined, size: 40, color: Colors.white54),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// _LikeButton
// ──────────────────────────────────────────────────────────────────────────────

class _LikeButton extends StatefulWidget {
  final bool isLiked;
  final VoidCallback onTap;

  const _LikeButton({required this.isLiked, required this.onTap});

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
  }

  @override
  void didUpdateWidget(_LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isLiked && widget.isLiked) {
      _controller.forward().then((_) => _controller.reverse());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Icon(
            widget.isLiked ? Icons.favorite : Icons.favorite_border,
            size: 18,
            color: widget.isLiked
                ? const Color(0xFFE53935)
                : Colors.grey,
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// _PriceBadge
// ──────────────────────────────────────────────────────────────────────────────

class _PriceBadge extends StatelessWidget {
  final double price;
  final ColorScheme colorScheme;

  const _PriceBadge({required this.price, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        'EGP ${price.toStringAsFixed(0)}',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// _MetaChip  (internal helper for category / spots-left pills)
// ──────────────────────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const _MetaChip({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
