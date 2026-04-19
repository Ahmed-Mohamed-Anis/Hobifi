import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:hobby_haven/services/like_service.dart';
import 'package:hobby_haven/services/auth_service.dart';
import 'package:hobby_haven/nav.dart';
import 'package:hobby_haven/theme.dart';
import 'package:hobby_haven/widgets/hobifi_card.dart';
import 'package:hobby_haven/widgets/hobifi_empty_state.dart';
import 'package:hobby_haven/widgets/hobifi_shimmer.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: AppSpacing.paddingLg,
              child: Text(
                'Saved',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Expanded(child: SavedContent()),
          ],
        ),
      ),
    );
  }
}

/// Reusable widget that renders the liked-activities list without any
/// Scaffold or page-title header. Used as the body of [SavedScreen] and
/// embedded as the "Liked" tab inside My Hobbies.
class SavedContent extends StatefulWidget {
  const SavedContent({super.key});

  @override
  State<SavedContent> createState() => _SavedContentState();
}

class _SavedContentState extends State<SavedContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthService>();
      final likeService = context.read<LikeService>();
      if (auth.currentUser != null) {
        likeService.loadLikes(auth.currentUser!.id).then((_) {
          likeService.loadLikedActivities();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final likeService = context.watch<LikeService>();
    final auth = context.watch<AuthService>();
    final activities = likeService.likedActivities;

    if (likeService.isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: 3,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: HobifiShimmer.card(),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => likeService.loadLikedActivities(),
      child: activities.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: HobifiEmptyState(
                    icon: Icons.favorite_outline_rounded,
                    title: 'No saved activities',
                    subtitle: 'Like activities to save them here',
                    actionLabel: 'Start Exploring',
                    onAction: () => context.go(AppRoutes.feed),
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: activities.length,
              itemBuilder: (context, index) {
                final activity = activities[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: HobifiCard(
                    activity: activity,
                    isLiked: likeService.isLiked(activity.id),
                    onTap: () =>
                        context.push('${AppRoutes.activity}/${activity.id}'),
                    onLikeTap: () {
                      final userId = auth.currentUser?.id;
                      if (userId != null) {
                        likeService.toggleLike(userId, activity.id);
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}
