# Frontend Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Overhaul all Hobifi frontend screens for a clean, social-media-inspired UI ready for Egypt launch.

**Architecture:** Shared widget library (`lib/widgets/`) consumed by all screens. Vertical card feed (Airbnb-style) for discovery, collapsing header for activity details, data-forward Stripe-style dashboard for business. All existing services, models, and routing remain unchanged — this is purely a UI layer rewrite.

**Tech Stack:** Flutter/Dart, Provider, GoRouter, CachedNetworkImage, fl_chart, shimmer (new), google_fonts, qr_flutter, intl

**Spec:** `docs/superpowers/specs/2026-04-05-frontend-overhaul-design.md`

---

## File Structure

### New files (shared widgets)
- `lib/widgets/hobifi_shimmer.dart` — Skeleton loading placeholder widget
- `lib/widgets/hobifi_empty_state.dart` — Consistent empty/error state widget
- `lib/widgets/hobifi_section_header.dart` — Section title + "See all" action
- `lib/widgets/hobifi_chip.dart` — Category filter chip (pill, filled/outlined)
- `lib/widgets/hobifi_card.dart` — Reusable activity card (hero image, overlays, info row)
- `lib/widgets/hobifi_stat_card.dart` — Dashboard stat card with trend badge

### Modified files (screens)
- `lib/screens/user/feed_screen.dart` — REWRITE using shared widgets
- `lib/screens/user/activity_details_screen.dart` — REWRITE with collapsing header
- `lib/screens/business/dashboard_screen.dart` — REWRITE with polished data viz
- `lib/screens/user/profile_screen.dart` — MODERATE EDIT (interest tags, settings polish)
- `lib/screens/user/bookings_screen.dart` — MODERATE EDIT (card redesign, filter chips)
- `lib/screens/user/saved_screen.dart` — MODERATE EDIT (use HobifiCard)
- `lib/screens/user/booking_confirm_screen.dart` — MODERATE EDIT (order summary polish)
- `lib/screens/user/payment_screen.dart` — LIGHT EDIT (shimmer loading)
- `lib/screens/user/ticket_screen.dart` — MODERATE EDIT (ticket tear effect, dark mode fix)
- `lib/screens/business/wallet_screen.dart` — MODERATE EDIT (EGP fix, balance card polish)
- `lib/screens/business/business_profile_screen.dart` — LIGHT EDIT (stats, consistency)
- `lib/screens/auth_screen.dart` — MODERATE EDIT (form polish, role toggle)
- `lib/screens/onboarding_screen.dart` — MODERATE EDIT (interest grid, progress dots)
- `lib/nav.dart` — LIGHT EDIT (bottom nav indicator polish)

---

## Task 1: Add shimmer dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add shimmer package to pubspec.yaml**

In `pubspec.yaml`, add `shimmer: ^3.0.0` under `dependencies`, after the `share_plus` line:

```yaml
  share_plus: ^12.0.1
  shimmer: ^3.0.0
```

- [ ] **Step 2: Install dependencies**

Run: `cd /Users/anis/Developer/Hobifi && flutter pub get`
Expected: "Got dependencies!" with no errors

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add shimmer package for skeleton loading"
```

---

## Task 2: Create HobifiShimmer widget

**Files:**
- Create: `lib/widgets/hobifi_shimmer.dart`

- [ ] **Step 1: Create the shimmer widget**

Create `lib/widgets/hobifi_shimmer.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Skeleton loading placeholder. Use instead of bare CircularProgressIndicator.
///
/// Usage:
///   HobifiShimmer.card()        — full activity card skeleton
///   HobifiShimmer.listTile()    — horizontal list tile skeleton
///   HobifiShimmer.box(w, h)     — arbitrary rectangle
class HobifiShimmer extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const HobifiShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 16,
  });

  /// A full activity card skeleton (image + text lines)
  static Widget card({double width = double.infinity, double imageHeight = 180}) {
    return _ShimmerWrap(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: width,
            height: imageHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 180,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 120,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }

  /// A horizontal list tile skeleton (thumbnail + text)
  static Widget listTile() {
    return _ShimmerWrap(
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 100,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 60,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// An arbitrary rectangle skeleton
  static Widget box(double width, double height, {double radius = 16}) {
    return _ShimmerWrap(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrap(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class _ShimmerWrap extends StatelessWidget {
  final Widget child;
  const _ShimmerWrap({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF1E1E2A) : const Color(0xFFE8E8E8),
      highlightColor: isDark ? const Color(0xFF2A2A3A) : const Color(0xFFF5F5F5),
      child: child,
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/anis/Developer/Hobifi && flutter analyze lib/widgets/hobifi_shimmer.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/hobifi_shimmer.dart
git commit -m "feat: add HobifiShimmer skeleton loading widget"
```

---

## Task 3: Create HobifiEmptyState widget

**Files:**
- Create: `lib/widgets/hobifi_empty_state.dart`

- [ ] **Step 1: Create the empty state widget**

Create `lib/widgets/hobifi_empty_state.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hobby_haven/theme.dart';

/// Consistent empty/error state used across all screens.
///
/// Usage:
///   HobifiEmptyState(
///     icon: Icons.explore_off_rounded,
///     title: 'No activities found',
///     subtitle: 'Check back later',
///     actionLabel: 'Explore',   // optional CTA
///     onAction: () => ...,      // optional CTA callback
///   )
class HobifiEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const HobifiEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 40, color: colorScheme.primary.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/anis/Developer/Hobifi && flutter analyze lib/widgets/hobifi_empty_state.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/hobifi_empty_state.dart
git commit -m "feat: add HobifiEmptyState widget for consistent empty states"
```

---

## Task 4: Create HobifiSectionHeader widget

**Files:**
- Create: `lib/widgets/hobifi_section_header.dart`

- [ ] **Step 1: Create the section header widget**

Create `lib/widgets/hobifi_section_header.dart`:

```dart
import 'package:flutter/material.dart';

/// Section header with title and optional "See all" action.
///
/// Usage:
///   HobifiSectionHeader(
///     title: 'Trending Near You',
///     onSeeAll: () => ...,  // optional
///   )
class HobifiSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;

  const HobifiSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'See all',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/anis/Developer/Hobifi && flutter analyze lib/widgets/hobifi_section_header.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/hobifi_section_header.dart
git commit -m "feat: add HobifiSectionHeader widget"
```

---

## Task 5: Create HobifiChip widget

**Files:**
- Create: `lib/widgets/hobifi_chip.dart`

- [ ] **Step 1: Create the chip widget**

Create `lib/widgets/hobifi_chip.dart`:

```dart
import 'package:flutter/material.dart';

/// Category filter chip — pill shape.
/// Selected: filled indigo + white text/icon.
/// Unselected: surface color + muted text/icon + subtle outline.
///
/// Usage:
///   HobifiChip(
///     label: 'Art',
///     icon: Icons.palette_rounded,
///     isSelected: true,
///     onTap: () => ...,
///   )
class HobifiChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const HobifiChip({
    super.key,
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary : colorScheme.surface,
            borderRadius: BorderRadius.circular(9999),
            border: isSelected
                ? null
                : Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/anis/Developer/Hobifi && flutter analyze lib/widgets/hobifi_chip.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/hobifi_chip.dart
git commit -m "feat: add HobifiChip filter chip widget"
```

---

## Task 6: Create HobifiCard widget

**Files:**
- Create: `lib/widgets/hobifi_card.dart`

This is the most important shared widget — used by feed, saved, and search results.

- [ ] **Step 1: Create the card widget**

Create `lib/widgets/hobifi_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hobby_haven/models/activity_model.dart';
import 'package:hobby_haven/widgets/hobifi_shimmer.dart';

/// Reusable activity card with hero image, overlay badges, like button, info row.
///
/// Two variants:
///   HobifiCard.featured(...)   — large card for horizontal scroll (3:4 aspect)
///   HobifiCard(...)            — standard vertical card (16:9 image + info below)
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

  const HobifiCard.featured({
    super.key,
    required this.activity,
    required this.isLiked,
    required this.onTap,
    required this.onLikeTap,
  }) : featured = true;

  @override
  Widget build(BuildContext context) {
    return featured ? _buildFeaturedCard(context) : _buildStandardCard(context);
  }

  /// Large card for horizontal scroll sections (3:4 aspect, ~260w x 340h)
  Widget _buildFeaturedCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
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
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
              ),
              // Like button
              Positioned(
                top: 12,
                right: 12,
                child: _LikeButton(isLiked: isLiked, onTap: onLikeTap),
              ),
              // Price badge
              Positioned(
                bottom: 70,
                left: 12,
                child: _PriceBadge(price: activity.price, colorScheme: colorScheme),
              ),
              // Bottom info
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, size: 14, color: colorScheme.tertiary),
                        const SizedBox(width: 3),
                        Text(
                          activity.rating.toStringAsFixed(1),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (activity.reviewCount > 0) ...[
                          Text(
                            ' (${activity.reviewCount})',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Standard vertical card — 16:9 image top, info below
  Widget _buildStandardCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.3 : 0.06,
              ),
              offset: const Offset(0, 2),
              blurRadius: 12,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _HeroImage(imageUrl: activity.imageUrl),
                    // Like button
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _LikeButton(isLiked: isLiked, onTap: onLikeTap),
                    ),
                    // Price badge
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: _PriceBadge(price: activity.price, colorScheme: colorScheme),
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
                  Text(
                    activity.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    activity.location,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Metadata row
                  Row(
                    children: [
                      Icon(Icons.star_rounded, size: 14, color: colorScheme.tertiary),
                      const SizedBox(width: 3),
                      Text(
                        activity.rating.toStringAsFixed(1),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          activity.category,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (activity.spotsLeft <= 5 && activity.spotsLeft > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE88B3C).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: Text(
                            '${activity.spotsLeft} spots left',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFFE88B3C),
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
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
}

/// Cached hero image with shimmer placeholder
class _HeroImage extends StatelessWidget {
  final String imageUrl;
  const _HeroImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty || !imageUrl.startsWith('http')) {
      return Container(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        child: Icon(
          Icons.image_rounded,
          size: 48,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => HobifiShimmer.box(double.infinity, double.infinity, radius: 0),
      errorWidget: (_, __, ___) => Container(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        child: Icon(
          Icons.broken_image_rounded,
          size: 48,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

/// Animated like button with scale + haptic feedback
class _LikeButton extends StatefulWidget {
  final bool isLiked;
  final VoidCallback onTap;
  const _LikeButton({required this.isLiked, required this.onTap});

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

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
  void didUpdateWidget(covariant _LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLiked && !oldWidget.isLiked) {
      _controller.forward().then((_) => _controller.reverse());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
              ),
            ],
          ),
          child: Icon(
            widget.isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
            size: 18,
            color: widget.isLiked ? const Color(0xFFE53935) : Colors.grey[600],
          ),
        ),
      ),
    );
  }
}

/// Price badge overlay
class _PriceBadge extends StatelessWidget {
  final double price;
  final ColorScheme colorScheme;
  const _PriceBadge({required this.price, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/anis/Developer/Hobifi && flutter analyze lib/widgets/hobifi_card.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/hobifi_card.dart
git commit -m "feat: add HobifiCard reusable activity card widget"
```

---

## Task 7: Create HobifiStatCard widget

**Files:**
- Create: `lib/widgets/hobifi_stat_card.dart`

- [ ] **Step 1: Create the stat card widget**

Create `lib/widgets/hobifi_stat_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hobby_haven/theme.dart';

/// Dashboard stat card with value, label, optional trend badge, left-edge gradient accent.
///
/// Usage:
///   HobifiStatCard(
///     label: 'Total Revenue',
///     value: 'EGP 12,500',
///     trend: '+12%',
///     trendPositive: true,
///     icon: Icons.payments_rounded,
///   )
class HobifiStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? trend;
  final bool trendPositive;
  final IconData icon;

  const HobifiStatCard({
    super.key,
    required this.label,
    required this.value,
    this.trend,
    this.trendPositive = true,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          // Left accent strip
          Container(
            width: 4,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [const Color(0xFF4A47B8), const Color(0xFF6C68D4)]
                    : [AppColors.indigo, const Color(0xFF3A37A0)],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: colorScheme.primary.withValues(alpha: 0.6)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                if (trend != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (trendPositive ? AppColors.lime : AppColors.likeRed)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Text(
                      trend!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: trendPositive ? AppColors.lime : AppColors.likeRed,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/anis/Developer/Hobifi && flutter analyze lib/widgets/hobifi_stat_card.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/hobifi_stat_card.dart
git commit -m "feat: add HobifiStatCard dashboard stat widget"
```

---

## Task 8: Rewrite Feed Screen

**Files:**
- Rewrite: `lib/screens/user/feed_screen.dart`

This is the largest task. The feed screen gets a full rewrite using the new shared widgets. It keeps the existing business logic (search, categories, pagination, rating prompt) but replaces all inline widget classes with the shared library.

- [ ] **Step 1: Rewrite feed_screen.dart**

Rewrite `lib/screens/user/feed_screen.dart`. The file is large (~520 lines currently). The rewrite should:

1. **Keep all existing imports** plus add the new widget imports:
   ```dart
   import 'package:hobby_haven/widgets/hobifi_card.dart';
   import 'package:hobby_haven/widgets/hobifi_chip.dart';
   import 'package:hobby_haven/widgets/hobifi_shimmer.dart';
   import 'package:hobby_haven/widgets/hobifi_section_header.dart';
   import 'package:hobby_haven/widgets/hobifi_empty_state.dart';
   ```

2. **Keep all state logic unchanged:**
   - `_selectedCategory`, `_searchQuery`, `_searchResults`, `_isSearching`, `_debounce`
   - `_searchController`, `_scrollController`
   - `_checkUnratedBookings()`, `_showRatingPrompt()`, `_onSearchChanged()`, `_selectCategory()`, `_onScroll()`

3. **Replace the build method and all private widget classes:**
   - Delete: `_MinimalHeader`, `_MinimalSearchBar`, `_CategoryChip`, `_SectionHeader`, `_FeaturedExperienceCard`, `_CompactExperienceCard`, `_MediumExperienceCard`, `_EmptyState`
   - Replace `_CategoryChip` usage with `HobifiChip`
   - Replace `_SectionHeader` usage with `HobifiSectionHeader`
   - Replace `_EmptyState` usage with `HobifiEmptyState`
   - Replace `_FeaturedExperienceCard` usage with `HobifiCard.featured()`
   - Replace `_CompactExperienceCard` usage with `HobifiCard()`
   - Replace loading spinners with `HobifiShimmer.card()`

4. **Header** — keep the `_MinimalHeader` inline (it's screen-specific with HOBIFI branding + avatar). Clean up spacing.

5. **Category chips** — replace `_CategoryChip` with `HobifiChip`:
   ```dart
   HobifiChip(
     label: 'All',
     icon: Icons.apps_rounded,
     isSelected: _selectedCategory == 'All',
     onTap: () => _selectCategory('All'),
   ),
   ```

6. **Discovery sections** — use `HobifiSectionHeader` + `HobifiCard`:
   - "Trending Near You" section with `HobifiCard.featured()` in horizontal scroll
   - "Upcoming This Week" section with `HobifiCard()` in vertical list
   - "New Activities" section with `HobifiCard()` in vertical list

7. **Wire like button** — each `HobifiCard` gets:
   ```dart
   HobifiCard(
     activity: activity,
     isLiked: likeService.isLiked(activity.id),
     onTap: () => context.push('${AppRoutes.activity}/${activity.id}'),
     onLikeTap: () {
       final userId = auth.currentUser?.id;
       if (userId != null) likeService.toggleLike(userId, activity.id);
     },
   )
   ```

8. **Shimmer loading** — replace the pagination `CircularProgressIndicator` with:
   ```dart
   SliverToBoxAdapter(
     child: Padding(
       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
       child: HobifiShimmer.card(),
     ),
   ),
   ```

9. **Pull-to-refresh** — wrap the `CustomScrollView` body content. Add `RefreshIndicator` wrapping the scroll view:
   ```dart
   RefreshIndicator(
     onRefresh: () => context.read<ActivityService>().loadActivities(),
     child: CustomScrollView(...)
   )
   ```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/anis/Developer/Hobifi && flutter analyze lib/screens/user/feed_screen.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/screens/user/feed_screen.dart
git commit -m "feat: rewrite feed screen with shared widgets and polished UI"
```

---

## Task 9: Rewrite Activity Details Screen

**Files:**
- Rewrite: `lib/screens/user/activity_details_screen.dart`

- [ ] **Step 1: Rewrite activity_details_screen.dart**

The rewrite implements the collapsing header pattern:

1. **SliverAppBar** with `expandedHeight: MediaQuery.of(context).size.height * 0.4`, `flexibleSpace` containing the hero image, gradient scrim, and floating action buttons (back, share, like).

2. **Collapsed state:** `title: Text(activity.title)` appears when scrolled.

3. **Body sections** as `SliverList` children:
   - Title + rating row
   - Quick info pills (date, time, location, category) — use `Wrap` of small chips
   - Description with expandable text (use a `_isExpanded` bool, show 3 lines by default, "Read more" toggles)
   - Host card (avatar + name + "Hosted by")
   - Reviews section (star breakdown bars + review cards)

4. **Sticky bottom bar** — use `Scaffold.bottomNavigationBar` with a `Container`:
   ```dart
   bottomNavigationBar: Container(
     padding: const EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
     decoration: BoxDecoration(
       color: colorScheme.surface,
       boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), offset: const Offset(0, -2), blurRadius: 8)],
     ),
     child: Row(
       children: [
         Column(
           mainAxisSize: MainAxisSize.min,
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Text('EGP ${activity.price.toStringAsFixed(0)}', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: colorScheme.onSurface)),
             Text('per person', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.5))),
           ],
         ),
         const Spacer(),
         FilledButton(
           onPressed: () => context.push('${AppRoutes.bookingConfirm}/${activity.id}'),
           style: FilledButton.styleFrom(
             backgroundColor: colorScheme.primary,
             padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
           ),
           child: const Text('Book Now'),
         ),
       ],
     ),
   ),
   ```

5. **Back button** — use `AppBackButton` from `lib/widgets/app_back_button.dart` with theme-aware colors, or a simple circular icon button:
   ```dart
   Positioned(
     top: MediaQuery.of(context).padding.top + 8,
     left: 16,
     child: GestureDetector(
       onTap: () => context.pop(),
       child: Container(
         width: 40, height: 40,
         decoration: BoxDecoration(
           color: Colors.white.withValues(alpha: 0.9),
           shape: BoxShape.circle,
           boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
         ),
         child: const Icon(Icons.arrow_back_rounded, size: 20),
       ),
     ),
   ),
   ```

6. **Share + like buttons** top-right, same floating circular style.

7. **Reviews section:**
   - Star breakdown with 5 rows: `Row(children: [Text('5'), LinearProgressIndicator(value: percent), Text(count)])`
   - Individual review cards: avatar, name, star row, text, date

8. **Keep existing data fetching logic** from `ActivityService` and `RatingService`.

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/anis/Developer/Hobifi && flutter analyze lib/screens/user/activity_details_screen.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/screens/user/activity_details_screen.dart
git commit -m "feat: rewrite activity details with collapsing header and sticky book bar"
```

---

## Task 10: Rewrite Business Dashboard Screen

**Files:**
- Rewrite: `lib/screens/business/dashboard_screen.dart`

- [ ] **Step 1: Rewrite dashboard_screen.dart**

The rewrite polishes the existing dashboard with:

1. **Keep all existing data fetching logic:** `_fetchStats`, `_fetchRevenueChart`, `_fetchPerActivityStats`, `_fetchEarningsHistory`, `_selectedDays`, all Future caching.

2. **Header:** Replace with greeting-style header:
   ```dart
   Padding(
     padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
     child: Row(
       children: [
         Expanded(
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text(_greeting(), style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.5))),
               const SizedBox(height: 4),
               Text(user?.name ?? 'Dashboard', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
             ],
           ),
         ),
         // Avatar
       ],
     ),
   ),
   ```

   Add a `_greeting()` helper:
   ```dart
   String _greeting() {
     final hour = DateTime.now().hour;
     if (hour < 12) return 'Good morning';
     if (hour < 17) return 'Good afternoon';
     return 'Good evening';
   }
   ```

3. **Stat cards:** Replace with horizontal scroll of `HobifiStatCard`:
   ```dart
   import 'package:hobby_haven/widgets/hobifi_stat_card.dart';
   ```
   Three cards: Total Revenue, Total Bookings, Active Activities.

4. **Revenue chart:** Polish the existing `fl_chart` `LineChart`:
   - Gradient fill under the line: `belowBarData: BarAreaData(show: true, gradient: LinearGradient(...))`
   - Smooth bezier curves: `isCurved: true`
   - Period selector chips using `HobifiChip`:
     ```dart
     import 'package:hobby_haven/widgets/hobifi_chip.dart';
     ```

5. **Per-activity breakdown:** Cards with title, bookings, revenue, fill rate bar.

6. **Recent earnings:** Clean list tiles with status badges:
   - completed → lime
   - pending → orange  
   - refunded → red

7. **Pull-to-refresh:** Wrap with `RefreshIndicator`.

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/anis/Developer/Hobifi && flutter analyze lib/screens/business/dashboard_screen.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/screens/business/dashboard_screen.dart
git commit -m "feat: rewrite business dashboard with polished stats and chart"
```

---

## Task 11: Polish Bookings Screen

**Files:**
- Modify: `lib/screens/user/bookings_screen.dart`

- [ ] **Step 1: Update bookings_screen.dart**

1. **Replace filter buttons** with `HobifiChip`:
   ```dart
   import 'package:hobby_haven/widgets/hobifi_chip.dart';
   import 'package:hobby_haven/widgets/hobifi_empty_state.dart';
   import 'package:hobby_haven/widgets/hobifi_shimmer.dart';
   import 'package:cached_network_image/cached_network_image.dart';
   ```

2. **Filter chips row** — replace raw buttons with:
   ```dart
   Row(
     children: [
       HobifiChip(label: 'Upcoming', isSelected: _selectedFilter == 'Upcoming', onTap: () => setState(() => _selectedFilter = 'Upcoming')),
       HobifiChip(label: 'Completed', isSelected: _selectedFilter == 'Completed', onTap: () => setState(() => _selectedFilter = 'Completed')),
       HobifiChip(label: 'Cancelled', isSelected: _selectedFilter == 'Cancelled', onTap: () => setState(() => _selectedFilter = 'Cancelled')),
     ],
   ),
   ```

3. **Booking card redesign** — each card uses horizontal layout:
   - Left: 80x80 rounded image thumbnail (`CachedNetworkImage` with `HobifiShimmer.box` placeholder)
   - Center: title, date/time (formatted with `intl`), location
   - Right: status badge (colored pill)

   Status badge colors:
   ```dart
   Color _statusColor(BookingStatus status) {
     return switch (status) {
       BookingStatus.confirmed => AppColors.lime,
       BookingStatus.pending => AppColors.orange,
       BookingStatus.cancelled => AppColors.likeRed,
       BookingStatus.completed => AppColors.lightSecondaryText,
     };
   }
   ```

4. **Empty state** — replace inline empty with:
   ```dart
   HobifiEmptyState(
     icon: Icons.confirmation_number_outlined,
     title: 'No bookings yet',
     subtitle: 'Explore activities and book your first experience!',
     actionLabel: 'Explore Activities',
     onAction: () => context.go(AppRoutes.feed),
   )
   ```

5. **Loading state** — replace `CircularProgressIndicator` with `HobifiShimmer.listTile()` repeated 3 times.

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/anis/Developer/Hobifi && flutter analyze lib/screens/user/bookings_screen.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/screens/user/bookings_screen.dart
git commit -m "feat: polish bookings screen with card layout and filter chips"
```

---

## Task 12: Polish Saved Screen

**Files:**
- Modify: `lib/screens/user/saved_screen.dart`

- [ ] **Step 1: Update saved_screen.dart**

1. **Add imports:**
   ```dart
   import 'package:hobby_haven/widgets/hobifi_card.dart';
   import 'package:hobby_haven/widgets/hobifi_empty_state.dart';
   import 'package:hobby_haven/widgets/hobifi_shimmer.dart';
   ```

2. **Replace loading state** with shimmer:
   ```dart
   Column(children: List.generate(3, (_) => Padding(
     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
     child: HobifiShimmer.card(),
   )))
   ```

3. **Replace empty state** with:
   ```dart
   HobifiEmptyState(
     icon: Icons.favorite_outline_rounded,
     title: 'No saved activities',
     subtitle: 'Like activities to save them here',
     actionLabel: 'Start Exploring',
     onAction: () => context.go(AppRoutes.feed),
   )
   ```

4. **Replace inline activity cards** with `HobifiCard()`:
   ```dart
   HobifiCard(
     activity: activity,
     isLiked: true, // always true on saved screen
     onTap: () => context.push('${AppRoutes.activity}/${activity.id}'),
     onLikeTap: () {
       final userId = auth.currentUser?.id;
       if (userId != null) likeService.toggleLike(userId, activity.id);
     },
   )
   ```

5. **Keep** `RefreshIndicator` and `loadLikedActivities` logic.

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/anis/Developer/Hobifi && flutter analyze lib/screens/user/saved_screen.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/screens/user/saved_screen.dart
git commit -m "feat: polish saved screen with HobifiCard and shimmer loading"
```

---

## Task 13: Polish Profile Screen

**Files:**
- Modify: `lib/screens/user/profile_screen.dart`

- [ ] **Step 1: Update profile_screen.dart**

1. **Add interest tags** below the role badge:
   ```dart
   if (user != null && user.interests.isNotEmpty && user.interests.first != 'All') ...[
     const SizedBox(height: 12),
     Wrap(
       spacing: 6,
       runSpacing: 6,
       alignment: WrapAlignment.center,
       children: user.interests.map((interest) => Container(
         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
         decoration: BoxDecoration(
           color: colorScheme.primary.withValues(alpha: 0.06),
           borderRadius: BorderRadius.circular(9999),
           border: Border.all(color: colorScheme.primary.withValues(alpha: 0.15)),
         ),
         child: Text(
           interest,
           style: theme.textTheme.bodySmall?.copyWith(
             color: colorScheme.primary,
             fontWeight: FontWeight.w500,
           ),
         ),
       )).toList(),
     ),
   ],
   ```

2. **Add Reviews count** to stats row alongside Bookings and Liked.
   Import `RatingService`:
   ```dart
   import 'package:hobby_haven/services/rating_service.dart';
   ```
   Read rating count:
   ```dart
   final ratingService = context.watch<RatingService>();
   final reviewCount = ratingService.ratings.length;
   ```
   Add to the stats row:
   ```dart
   Row(
     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
     children: [
       _StatItem(value: '$userBookings', label: 'Bookings'),
       Container(width: 1, height: 40, color: colorScheme.outline.withValues(alpha: 0.3)),
       _StatItem(value: '$likedCount', label: 'Liked'),
       Container(width: 1, height: 40, color: colorScheme.outline.withValues(alpha: 0.3)),
       _StatItem(value: '$reviewCount', label: 'Reviews'),
     ],
   ),
   ```

3. **Load ratings in initState** (add alongside existing loads):
   ```dart
   context.read<RatingService>().loadUserRatings(auth.currentUser!.id);
   ```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/anis/Developer/Hobifi && flutter analyze lib/screens/user/profile_screen.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/screens/user/profile_screen.dart
git commit -m "feat: add interest tags and reviews count to profile screen"
```

---

## Task 14: Polish Ticket Screen

**Files:**
- Modify: `lib/screens/user/ticket_screen.dart`

- [ ] **Step 1: Update ticket_screen.dart**

1. **Fix dark mode** — replace hardcoded `AppColors.lightBackground`, `AppColors.lightSurface`, `AppColors.lightPrimaryText` with theme-aware colors:
   ```dart
   backgroundColor: theme.scaffoldBackgroundColor,
   ```
   ```dart
   color: colorScheme.surface,  // instead of AppColors.lightSurface
   ```
   ```dart
   color: colorScheme.onSurface,  // instead of AppColors.lightPrimaryText
   ```

2. **Add dashed divider** for ticket tear effect — use a `CustomPainter`:
   ```dart
   CustomPaint(
     size: const Size(double.infinity, 1),
     painter: _DashedLinePainter(color: colorScheme.outline.withValues(alpha: 0.3)),
   ),
   ```
   
   Add the painter class:
   ```dart
   class _DashedLinePainter extends CustomPainter {
     final Color color;
     _DashedLinePainter({required this.color});
   
     @override
     void paint(Canvas canvas, Size size) {
       final paint = Paint()
         ..color = color
         ..strokeWidth = 1;
       const dashWidth = 6.0;
       const dashSpace = 4.0;
       double x = 0;
       while (x < size.width) {
         canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
         x += dashWidth + dashSpace;
       }
     }
   
     @override
     bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
   }
   ```

3. **Replace** the divider between image and details with the dashed painter + small semi-circle notches on left/right edges for the "tear" effect.

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/anis/Developer/Hobifi && flutter analyze lib/screens/user/ticket_screen.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/screens/user/ticket_screen.dart
git commit -m "feat: polish ticket screen with dark mode fix and tear effect"
```

---

## Task 15: Polish Wallet Screen (EGP fix + design)

**Files:**
- Modify: `lib/screens/business/wallet_screen.dart`

- [ ] **Step 1: Update wallet_screen.dart**

1. **Fix currency** — find all occurrences of `$` or `\$` used as currency symbol and replace with `EGP`:
   - Search for patterns like `'\$${amount}'` or `'$'` used in currency context
   - Replace with `'EGP ${amount}'`

2. **Polish balance card** at top:
   - Big number: Poppins bold 34px
   - Label: "Available Balance"
   - Use theme colors, not hardcoded

3. **Transaction row status badges:**
   - completed: lime bg + checkmark icon
   - pending: orange bg + clock icon
   - refunded: red bg + arrow icon

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/anis/Developer/Hobifi && flutter analyze lib/screens/business/wallet_screen.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/screens/business/wallet_screen.dart
git commit -m "fix: show EGP currency and polish wallet screen design"
```

---

## Task 16: Polish Auth Screen

**Files:**
- Modify: `lib/screens/auth_screen.dart`

- [ ] **Step 1: Update auth_screen.dart**

1. **Keep** the constellation background animation.

2. **Role toggle** — replace raw buttons with a cleaner pill toggle:
   ```dart
   Container(
     decoration: BoxDecoration(
       color: colorScheme.surface.withValues(alpha: 0.1),
       borderRadius: BorderRadius.circular(9999),
     ),
     child: Row(
       mainAxisSize: MainAxisSize.min,
       children: [
         _RoleToggleButton(label: 'Explorer', isSelected: _isUser, onTap: () => setState(() => _isUser = true)),
         _RoleToggleButton(label: 'Host', isSelected: !_isUser, onTap: () => setState(() => _isUser = false)),
       ],
     ),
   ),
   ```

3. **Primary CTA** — full-width, 52px height, 16px radius:
   ```dart
   SizedBox(
     width: double.infinity,
     height: 52,
     child: FilledButton(
       onPressed: _submit,
       style: FilledButton.styleFrom(
         backgroundColor: colorScheme.primary,
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
       ),
       child: Text(_isSignUp ? 'Create Account' : 'Sign In'),
     ),
   ),
   ```

4. **Sign Up / Sign In toggle** — subtle text link:
   ```dart
   TextButton(
     onPressed: () => setState(() => _isSignUp = !_isSignUp),
     child: Text(
       _isSignUp ? 'Already have an account? Sign In' : "Don't have an account? Sign Up",
       style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.7)),
     ),
   ),
   ```

5. **Tighter spacing** — reduce vertical gaps between form fields from any large values to 12-16px.

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/anis/Developer/Hobifi && flutter analyze lib/screens/auth_screen.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/screens/auth_screen.dart
git commit -m "feat: polish auth screen with pill role toggle and tighter spacing"
```

---

## Task 17: Polish Onboarding Screen

**Files:**
- Modify: `lib/screens/onboarding_screen.dart`

- [ ] **Step 1: Update onboarding_screen.dart**

1. **Interest grid** — larger tap targets (min height 80px), scale animation on select:
   ```dart
   AnimatedScale(
     scale: isSelected ? 0.95 : 1.0,
     duration: const Duration(milliseconds: 150),
     child: Container(
       height: 80,
       decoration: BoxDecoration(
         color: isSelected ? interest.color.withValues(alpha: 0.15) : colorScheme.surface,
         borderRadius: BorderRadius.circular(16),
         border: Border.all(
           color: isSelected ? interest.color : colorScheme.outline.withValues(alpha: 0.2),
           width: isSelected ? 2 : 1,
         ),
       ),
       child: Stack(
         children: [
           Center(
             child: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
                 Icon(interest.icon, size: 28, color: isSelected ? interest.color : colorScheme.onSurface.withValues(alpha: 0.5)),
                 const SizedBox(height: 6),
                 Text(interest.label, style: theme.textTheme.labelMedium?.copyWith(
                   color: isSelected ? interest.color : colorScheme.onSurface.withValues(alpha: 0.7),
                   fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                 )),
               ],
             ),
           ),
           if (isSelected)
             Positioned(
               top: 8, right: 8,
               child: Container(
                 width: 20, height: 20,
                 decoration: BoxDecoration(color: interest.color, shape: BoxShape.circle),
                 child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
               ),
             ),
         ],
       ),
     ),
   ),
   ```

2. **Progress dots** — dot indicator at bottom:
   ```dart
   Row(
     mainAxisAlignment: MainAxisAlignment.center,
     children: List.generate(2, (i) => Container(
       width: _currentPage == i ? 24 : 8,
       height: 8,
       margin: const EdgeInsets.symmetric(horizontal: 4),
       decoration: BoxDecoration(
         color: _currentPage == i ? colorScheme.primary : colorScheme.primary.withValues(alpha: 0.2),
         borderRadius: BorderRadius.circular(4),
       ),
     )),
   ),
   ```

3. **Continue button** — full-width indigo filled, 16px radius, consistent with auth screen.

4. **Skip button** — muted text link top-right of the page.

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/anis/Developer/Hobifi && flutter analyze lib/screens/onboarding_screen.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/screens/onboarding_screen.dart
git commit -m "feat: polish onboarding with larger interest cards and progress dots"
```

---

## Task 18: Polish Booking Confirm Screen

**Files:**
- Modify: `lib/screens/user/booking_confirm_screen.dart`

- [ ] **Step 1: Update booking_confirm_screen.dart**

1. **Add imports:**
   ```dart
   import 'package:cached_network_image/cached_network_image.dart';
   import 'package:hobby_haven/widgets/hobifi_shimmer.dart';
   ```

2. **Order summary card** — activity image at top of card, then details below:
   ```dart
   Container(
     decoration: BoxDecoration(
       color: colorScheme.surface,
       borderRadius: BorderRadius.circular(16),
       boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06), offset: const Offset(0, 2), blurRadius: 12)],
     ),
     child: Column(
       children: [
         // Activity image
         ClipRRect(
           borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
           child: AspectRatio(
             aspectRatio: 16 / 9,
             child: CachedNetworkImage(
               imageUrl: activity.imageUrl,
               fit: BoxFit.cover,
               placeholder: (_, __) => HobifiShimmer.box(double.infinity, double.infinity, radius: 0),
               errorWidget: (_, __, ___) => Container(color: colorScheme.primary.withValues(alpha: 0.08)),
             ),
           ),
         ),
         // Details
         Padding(
           padding: const EdgeInsets.all(16),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text(activity.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
               const SizedBox(height: 8),
               _DetailRow(icon: Icons.calendar_today_rounded, text: DateFormat('EEE, MMM d, yyyy').format(activity.dateTime)),
               _DetailRow(icon: Icons.access_time_rounded, text: DateFormat('h:mm a').format(activity.dateTime)),
               _DetailRow(icon: Icons.location_on_rounded, text: activity.location),
               const Divider(height: 24),
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Text('Total', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                   Text('EGP ${activity.price.toStringAsFixed(0)}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: colorScheme.primary)),
                 ],
               ),
             ],
           ),
         ),
       ],
     ),
   ),
   ```

3. **CTA button** — full-width indigo filled at bottom, consistent with other screens.

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/anis/Developer/Hobifi && flutter analyze lib/screens/user/booking_confirm_screen.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/screens/user/booking_confirm_screen.dart
git commit -m "feat: polish booking confirm with image card and clean summary"
```

---

## Task 19: Polish Payment Screen

**Files:**
- Modify: `lib/screens/user/payment_screen.dart`

- [ ] **Step 1: Update payment_screen.dart**

1. **Add import:**
   ```dart
   import 'package:hobby_haven/widgets/hobifi_shimmer.dart';
   ```

2. **Replace loading/polling spinner** with shimmer or a branded loading state:
   ```dart
   // Instead of bare CircularProgressIndicator during polling:
   Column(
     mainAxisAlignment: MainAxisAlignment.center,
     children: [
       CircularProgressIndicator(color: colorScheme.primary),
       const SizedBox(height: 16),
       Text('Verifying payment...', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.6))),
     ],
   )
   ```

3. **Clean header** — "Payment" title with activity title subtitle.

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/anis/Developer/Hobifi && flutter analyze lib/screens/user/payment_screen.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/screens/user/payment_screen.dart
git commit -m "feat: polish payment screen with loading state text"
```

---

## Task 20: Polish Bottom Navigation

**Files:**
- Modify: `lib/nav.dart`

- [ ] **Step 1: Update nav.dart**

1. **User bottom nav** — add subtle animation on tab switch. Update the `NavigationBar` indicator:
   ```dart
   indicatorColor: colorScheme.primary.withValues(alpha: 0.12),
   indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
   ```

2. **Business bottom nav** — same treatment.

3. **Both navs** — ensure `height: 68` (slightly taller for comfortable tap targets) and consistent icon sizes.

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/anis/Developer/Hobifi && flutter analyze lib/nav.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/nav.dart
git commit -m "feat: polish bottom navigation with rounded indicator"
```

---

## Task 21: Polish Business Profile Screen

**Files:**
- Modify: `lib/screens/business/business_profile_screen.dart`

- [ ] **Step 1: Update business_profile_screen.dart**

1. **Ensure theme-aware colors** — replace any hardcoded light-mode colors with `colorScheme` references.

2. **Stats row** — show Total Activities, Total Bookings, Average Rating in a row similar to user profile's `_StatItem` pattern.

3. **Settings section** — ensure consistent style with user profile (gradient icon containers for each setting tile, like the dark mode toggle pattern).

4. **Keep** existing avatar upload and sign-out logic.

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/anis/Developer/Hobifi && flutter analyze lib/screens/business/business_profile_screen.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/screens/business/business_profile_screen.dart
git commit -m "feat: polish business profile with stats and consistent settings style"
```

---

## Task 22: Final analysis and smoke test

- [ ] **Step 1: Run full flutter analyze**

Run: `cd /Users/anis/Developer/Hobifi && flutter analyze`
Expected: No errors (warnings are acceptable for unused imports during transition)

- [ ] **Step 2: Fix any analysis issues**

Address any errors from the analyze step. Common issues:
- Missing imports
- Unused imports from removed inline widgets
- Type mismatches

- [ ] **Step 3: Run the app**

Run: `cd /Users/anis/Developer/Hobifi && flutter run` (or have user test on their device)
Verify: App launches, feed loads, navigation works, dark mode toggles correctly.

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "fix: resolve analysis issues from frontend overhaul"
```

---

## Execution Order & Dependencies

```
Task 1 (shimmer dep)
  └─► Task 2 (HobifiShimmer)
       └─► Task 6 (HobifiCard — depends on shimmer)
            └─► Task 8 (Feed — depends on card, chip, header, empty)
            └─► Task 12 (Saved — depends on card)

Task 3 (HobifiEmptyState) ─── independent
Task 4 (HobifiSectionHeader) ─── independent
Task 5 (HobifiChip) ─── independent
Task 7 (HobifiStatCard) ─── independent
  └─► Task 10 (Dashboard — depends on stat card, chip)

Tasks 9, 11, 13-21 ─── depend only on shared widgets (Tasks 2-7)
Task 22 (final check) ─── depends on all
```

**Parallelizable groups (for subagent execution):**
- Group A: Tasks 3, 4, 5, 7 (independent widget files)
- Group B: Tasks 9, 11, 13, 14, 15, 16, 17, 18, 19, 20, 21 (independent screen edits, after widgets exist)
