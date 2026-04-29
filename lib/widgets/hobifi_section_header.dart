import 'package:flutter/material.dart';

/// A section title row with an optional "See all" action link.
///
/// Displays a bold title on the left with an optional muted subtitle below it,
/// and an optional "See all" tap target on the right.
///
/// Usage:
/// ```dart
/// HobifiSectionHeader(
///   title: 'Nearby Activities',
///   subtitle: 'Within 5 km',
///   onSeeAll: () => Navigator.push(...),
/// )
/// ```
class HobifiSectionHeader extends StatelessWidget {
  /// Primary section title.
  final String title;

  /// Optional secondary label shown below the title at reduced opacity.
  final String? subtitle;

  /// When provided, an action link is rendered on the right.
  final VoidCallback? onSeeAll;

  /// Label for the action link. Defaults to 'See all'.
  final String actionLabel;

  const HobifiSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onSeeAll,
    this.actionLabel = 'See all',
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: title + optional subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Right: "See all" link (only when callback is provided)
          if (onSeeAll != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: GestureDetector(
                onTap: onSeeAll,
                child: Text(
                  actionLabel,
                  style: textTheme.labelMedium?.copyWith(
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
