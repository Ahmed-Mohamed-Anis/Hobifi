import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hobby_haven/services/activity_service.dart';
import 'package:hobby_haven/models/activity_model.dart';
import 'package:hobby_haven/models/booking_model.dart';
import 'package:hobby_haven/nav.dart';
import 'package:hobby_haven/services/auth_service.dart';
import 'package:hobby_haven/services/like_service.dart';
import 'package:hobby_haven/services/booking_service.dart';
import 'package:hobby_haven/screens/user/bookings_screen.dart' show BookingCard;

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  String _mainTab = 'Explore';
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
        context.read<BookingService>().loadUserBookings(auth.currentUser!.id);
      }
    });
  }

  void _onScroll() {
    if (_mainTab != 'Explore' || _searchQuery.isNotEmpty) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    // Trigger load-more when within 200px of the bottom
    if (maxScroll - currentScroll <= 200) {
      context.read<ActivityService>().loadMoreActivities();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activityService = context.watch<ActivityService>();
    final auth = context.watch<AuthService>();
    final likeService = context.watch<LikeService>();
    final bookingService = context.watch<BookingService>();

    final user = auth.currentUser;
    final userBookings = user == null ? <BookingModel>[] : bookingService.getUserBookings(user.id);
    final now = DateTime.now();
    final upcomingBookings = userBookings
        .where((b) => (b.status == BookingStatus.confirmed || b.status == BookingStatus.pending) && b.dateTime.isAfter(now))
        .toList();
    final cancelledBookings = userBookings.where((b) => b.status == BookingStatus.cancelled).toList();
    final likedActivities = likeService.likedActivityIds
        .map((id) => activityService.getActivityById(id))
        .whereType<ActivityModel>()
        .toList();

    List<ActivityModel> activities = _selectedCategory == 'All'
        ? activityService.activities
        : activityService.getActivitiesByCategory(_selectedCategory);

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      activities = activities.where((a) {
        return a.title.toLowerCase().contains(q) ||
            a.description.toLowerCase().contains(q) ||
            a.location.toLowerCase().contains(q) ||
            a.category.toLowerCase().contains(q);
      }).toList();
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Clean minimal header
            SliverToBoxAdapter(
              child: _MinimalHeader(
                mainTab: _mainTab,
                avatarUrl: auth.currentUser?.avatarUrl,
                onProfileTap: () => context.go(AppRoutes.profile),
              ),
            ),

            // Search bar (only in Explore)
            if (_mainTab == 'Explore')
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: _MinimalSearchBar(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    onClear: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
                ),
              ),

            // Main navigation tabs
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _MinimalTab(
                      label: 'Explore',
                      isSelected: _mainTab == 'Explore',
                      onTap: () => setState(() => _mainTab = 'Explore'),
                    ),
                    _MinimalTab(
                      label: 'Upcoming',
                      count: upcomingBookings.length,
                      isSelected: _mainTab == 'Upcoming',
                      onTap: () => setState(() => _mainTab = 'Upcoming'),
                    ),
                    _MinimalTab(
                      label: 'Saved',
                      count: likedActivities.length,
                      isSelected: _mainTab == 'Liked',
                      onTap: () => setState(() => _mainTab = 'Liked'),
                    ),
                    _MinimalTab(
                      label: 'History',
                      isSelected: _mainTab == 'All',
                      onTap: () => setState(() => _mainTab = 'All'),
                    ),
                    _MinimalTab(
                      label: 'Cancelled',
                      isSelected: _mainTab == 'Cancelled',
                      onTap: () => setState(() => _mainTab = 'Cancelled'),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Content based on tab
            if (_mainTab == 'Explore') ...[
              // Category filters with icons
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _CategoryChip(
                        label: 'All',
                        icon: Icons.apps_rounded,
                        isSelected: _selectedCategory == 'All',
                        onTap: () => setState(() => _selectedCategory = 'All'),
                      ),
                      _CategoryChip(
                        label: 'Adventure',
                        icon: Icons.terrain_rounded,
                        isSelected: _selectedCategory == 'Adventure',
                        onTap: () => setState(() => _selectedCategory = 'Adventure'),
                      ),
                      _CategoryChip(
                        label: 'Sports',
                        icon: Icons.sports_basketball_rounded,
                        isSelected: _selectedCategory == 'Sports',
                        onTap: () => setState(() => _selectedCategory = 'Sports'),
                      ),
                      _CategoryChip(
                        label: 'Creative',
                        icon: Icons.palette_rounded,
                        isSelected: _selectedCategory == 'Art',
                        onTap: () => setState(() => _selectedCategory = 'Art'),
                      ),
                      _CategoryChip(
                        label: 'Wellness',
                        icon: Icons.self_improvement_rounded,
                        isSelected: _selectedCategory == 'Fitness',
                        onTap: () => setState(() => _selectedCategory = 'Fitness'),
                      ),
                      _CategoryChip(
                        label: 'Music',
                        icon: Icons.music_note_rounded,
                        isSelected: _selectedCategory == 'Music',
                        onTap: () => setState(() => _selectedCategory = 'Music'),
                      ),
                      _CategoryChip(
                        label: 'Culinary',
                        icon: Icons.restaurant_rounded,
                        isSelected: _selectedCategory == 'Cooking',
                        onTap: () => setState(() => _selectedCategory = 'Cooking'),
                      ),
                    ],
                  ),
                ),
              ),

              // Discovery sections
              if (_searchQuery.isEmpty) ...[
                _buildDiscoveryFeed(activities, theme),
              ] else ...[
                // Search results
                _buildSearchResults(activities, theme),
              ],
            ] else ...[
              _buildTabContent(
                mainTab: _mainTab,
                upcomingBookings: upcomingBookings,
                likedActivities: likedActivities,
                allBookings: userBookings,
                cancelledBookings: cancelledBookings,
                theme: theme,
              ),
            ],

            // Loading indicator for pagination
            if (_mainTab == 'Explore' && activityService.isLoading && activityService.activities.isNotEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoveryFeed(List<ActivityModel> activities, ThemeData theme) {
    if (activities.isEmpty) {
      return SliverToBoxAdapter(
        child: _EmptyState(
          icon: Icons.explore_off_rounded,
          title: 'No experiences found',
          subtitle: 'Check back soon for new activities in your area',
        ),
      );
    }

    // Group activities for curated sections
    final trendingActivities = activities.take(3).toList();
    final popularActivities = activities.skip(1).take(4).toList();
    final weekendActivities = activities.where((a) => a.spotsLeft > 5).take(3).toList();

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trending Experiences - Featured horizontal scroll
          _SectionHeader(
            title: 'Trending Experiences',
            subtitle: 'Most popular right now',
          ),
          SizedBox(
            height: 340,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: trendingActivities.length,
              itemBuilder: (context, index) => Padding(
                padding: EdgeInsets.only(right: index < trendingActivities.length - 1 ? 16 : 0),
                child: _FeaturedExperienceCard(activity: trendingActivities[index]),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Popular Near You - Vertical list
          _SectionHeader(
            title: 'Popular Near You',
            subtitle: 'Discover what\'s happening around you',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: popularActivities.map((activity) => 
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _CompactExperienceCard(activity: activity),
                ),
              ).toList(),
            ),
          ),

          if (weekendActivities.isNotEmpty) ...[
            const SizedBox(height: 24),

            // Weekend Adventures - Horizontal cards
            _SectionHeader(
              title: 'Weekend Adventures',
              subtitle: 'Perfect for your next getaway',
            ),
            SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: weekendActivities.length,
                itemBuilder: (context, index) => Padding(
                  padding: EdgeInsets.only(right: index < weekendActivities.length - 1 ? 16 : 0),
                  child: _MediumExperienceCard(activity: weekendActivities[index]),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchResults(List<ActivityModel> activities, ThemeData theme) {
    if (activities.isEmpty) {
      return SliverToBoxAdapter(
        child: _EmptyState(
          icon: Icons.search_off_rounded,
          title: 'No results found',
          subtitle: 'Try different keywords or explore categories',
          actionLabel: 'Clear Search',
          onAction: () {
            _searchController.clear();
            setState(() => _searchQuery = '');
          },
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _CompactExperienceCard(activity: activities[index]),
          ),
          childCount: activities.length,
        ),
      ),
    );
  }

  Widget _buildTabContent({
    required String mainTab,
    required List<BookingModel> upcomingBookings,
    required List<ActivityModel> likedActivities,
    required List<BookingModel> allBookings,
    required List<BookingModel> cancelledBookings,
    required ThemeData theme,
  }) {
    switch (mainTab) {
      case 'Upcoming':
        if (upcomingBookings.isEmpty) {
          return SliverToBoxAdapter(
            child: _EmptyState(
              icon: Icons.calendar_today_rounded,
              title: 'No upcoming experiences',
              subtitle: 'Your next adventure is waiting to be discovered',
              actionLabel: 'Explore Now',
              onAction: () => setState(() => _mainTab = 'Explore'),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: BookingCard(booking: upcomingBookings[index]),
              ),
              childCount: upcomingBookings.length,
            ),
          ),
        );

      case 'Liked':
        if (likedActivities.isEmpty) {
          return SliverToBoxAdapter(
            child: _EmptyState(
              icon: Icons.bookmark_border_rounded,
              title: 'No saved experiences',
              subtitle: 'Save activities you\'d like to try later',
              actionLabel: 'Start Exploring',
              onAction: () => setState(() => _mainTab = 'Explore'),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _CompactExperienceCard(activity: likedActivities[index]),
              ),
              childCount: likedActivities.length,
            ),
          ),
        );

      case 'All':
        if (allBookings.isEmpty) {
          return SliverToBoxAdapter(
            child: _EmptyState(
              icon: Icons.history_rounded,
              title: 'Your journey begins here',
              subtitle: 'Book your first experience and start exploring',
              actionLabel: 'Discover',
              onAction: () => setState(() => _mainTab = 'Explore'),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: BookingCard(booking: allBookings[index]),
              ),
              childCount: allBookings.length,
            ),
          ),
        );

      case 'Cancelled':
        if (cancelledBookings.isEmpty) {
          return SliverToBoxAdapter(
            child: _EmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: 'All clear',
              subtitle: 'No cancelled bookings',
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: BookingCard(booking: cancelledBookings[index]),
              ),
              childCount: cancelledBookings.length,
            ),
          ),
        );

      default:
        return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
  }
}

// Minimal Header
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

// Minimal Search Bar with smooth focus animations
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

// Minimal Tab with smooth animations
class _MinimalTab extends StatefulWidget {
  final String label;
  final int? count;
  final bool isSelected;
  final VoidCallback onTap;

  const _MinimalTab({
    required this.label,
    this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_MinimalTab> createState() => _MinimalTabState();
}

class _MinimalTabState extends State<_MinimalTab> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _scaleController.forward();
  void _onTapUp(_) => _scaleController.reverse();
  void _onTapCancel() => _scaleController.reverse();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
          child: Builder(
            builder: (context) {
              final colorScheme = Theme.of(context).colorScheme;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.isSelected ? colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      style: theme.textTheme.labelMedium!.copyWith(
                        color: widget.isSelected ? colorScheme.onPrimary : colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                      child: Text(widget.label),
                    ),
                    if (widget.count != null && widget.count! > 0) ...[
                      const SizedBox(width: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: widget.isSelected 
                              ? colorScheme.onPrimary.withValues(alpha: 0.2) 
                              : colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.count.toString(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: widget.isSelected ? colorScheme.onPrimary : colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Category Chip with Icon and smooth animations
class _CategoryChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
          child: Builder(
            builder: (context) {
              final colorScheme = Theme.of(context).colorScheme;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.isSelected ? colorScheme.primary : colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.isSelected ? colorScheme.primary : theme.dividerColor,
                  ),
                  boxShadow: widget.isSelected
                      ? [BoxShadow(color: colorScheme.primary.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        widget.icon,
                        key: ValueKey(widget.isSelected),
                        size: 16,
                        color: widget.isSelected ? colorScheme.onPrimary : colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      style: theme.textTheme.labelMedium!.copyWith(
                        color: widget.isSelected ? colorScheme.onPrimary : colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                      child: Text(widget.label),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Section Header
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionHeader({
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Featured Experience Card - Large immersive card with smooth interactions
class _FeaturedExperienceCard extends StatefulWidget {
  final ActivityModel activity;

  const _FeaturedExperienceCard({required this.activity});

  @override
  State<_FeaturedExperienceCard> createState() => _FeaturedExperienceCardState();
}

class _FeaturedExperienceCardState extends State<_FeaturedExperienceCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _elevationAnimation = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewUrl = widget.activity.imageUrls.isNotEmpty 
        ? widget.activity.imageUrls.first 
        : widget.activity.imageUrl;
    final isNetwork = previewUrl.startsWith('http');
    final likeService = context.watch<LikeService>();
    final auth = context.read<AuthService>();
    final isLiked = likeService.isLiked(widget.activity.id);

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: () {
        HapticFeedback.lightImpact();
        context.pushNamed('activity', pathParameters: {'id': widget.activity.id});
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final colorScheme = Theme.of(context).colorScheme;
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 280,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06 + _elevationAnimation.value * 0.01),
                    blurRadius: 12 + _elevationAnimation.value,
                    offset: Offset(0, 4 + _elevationAnimation.value * 0.5),
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: Builder(
          builder: (context) {
            final colorScheme = Theme.of(context).colorScheme;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Large immersive image with Hero
                Expanded(
                  child: Hero(
                    tag: 'activity_${widget.activity.id}',
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          child: _CachedActivityImage(
                            imageUrl: previewUrl,
                            isNetwork: isNetwork,
                            width: 280,
                            fit: BoxFit.cover,
                          ),
                        ),
                        // Subtle gradient
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.4),
                                ],
                                stops: const [0.5, 1.0],
                              ),
                            ),
                          ),
                        ),
                        // Save button with animation
                        Positioned(
                          top: 12,
                          right: 12,
                          child: _AnimatedSaveButton(
                            isLiked: isLiked,
                            onTap: () async {
                              final userId = auth.currentUser?.id;
                              if (userId == null) return;
                              HapticFeedback.mediumImpact();
                              await context.read<LikeService>().toggleLike(userId, widget.activity.id);
                            },
                          ),
                        ),
                        // Price tag
                        Positioned(
                          bottom: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '\$${widget.activity.price.toStringAsFixed(0)}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.activity.category.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.secondary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.activity.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 14, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.activity.location,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.star_rounded, size: 14, color: colorScheme.secondary),
                          const SizedBox(width: 2),
                          Text(
                            widget.activity.rating.toString(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// Animated Save Button with bounce effect
class _AnimatedSaveButton extends StatefulWidget {
  final bool isLiked;
  final VoidCallback onTap;

  const _AnimatedSaveButton({required this.isLiked, required this.onTap});

  @override
  State<_AnimatedSaveButton> createState() => _AnimatedSaveButtonState();
}

class _AnimatedSaveButtonState extends State<_AnimatedSaveButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant _AnimatedSaveButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLiked != oldWidget.isLiked && widget.isLiked) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _bounceAnimation,
        builder: (context, child) => Transform.scale(
          scale: _bounceAnimation.value,
          child: child,
        ),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              widget.isLiked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              key: ValueKey(widget.isLiked),
              color: widget.isLiked ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.4),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

// Cached Activity Image Widget
class _CachedActivityImage extends StatelessWidget {
  final String imageUrl;
  final bool isNetwork;
  final double? width;
  final double? height;
  final BoxFit fit;

  const _CachedActivityImage({
    required this.imageUrl,
    required this.isNetwork,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    if (isNetwork) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          color: colorScheme.primary.withValues(alpha: 0.08),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: width,
          height: height,
          color: colorScheme.primary.withValues(alpha: 0.08),
          child: Icon(Icons.image_not_supported_outlined, color: colorScheme.onSurface.withValues(alpha: 0.4)),
        ),
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 100),
      );
    }
    return Image.asset(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
    );
  }
}

// Compact Experience Card with smooth interactions
class _CompactExperienceCard extends StatefulWidget {
  final ActivityModel activity;

  const _CompactExperienceCard({required this.activity});

  @override
  State<_CompactExperienceCard> createState() => _CompactExperienceCardState();
}

class _CompactExperienceCardState extends State<_CompactExperienceCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewUrl = widget.activity.imageUrls.isNotEmpty 
        ? widget.activity.imageUrls.first 
        : widget.activity.imageUrl;
    final isNetwork = previewUrl.startsWith('http');
    final likeService = context.watch<LikeService>();
    final auth = context.read<AuthService>();
    final isLiked = likeService.isLiked(widget.activity.id);

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: () {
        HapticFeedback.lightImpact();
        context.pushNamed('activity', pathParameters: {'id': widget.activity.id});
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: Builder(
          builder: (context) {
            final colorScheme = Theme.of(context).colorScheme;
            return Container(
              height: 120,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Image with Hero animation
                  Hero(
                    tag: 'activity_compact_${widget.activity.id}',
                    child: ClipRRect(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                      child: SizedBox(
                        width: 120,
                        height: 120,
                        child: _CachedActivityImage(
                          imageUrl: previewUrl,
                          isNetwork: isNetwork,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.activity.category.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.secondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.activity.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 12, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widget.activity.location,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                '\$${widget.activity.price.toStringAsFixed(0)}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.star_rounded, size: 12, color: colorScheme.secondary),
                              const SizedBox(width: 2),
                              Text(
                                widget.activity.rating.toString(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              if (widget.activity.spotsLeft <= 5)
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.8, end: 1.0),
                                  duration: const Duration(milliseconds: 600),
                                  curve: Curves.elasticOut,
                                  builder: (context, value, child) => Transform.scale(
                                    scale: value,
                                    child: child,
                                  ),
                                  child: Text(
                                    '${widget.activity.spotsLeft} spots left',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.secondary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Animated save button
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _SmallSaveButton(
                      isLiked: isLiked,
                      onTap: () async {
                        final userId = auth.currentUser?.id;
                        if (userId == null) return;
                        HapticFeedback.selectionClick();
                        await context.read<LikeService>().toggleLike(userId, widget.activity.id);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// Small animated save button for compact cards
class _SmallSaveButton extends StatefulWidget {
  final bool isLiked;
  final VoidCallback onTap;

  const _SmallSaveButton({required this.isLiked, required this.onTap});

  @override
  State<_SmallSaveButton> createState() => _SmallSaveButtonState();
}

class _SmallSaveButtonState extends State<_SmallSaveButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 0.85), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant _SmallSaveButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLiked != oldWidget.isLiked && widget.isLiked) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: AnimatedBuilder(
          animation: _bounceAnimation,
          builder: (context, child) => Transform.scale(
            scale: _bounceAnimation.value,
            child: child,
          ),
          child: Builder(
            builder: (context) {
              final colorScheme = Theme.of(context).colorScheme;
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: child,
                ),
                child: Icon(
                  widget.isLiked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  key: ValueKey(widget.isLiked),
                  color: widget.isLiked ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.4),
                  size: 22,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Medium Experience Card with smooth interactions
class _MediumExperienceCard extends StatefulWidget {
  final ActivityModel activity;

  const _MediumExperienceCard({required this.activity});

  @override
  State<_MediumExperienceCard> createState() => _MediumExperienceCardState();
}

class _MediumExperienceCardState extends State<_MediumExperienceCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewUrl = widget.activity.imageUrls.isNotEmpty 
        ? widget.activity.imageUrls.first 
        : widget.activity.imageUrl;
    final isNetwork = previewUrl.startsWith('http');

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: () {
        HapticFeedback.lightImpact();
        context.pushNamed('activity', pathParameters: {'id': widget.activity.id});
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: Builder(
          builder: (context) {
            final colorScheme = Theme.of(context).colorScheme;
            return Container(
              width: 200,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: SizedBox(
                            width: 200,
                            height: double.infinity,
                            child: _CachedActivityImage(
                              imageUrl: previewUrl,
                              isNetwork: isNetwork,
                              width: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              '\$${widget.activity.price.toStringAsFixed(0)}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.activity.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.schedule_outlined, size: 12, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                            const SizedBox(width: 4),
                            Text(
                              widget.activity.duration,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// Empty State
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 40, color: colorScheme.primary),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  actionLabel!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Backwards compatibility exports
class CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => _CategoryChip(
    label: label,
    icon: icon,
    isSelected: isSelected,
    onTap: onTap,
  );
}

class ActivityCard extends StatelessWidget {
  final ActivityModel activity;
  const ActivityCard({super.key, required this.activity});

  @override
  Widget build(BuildContext context) => _CompactExperienceCard(activity: activity);
}

class PremiumActivityCard extends StatelessWidget {
  final ActivityModel activity;
  const PremiumActivityCard({super.key, required this.activity});

  @override
  Widget build(BuildContext context) => _CompactExperienceCard(activity: activity);
}
