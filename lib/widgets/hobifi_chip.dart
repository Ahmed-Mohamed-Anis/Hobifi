import 'package:flutter/material.dart';

/// A pill-shaped category filter chip with selected/unselected states.
///
/// Usage:
///   HobifiChip(
///     label: 'Yoga',
///     icon: Icons.self_improvement,
///     isSelected: _selected == 'Yoga',
///     onTap: () => setState(() => _selected = 'Yoga'),
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final backgroundColor =
        isSelected ? colorScheme.primary : colorScheme.surface;

    final borderColor = isSelected
        ? Colors.transparent
        : colorScheme.outline.withValues(alpha: 0.2);

    final contentColor = isSelected
        ? colorScheme.onPrimary
        : colorScheme.onSurface.withValues(alpha: 0.7);

    final iconColor = isSelected
        ? colorScheme.onPrimary
        : colorScheme.onSurface.withValues(alpha: 0.6);

    final fontWeight = isSelected ? FontWeight.w700 : FontWeight.w500;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: textTheme.labelMedium?.copyWith(
                  color: contentColor,
                  fontWeight: fontWeight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
