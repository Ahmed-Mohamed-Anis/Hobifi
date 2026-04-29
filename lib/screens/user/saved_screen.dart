import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:hobby_haven/models/activity_model.dart';
import 'package:hobby_haven/services/like_service.dart';
import 'package:hobby_haven/services/auth_service.dart';
import 'package:hobby_haven/nav.dart';
import 'package:hobby_haven/widgets/hobifi_empty_state.dart';
import 'package:hobby_haven/widgets/hobifi_shimmer.dart';
import 'package:intl/intl.dart';

/// Reusable widget that renders the liked-activities list without any
/// Scaffold or page-title header. Embedded as the "Liked" tab inside the
/// My Hobbies screen (see `bookings_screen.dart`).
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
                  child: _ActivityCompactCard(
                    activity: activity,
                    isLiked: likeService.isLiked(activity.id),
                    onTap: () => context.push('${AppRoutes.activity}/${activity.id}'),
                    onLikeTap: () {
                      final userId = auth.currentUser?.id;
                      if (userId != null) likeService.toggleLike(userId, activity.id);
                    },
                  ),
                );
              },
            ),
    );
  }
}

class _ActivityCompactCard extends StatelessWidget {
  final ActivityModel activity;
  final bool isLiked;
  final VoidCallback onTap;
  final VoidCallback onLikeTap;

  const _ActivityCompactCard({
    required this.activity,
    required this.isLiked,
    required this.onTap,
    required this.onLikeTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isNetwork = activity.imageUrl.startsWith('http');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.06),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: isNetwork
                    ? CachedNetworkImage(
                        imageUrl: activity.imageUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => HobifiShimmer.box(80, 80, radius: 12),
                        errorWidget: (_, __, ___) => Container(
                          width: 80,
                          height: 80,
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      )
                    : Image.asset(activity.imageUrl, width: 80, height: 80, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEE, MMM d • h:mm a').format(activity.dateTime),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            activity.location,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onLikeTap();
                },
                child: Icon(
                  isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isLiked
                      ? const Color(0xFFE53935)
                      : colorScheme.onSurface.withValues(alpha: 0.4),
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
