import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:hobby_haven/nav.dart';
import 'package:hobby_haven/services/activity_service.dart';
import 'package:hobby_haven/services/auth_service.dart';
import 'package:hobby_haven/services/like_service.dart';
import 'package:hobby_haven/services/location_service.dart';
import 'package:hobby_haven/utils/distance_util.dart';
import 'package:hobby_haven/utils/feed_filters.dart';
import 'package:hobby_haven/widgets/hobifi_card.dart';
import 'package:hobby_haven/widgets/hobifi_chip.dart';
import 'package:hobby_haven/widgets/hobifi_empty_state.dart';
import 'package:hobby_haven/widgets/hobifi_search_bar.dart';
import 'package:hobby_haven/widgets/hobifi_shimmer.dart';

class SectionExploreScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final SectionFilterSort filterSort;

  const SectionExploreScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.filterSort,
  });

  @override
  State<SectionExploreScreen> createState() => _SectionExploreScreenState();
}

class _SectionExploreScreenState extends State<SectionExploreScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activityService = context.watch<ActivityService>();
    final likeService = context.watch<LikeService>();
    final auth = context.watch<AuthService>();
    final userLocation = context.watch<LocationService>().savedLocation;

    var filtered = widget.filterSort(
      activityService.activities,
      _selectedCategory,
      userLocation,
    );

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      filtered = filtered
          .where(
            (a) =>
                a.title.toLowerCase().contains(q) ||
                a.location.toLowerCase().contains(q),
          )
          .toList();
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 20, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
                    onPressed: () => context.pop(),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          widget.subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: HobifiSearchBar(
                controller: _searchController,
                onChanged: (q) => setState(() => _searchQuery = q),
                onClear: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              ),
            ),
            // Category chips
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  HobifiChip(
                    label: 'All',
                    icon: Icons.apps_rounded,
                    isSelected: _selectedCategory == 'All',
                    onTap: () => setState(() => _selectedCategory = 'All'),
                  ),
                  HobifiChip(
                    label: 'Art',
                    icon: Icons.palette_rounded,
                    isSelected: _selectedCategory == 'Art',
                    onTap: () => setState(() => _selectedCategory = 'Art'),
                  ),
                  HobifiChip(
                    label: 'Sports',
                    icon: Icons.sports_basketball_rounded,
                    isSelected: _selectedCategory == 'Sports',
                    onTap: () => setState(() => _selectedCategory = 'Sports'),
                  ),
                  HobifiChip(
                    label: 'Music',
                    icon: Icons.music_note_rounded,
                    isSelected: _selectedCategory == 'Music',
                    onTap: () => setState(() => _selectedCategory = 'Music'),
                  ),
                  HobifiChip(
                    label: 'Cooking',
                    icon: Icons.restaurant_rounded,
                    isSelected: _selectedCategory == 'Cooking',
                    onTap: () => setState(() => _selectedCategory = 'Cooking'),
                  ),
                  HobifiChip(
                    label: 'Tech',
                    icon: Icons.computer_rounded,
                    isSelected: _selectedCategory == 'Tech',
                    onTap: () => setState(() => _selectedCategory = 'Tech'),
                  ),
                  HobifiChip(
                    label: 'Outdoor',
                    icon: Icons.terrain_rounded,
                    isSelected: _selectedCategory == 'Outdoor',
                    onTap: () => setState(() => _selectedCategory = 'Outdoor'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Results
            Expanded(
              child: activityService.isLoading && activityService.activities.isEmpty
                  ? ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: 4,
                      itemBuilder: (_, __) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: HobifiShimmer.card(),
                      ),
                    )
                  : filtered.isEmpty
                      ? const HobifiEmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'No activities found',
                          subtitle: 'Try a different category or search term',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final activity = filtered[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: HobifiCard(
                                activity: activity,
                                isLiked: likeService.isLiked(activity.id),
                                onTap: () => context.push(
                                  '${AppRoutes.activity}/${activity.id}',
                                ),
                                onLikeTap: () {
                                  final userId = auth.currentUser?.id;
                                  if (userId != null) {
                                    likeService.toggleLike(userId, activity.id);
                                  }
                                },
                                distanceLabel: userLocation != null &&
                                        activity.latitude != null
                                    ? DistanceUtil.formatDistance(
                                        userLocation,
                                        LatLng(
                                          activity.latitude!,
                                          activity.longitude!,
                                        ),
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
