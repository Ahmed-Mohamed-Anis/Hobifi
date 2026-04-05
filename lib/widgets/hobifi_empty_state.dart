import 'package:flutter/material.dart';

/// A consistent empty/error state widget used across all screens.
///
/// Shows a centered column with an icon, title, optional subtitle,
/// and an optional CTA button.
///
/// Usage:
/// ```dart
/// HobifiEmptyState(
///   icon: Icons.search_off,
///   title: 'No results found',
///   subtitle: 'Try adjusting your filters.',
///   actionLabel: 'Clear filters',
///   onAction: () => clearFilters(),
/// )
/// ```
class HobifiEmptyState extends StatelessWidget {
  /// Main icon displayed in the rounded container.
  final IconData icon;

  /// Primary message shown below the icon.
  final String title;

  /// Optional secondary message shown below the title.
  final String? subtitle;

  /// Text for the CTA button. Displayed only when [onAction] is also provided.
  final String? actionLabel;

  /// Callback for the CTA button. Displayed only when [actionLabel] is also provided.
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon container
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                icon,
                size: 36,
                color: colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),

            const SizedBox(height: 24),

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),

            // Subtitle (optional)
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],

            // CTA button (optional — only when both label and callback are provided)
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
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
