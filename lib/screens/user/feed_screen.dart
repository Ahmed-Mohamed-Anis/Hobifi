import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:hobby_haven/widgets/hobifi_card.dart';
import 'package:hobby_haven/widgets/hobifi_chip.dart';
import 'package:hobby_haven/widgets/hobifi_shimmer.dart';
import 'package:hobby_haven/widgets/hobifi_section_header.dart';
import 'package:hobby_haven/widgets/hobifi_empty_state.dart';

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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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
                  child: _MinimalSearchBar(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onClear: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  ),
                ),
              ),

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
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator()),
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

    final trendingActivities = activities.take(3).toList();
    final popularActivities = activities.skip(1).take(4).toList();
    final weekendActivities = activities.where((a) => a.spotsLeft > 5).take(3).toList();

    final auth = context.watch<AuthService>();
    final likeService = context.watch<LikeService>();

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trending section
          const HobifiSectionHeader(
            title: 'Trending Experiences',
            subtitle: 'Most popular right now',
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
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),

          // Popular section
          const HobifiSectionHeader(
            title: 'Popular Near You',
            subtitle: "Discover what's happening around you",
          ),
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
                ),
              )).toList(),
            ),
          ),

          // Weekend section (if activities available)
          if (weekendActivities.isNotEmpty) ...[
            const SizedBox(height: 24),
            const HobifiSectionHeader(
              title: 'Weekend Adventures',
              subtitle: 'Perfect for your next getaway',
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
              Text(
                'HOBIFI',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.secondary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
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
                borderRadius: BorderRadius.circular(14),
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

// ── Minimal Search Bar ────────────────────────────────────────────────────────

class _MinimalSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _MinimalSearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_MinimalSearchBar> createState() => _MinimalSearchBarState();
}

class _MinimalSearchBarState extends State<_MinimalSearchBar> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      height: 52,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isFocused ? colorScheme.primary : theme.dividerColor,
          width: _isFocused ? 1.5 : 1,
        ),
        boxShadow: _isFocused
            ? [BoxShadow(color: colorScheme.primary.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))]
            : null,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        onChanged: widget.onChanged,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: 'Search experiences...',
          hintStyle: TextStyle(
            color: theme.hintColor,
            fontSize: 15,
          ),
          prefixIcon: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(
              Icons.search_rounded,
              color: _isFocused ? colorScheme.primary : theme.hintColor,
              size: 22,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 50),
          suffixIcon: widget.controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, color: theme.hintColor, size: 20),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    widget.onClear();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
