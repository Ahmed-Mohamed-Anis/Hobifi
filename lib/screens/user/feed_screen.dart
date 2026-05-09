import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:hobby_haven/services/activity_service.dart';
import 'package:hobby_haven/models/activity_model.dart';
import 'package:hobby_haven/nav.dart';
import 'package:hobby_haven/services/auth_service.dart';
import 'package:hobby_haven/services/like_service.dart';
import 'package:hobby_haven/services/booking_service.dart';
import 'package:hobby_haven/services/rating_service.dart';
import 'package:hobby_haven/models/booking_model.dart';
import 'package:latlong2/latlong.dart';
import 'package:hobby_haven/services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hobby_haven/utils/distance_util.dart';
import 'package:hobby_haven/widgets/hobifi_card.dart';
import 'package:hobby_haven/widgets/hobifi_chip.dart';
import 'package:hobby_haven/widgets/hobifi_shimmer.dart';
import 'package:hobby_haven/widgets/hobifi_section_header.dart';
import 'package:hobby_haven/widgets/hobifi_empty_state.dart';
import 'package:hobby_haven/widgets/hobifi_search_bar.dart';
import 'package:hobby_haven/utils/feed_filters.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  List<ActivityModel> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<String> _searchHistory = [];
  bool _searchFocused = false;

  static const _historyKey = 'search_history';
  static const _suggestions = ['Pottery', 'Yoga', 'Cooking class', 'Photography'];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadSearchHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthService>();
      if (auth.currentUser != null) {
        context.read<LikeService>().loadLikes(auth.currentUser!.id);
        _checkUnratedBookings(auth.currentUser!.id);
      }
    });
  }

  Future<void> _checkUnratedBookings(String userId) async {
    try {
      final bookingService = context.read<BookingService>();
      final ratingService = context.read<RatingService>();
      await bookingService.loadUserBookings(userId);
      await ratingService.loadUserRatings(userId);

      final completed = bookingService.getBookingsByStatus(BookingStatus.completed);
      for (final booking in completed) {
        final hasRating = ratingService.getUserRatingForActivity(userId, booking.activityId) != null;
        if (!hasRating && mounted) {
          _showRatingPrompt(userId, booking.activityId, booking.activityTitle);
          break; // Only prompt for one at a time
        }
      }
    } catch (e) {
      debugPrint('Failed to check unrated bookings: $e');
    }
  }

  void _showRatingPrompt(String userId, String activityId, String activityTitle) {
    int selectedStars = 0;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final theme = Theme.of(ctx);
            final colorScheme = theme.colorScheme;
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'How was it?',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    activityTitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final star = i + 1;
                      return IconButton(
                        onPressed: () => setSheetState(() => selectedStars = star),
                        icon: Icon(
                          selectedStars >= star ? Icons.star_rounded : Icons.star_border_rounded,
                          size: 40,
                          color: colorScheme.tertiary,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: selectedStars > 0
                          ? () async {
                              await context.read<RatingService>().addOrUpdateRating(
                                    userId,
                                    activityId,
                                    selectedStars,
                                  );
                              if (ctx.mounted) Navigator.of(ctx).pop();
                            }
                          : null,
                      child: const Text('Submit Rating'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text('Maybe later', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5))),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final results = await context.read<ActivityService>().searchActivities(
        query.trim(),
        category: _selectedCategory,
      );
      if (mounted && _searchQuery == query) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _searchHistory = prefs.getStringList(_historyKey) ?? []);
  }

  Future<void> _saveSearchTerm(String term) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return;
    final updated = [trimmed, ..._searchHistory.where((t) => t != trimmed)].take(5).toList();
    setState(() => _searchHistory = updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, updated);
  }

  Future<void> _removeSearchTerm(String term) async {
    final updated = _searchHistory.where((t) => t != term).toList();
    setState(() => _searchHistory = updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, updated);
  }

  void _selectCategory(String category) {
    setState(() => _selectedCategory = category);
    if (_searchQuery.trim().isNotEmpty) {
      _onSearchChanged(_searchQuery);
    }
  }

  void _onScroll() {
    if (_searchQuery.isNotEmpty) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    // Trigger load-more when within 200px of the bottom
    if (maxScroll - currentScroll <= 200) {
      context.read<ActivityService>().loadMoreActivities();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String? _distanceLabel(ActivityModel activity, LatLng? userLocation) {
    if (userLocation == null || activity.latitude == null) return null;
    return DistanceUtil.formatDistance(
      userLocation,
      LatLng(activity.latitude!, activity.longitude!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activityService = context.watch<ActivityService>();
    final auth = context.watch<AuthService>();

    // Use server-side search results when searching, cached list otherwise
    final List<ActivityModel> activities;
    if (_searchQuery.trim().isNotEmpty) {
      activities = _searchResults;
    } else if (_selectedCategory == 'All') {
      activities = activityService.activities;
    } else {
      activities = activityService.getActivitiesByCategory(_selectedCategory);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<ActivityService>().loadActivities(),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // 1. Header
              SliverToBoxAdapter(
                child: _MinimalHeader(
                  mainTab: 'Explore',
                  avatarUrl: auth.currentUser?.avatarUrl,
                  onProfileTap: () => context.go(AppRoutes.profile),
                ),
              ),

              // 2. Search bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: HobifiSearchBar(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onClear: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                    onFocusChange: (focused) => setState(() => _searchFocused = focused),
                    onSubmitted: (term) {
                      if (term.trim().isNotEmpty) _saveSearchTerm(term.trim());
                    },
                  ),
                ),
              ),

              // 2b. Search history / suggestion chips
              if (_searchFocused && _searchQuery.isEmpty)
                SliverToBoxAdapter(child: _buildSearchChips()),

              // 3. Category chips using HobifiChip
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      HobifiChip(
                        label: 'All',
                        icon: Icons.apps_rounded,
                        isSelected: _selectedCategory == 'All',
                        onTap: () => _selectCategory('All'),
                      ),
                      HobifiChip(
                        label: 'Art',
                        icon: Icons.palette_rounded,
                        isSelected: _selectedCategory == 'Art',
                        onTap: () => _selectCategory('Art'),
                      ),
                      HobifiChip(
                        label: 'Sports',
                        icon: Icons.sports_basketball_rounded,
                        isSelected: _selectedCategory == 'Sports',
                        onTap: () => _selectCategory('Sports'),
                      ),
                      HobifiChip(
                        label: 'Music',
                        icon: Icons.music_note_rounded,
                        isSelected: _selectedCategory == 'Music',
                        onTap: () => _selectCategory('Music'),
                      ),
                      HobifiChip(
                        label: 'Cooking',
                        icon: Icons.restaurant_rounded,
                        isSelected: _selectedCategory == 'Cooking',
                        onTap: () => _selectCategory('Cooking'),
                      ),
                      HobifiChip(
                        label: 'Tech',
                        icon: Icons.computer_rounded,
                        isSelected: _selectedCategory == 'Tech',
                        onTap: () => _selectCategory('Tech'),
                      ),
                      HobifiChip(
                        label: 'Outdoor',
                        icon: Icons.terrain_rounded,
                        isSelected: _selectedCategory == 'Outdoor',
                        onTap: () => _selectCategory('Outdoor'),
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Content: discovery feed OR search results
              if (_searchQuery.isEmpty) ...[
                _buildDiscoveryFeed(activities, theme),
              ] else if (_isSearching) ...[
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, __) => Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: HobifiShimmer.card(),
                    ),
                    childCount: 3,
                  ),
                ),
              ] else ...[
                _buildSearchResults(activities, theme),
              ],

              // 5. Pagination loading
              if (activityService.isLoading && activityService.activities.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: HobifiShimmer.card(),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchChips() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final chips = _searchHistory.isNotEmpty ? _searchHistory : _suggestions;
    final label = _searchHistory.isNotEmpty ? 'Recent' : 'Popular';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips.map((term) {
              return InputChip(
                label: Text(term),
                onPressed: () {
                  _searchController.text = term;
                  _onSearchChanged(term);
                  _saveSearchTerm(term);
                },
                onDeleted: _searchHistory.isNotEmpty ? () => _removeSearchTerm(term) : null,
                deleteIcon: _searchHistory.isNotEmpty
                    ? Icon(Icons.close_rounded,
                        size: 14, color: colorScheme.onSurface.withValues(alpha: 0.5))
                    : null,
                backgroundColor: colorScheme.surface,
                side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
                labelStyle: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveryFeed(List<ActivityModel> activities, ThemeData theme) {
    if (activities.isEmpty) {
      return const SliverToBoxAdapter(
        child: HobifiEmptyState(
          icon: Icons.explore_off_rounded,
          title: 'No experiences found',
          subtitle: 'Check back soon for new activities in your area',
        ),
      );
    }

    final auth = context.watch<AuthService>();
    final likeService = context.watch<LikeService>();
    final userLocation = context.watch<LocationService>().savedLocation;

    final trendingActivities = trendingFilterSort(activities, 'All', userLocation);
    final popularActivities = nearbyFilterSort(activities, 'All', userLocation);
    final weekendActivities = weekendFilterSort(activities, 'All', userLocation);

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trending section
          HobifiSectionHeader(
            title: 'Trending Experiences',
            subtitle: 'Highest rated right now',
            actionLabel: 'Explore more',
            onSeeAll: () => context.push(
              AppRoutes.sectionExplore,
              extra: {
                'title': 'Trending Experiences',
                'subtitle': 'Highest rated right now',
                'filterSort': trendingFilterSort,
              },
            ),
          ),
          SizedBox(
            height: 340,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: trendingActivities.length,
              itemBuilder: (context, index) {
                final activity = trendingActivities[index];
                return Padding(
                  padding: EdgeInsets.only(
                    right: index < trendingActivities.length - 1 ? 16 : 0,
                  ),
                  child: HobifiCard.featured(
                    activity: activity,
                    isLiked: likeService.isLiked(activity.id),
                    onTap: () => context.push('${AppRoutes.activity}/${activity.id}'),
                    onLikeTap: () {
                      final userId = auth.currentUser?.id;
                      if (userId != null) likeService.toggleLike(userId, activity.id);
                    },
                    distanceLabel: _distanceLabel(activity, userLocation),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),

          // Popular section
          HobifiSectionHeader(
            title: 'Popular Near You',
            subtitle: 'Closest activities to you',
            actionLabel: 'Explore more',
            onSeeAll: userLocation != null ? () => context.push(
              AppRoutes.sectionExplore,
              extra: {
                'title': 'Popular Near You',
                'subtitle': 'Closest activities to you',
                'filterSort': nearbyFilterSort,
              },
            ) : null,
          ),
          if (userLocation == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: HobifiEmptyState(
                icon: Icons.location_off_rounded,
                title: 'Enable location to see activities near you',
                actionLabel: 'Enable Location',
                onAction: () { Geolocator.openAppSettings(); },
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: popularActivities.map((activity) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: HobifiCard(
                    activity: activity,
                    isLiked: likeService.isLiked(activity.id),
                    onTap: () => context.push('${AppRoutes.activity}/${activity.id}'),
                    onLikeTap: () {
                      final userId = auth.currentUser?.id;
                      if (userId != null) likeService.toggleLike(userId, activity.id);
                    },
                    distanceLabel: _distanceLabel(activity, userLocation),
                  ),
                )).toList(),
              ),
            ),

          // Weekend section (if activities available)
          if (weekendActivities.isNotEmpty) ...[
            const SizedBox(height: 24),
            HobifiSectionHeader(
              title: 'Friday & Saturday',
              subtitle: 'Activities this weekend',
              actionLabel: 'Explore more',
              onSeeAll: () => context.push(
                AppRoutes.sectionExplore,
                extra: {
                  'title': 'Friday & Saturday',
                  'subtitle': 'Activities this weekend',
                  'filterSort': weekendFilterSort,
                },
              ),
            ),
            SizedBox(
              height: 340,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: weekendActivities.length,
                itemBuilder: (context, index) {
                  final activity = weekendActivities[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index < weekendActivities.length - 1 ? 16 : 0,
                    ),
                    child: HobifiCard.featured(
                      activity: activity,
                      isLiked: likeService.isLiked(activity.id),
                      onTap: () => context.push('${AppRoutes.activity}/${activity.id}'),
                      onLikeTap: () {
                        final userId = auth.currentUser?.id;
                        if (userId != null) likeService.toggleLike(userId, activity.id);
                      },
                      distanceLabel: _distanceLabel(activity, userLocation),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchResults(List<ActivityModel> activities, ThemeData theme) {
    final auth = context.watch<AuthService>();
    final likeService = context.watch<LikeService>();
    final userLocation = context.watch<LocationService>().savedLocation;

    if (activities.isEmpty) {
      return SliverToBoxAdapter(
        child: HobifiEmptyState(
          icon: Icons.search_off_rounded,
          title: 'No results found',
          subtitle: 'Try different keywords or explore categories',
          actionLabel: 'Clear Search',
          onAction: () {
            _searchController.clear();
            _onSearchChanged('');
          },
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final activity = activities[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: HobifiCard(
                activity: activity,
                isLiked: likeService.isLiked(activity.id),
                onTap: () => context.push('${AppRoutes.activity}/${activity.id}'),
                onLikeTap: () {
                  final userId = auth.currentUser?.id;
                  if (userId != null) likeService.toggleLike(userId, activity.id);
                },
                distanceLabel: _distanceLabel(activity, userLocation),
              ),
            );
          },
          childCount: activities.length,
        ),
      ),
    );
  }
}

// ── Minimal Header ────────────────────────────────────────────────────────────

class _MinimalHeader extends StatelessWidget {
  final String mainTab;
  final String? avatarUrl;
  final VoidCallback onProfileTap;

  const _MinimalHeader({
    required this.mainTab,
    this.avatarUrl,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRect(
                child: Align(
                  alignment: Alignment.topLeft,
                  heightFactor: 0.72,
                  child: Image.asset(
                    'assets/images/hobifi_logo.png',
                    height: 90,
                    fit: BoxFit.fitHeight,
                  ),
                ),
              ),
              Text(
                mainTab == 'Explore' ? 'Discover' : mainTab,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: onProfileTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                image: avatarUrl != null && avatarUrl!.startsWith('http')
                    ? DecorationImage(
                        image: NetworkImage(avatarUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: avatarUrl == null || !avatarUrl!.startsWith('http')
                  ? Icon(Icons.person_outlined, color: colorScheme.primary, size: 22)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

