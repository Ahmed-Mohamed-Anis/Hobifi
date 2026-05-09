import 'package:flutter/material.dart';
import 'package:hobby_haven/theme.dart';
import 'package:hobby_haven/widgets/hobifi_empty_state.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: AppSpacing.paddingLg,
              child: Text(
                'Friends',
                style: theme.textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            const Expanded(
              child: HobifiEmptyState(
                icon: Icons.people_outline_rounded,
                title: 'Friends coming soon',
                subtitle:
                    'Meet people who share your hobbies — launching in a future update.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
