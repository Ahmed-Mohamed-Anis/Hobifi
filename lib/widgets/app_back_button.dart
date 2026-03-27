import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hobby_haven/theme.dart';
import 'package:hobby_haven/nav.dart';

/// A consistent back button for the app, placed top-left in pages.
/// Uses go_router's context.pop() by default.
class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final EdgeInsetsGeometry padding;

  const AppBackButton({super.key, this.onPressed, this.backgroundColor, this.iconColor, this.padding = const EdgeInsets.all(0)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.lightSurface,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: AppColors.lightDivider),
        ),
        child: IconButton(
          onPressed: onPressed ?? () {
            if (Navigator.canPop(context)) {
              context.pop();
            } else {
              context.go(AppRoutes.feed);
            }
          },
          icon: Icon(Icons.arrow_back_rounded, color: iconColor ?? AppColors.lightPrimaryText, size: 22),
          splashRadius: 24,
        ),
      ),
    );
  }
}
