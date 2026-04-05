import 'package:flutter/material.dart';
import 'package:hobby_haven/theme.dart';

/// A dashboard stat card displaying a value, label, optional trend badge,
/// and a left-edge gradient accent strip.
class HobifiStatCard extends StatelessWidget {
  /// Short label describing the stat, e.g. "Total Revenue".
  final String label;

  /// Formatted value string, e.g. "EGP 12,500".
  final String value;

  /// Optional trend string, e.g. "+12%". When null the trend pill is hidden.
  final String? trend;

  /// Whether the trend is positive (lime) or negative (red). Defaults to true.
  final bool trendPositive;

  /// Icon shown beside the label.
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Box shadow differs by brightness.
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.2)
        : Colors.black.withValues(alpha: 0.04);

    // Gradient accent strip colors.
    final accentStart =
        isDark ? const Color(0xFF4A47B8) : AppColors.indigo;
    final accentEnd =
        isDark ? const Color(0xFF6C68D4) : const Color(0xFF3A378A);

    // Trend pill colors.
    final trendColor =
        trendPositive ? AppColors.lime : AppColors.likeRed;

    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left accent strip ──────────────────────────────
          Container(
            width: 4,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [accentStart, accentEnd],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // ── Info column ────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon + label
                Row(
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: cs.primary.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Value
                Text(
                  value,
                  style: tt.titleLarge?.copyWith(
                    fontSize: 20,
                    color: cs.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                // Trend pill (optional)
                if (trend != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: trendColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Text(
                      trend!,
                      style: tt.bodySmall?.copyWith(
                        fontSize: 11,
                        color: trendColor,
                        fontWeight: FontWeight.w700,
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
