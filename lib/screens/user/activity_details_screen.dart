import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hobby_haven/models/activity_model.dart';
import 'package:hobby_haven/services/activity_service.dart';
import 'package:hobby_haven/services/auth_service.dart';
import 'package:hobby_haven/services/like_service.dart';
import 'package:hobby_haven/services/rating_service.dart';
import 'package:hobby_haven/services/booking_service.dart';
import 'package:hobby_haven/models/rating_model.dart';
import 'package:hobby_haven/supabase/supabase_config.dart';
import 'package:hobby_haven/widgets/hobifi_shimmer.dart';
import 'package:hobby_haven/nav.dart';
import 'package:hobby_haven/theme.dart';

class ActivityDetailsScreen extends StatefulWidget {
  final String activityId;

  const ActivityDetailsScreen({super.key, required this.activityId});

  @override
  State<ActivityDetailsScreen> createState() => _ActivityDetailsScreenState();
}

class _ActivityDetailsScreenState extends State<ActivityDetailsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showTitle = false;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RatingService>().loadActivityReviews(widget.activityId);
    });
  }

  void _onScroll() {
    // Show title when hero is mostly scrolled away (~180px into scroll)
    final shouldShow = _scrollController.offset > 180;
    if (shouldShow != _showTitle) {
      setState(() => _showTitle = shouldShow);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openDirections(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activityService = context.watch<ActivityService>();
    final activity = activityService.getActivityById(widget.activityId);
    final likeService = context.watch<LikeService>();
    final auth = context.read<AuthService>();

    if (activity == null) {
      return _buildLoadingState(context, theme, colorScheme);
    }

    final isLiked = likeService.isLiked(activity.id);
    final heroImageUrl = activity.imageUrls.isNotEmpty
        ? activity.imageUrls.first
        : activity.imageUrl;

    final start = activity.startAt ?? activity.dateTime;
    final end = activity.endAt ?? activity.dateTime.add(const Duration(hours: 2));
    final dateStr = DateFormat('EEE, MMM d').format(start);
    final timeStr =
        '${DateFormat('h:mm a').format(start)} – ${DateFormat('h:mm a').format(end)}';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // ── Collapsing hero header ──────────────────────────────────────
            SliverAppBar(
              expandedHeight: MediaQuery.of(context).size.height * 0.4,
              pinned: true,
              stretch: true,
              backgroundColor: colorScheme.surface,
              title: AnimatedOpacity(
                opacity: _showTitle ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  activity.title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: _CircleButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => context.pop(),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _CircleButton(
                    icon: Icons.share_rounded,
                    onTap: () {
                      SharePlus.instance.share(
                        ShareParams(
                          text:
                              'Check out "${activity.title}" on HOBIFI!\n${activity.location} — EGP ${activity.price.toStringAsFixed(0)}/person',
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _CircleButton(
                    icon: isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    iconColor:
                        isLiked ? AppColors.likeRed : null,
                    onTap: () async {
                      final userId = auth.currentUser?.id;
                      if (userId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Please sign in to like activities.')),
                        );
                        return;
                      }
                      await context
                          .read<LikeService>()
                          .toggleLike(userId, activity.id);
                    },
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Hero image
                    CachedNetworkImage(
                      imageUrl: heroImageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: colorScheme.surfaceContainerHighest,
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(Icons.image_not_supported_outlined,
                            color: colorScheme.onSurface.withValues(alpha: 0.3),
                            size: 48),
                      ),
                    ),
                    // Gradient scrim
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x4D000000), // black 30%
                            Colors.transparent,
                            Color(0x80000000), // black 50%
                          ],
                          stops: [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Scrollable body ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Title + Rating Row
                    const SizedBox(height: 24),
                    Text(
                      activity.title,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (activity.reviewCount > 0)
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              color: colorScheme.tertiary, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            activity.rating.toStringAsFixed(1),
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${activity.reviewCount} reviews)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'New — no reviews yet',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.tertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                    // 2. Quick Info Pills
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoPill(
                            icon: Icons.calendar_today_rounded,
                            label: dateStr),
                        _InfoPill(
                            icon: Icons.access_time_rounded, label: timeStr),
                        _InfoPill(
                            icon: Icons.location_on_rounded,
                            label: activity.location),
                        _InfoPill(
                            icon: Icons.label_rounded,
                            label: activity.category),
                      ],
                    ),

                    // Map section (only when coordinates available)
                    if (activity.latitude != null) ...[
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          height: 200,
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter: LatLng(activity.latitude!, activity.longitude!),
                              initialZoom: 15,
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.none,
                              ),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.hobifi.app',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(activity.latitude!, activity.longitude!),
                                    child: const Icon(
                                      Icons.location_pin,
                                      color: Colors.red,
                                      size: 40,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () => _openDirections(
                            activity.latitude!,
                            activity.longitude!,
                          ),
                          icon: const Icon(Icons.directions_rounded),
                          label: const Text('Get Directions'),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],

                    // 3. Description
                    const SizedBox(height: 16),
                    Text(
                      activity.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            colorScheme.onSurface.withValues(alpha: 0.7),
                        height: 1.6,
                      ),
                      maxLines: _isExpanded ? null : 3,
                      overflow: _isExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                    ),
                    TextButton(
                      onPressed: () =>
                          setState(() => _isExpanded = !_isExpanded),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        _isExpanded ? 'Show less' : 'Read more',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    // 4. Host Card
                    const SizedBox(height: 16),
                    _HostInfoCard(businessId: activity.businessId),

                    // 5. Reviews Section
                    const SizedBox(height: 24),
                    _ReviewsSection(activity: activity),

                    // Bottom spacing for sticky bar
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),

        // ── Sticky Book Bar ─────────────────────────────────────────────────
        bottomNavigationBar: _StickyBookBar(activity: activity),
      ),
    );
  }

  Widget _buildLoadingState(
      BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.height * 0.4,
            pinned: true,
            backgroundColor: colorScheme.surface,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _CircleButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => context.pop(),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: HobifiShimmer(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.4,
                borderRadius: 0,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  HobifiShimmer(width: double.infinity, height: 28),
                  const SizedBox(height: 12),
                  HobifiShimmer(width: 160, height: 16),
                  const SizedBox(height: 20),
                  HobifiShimmer(width: double.infinity, height: 80),
                  const SizedBox(height: 16),
                  HobifiShimmer(width: double.infinity, height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Circle Action Button ──────────────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 20,
          color: iconColor ?? colorScheme.onSurface,
        ),
      ),
    );
  }
}

// ── Info Pill ─────────────────────────────────────────────────────────────────

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.1),
        ),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.6)),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Host Info Card ────────────────────────────────────────────────────────────

class _HostInfoCard extends StatefulWidget {
  final String businessId;
  const _HostInfoCard({required this.businessId});

  @override
  State<_HostInfoCard> createState() => _HostInfoCardState();
}

class _HostInfoCardState extends State<_HostInfoCard> {
  Map<String, dynamic>? _host;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadHost();
  }

  Future<void> _loadHost() async {
    try {
      final data = await SupabaseConfig.client
          .from('users')
          .select()
          .eq('id', widget.businessId)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _host = data;
          _loaded = true;
        });
      }
    } catch (e) {
      debugPrint('Failed to load host: $e');
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return HobifiShimmer(width: double.infinity, height: 72);
    if (_host == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final name = _host!['name'] as String? ?? 'Host';
    final avatarUrl = _host!['avatar_url'] as String?;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
            backgroundImage: (avatarUrl != null && avatarUrl.startsWith('http'))
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl == null
                ? Text(
                    initial,
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hosted by',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              Text(
                name,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Reviews Section ───────────────────────────────────────────────────────────

class _ReviewsSection extends StatefulWidget {
  final ActivityModel activity;
  const _ReviewsSection({required this.activity});

  @override
  State<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<_ReviewsSection> {
  final TextEditingController _commentController = TextEditingController();
  int _selectedStars = 0;
  bool _isSubmitting = false;
  bool _showReviewForm = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final auth = context.watch<AuthService>();
    final ratingService = context.watch<RatingService>();
    final userId = auth.currentUser?.id;

    final reviews =
        ratingService.getCachedActivityReviews(widget.activity.id);
    final reviewsWithComments = reviews
        .where((r) => r.comment != null && r.comment!.trim().isNotEmpty)
        .toList();

    // Star breakdown counts
    final Map<int, int> starCounts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in reviews) {
      final s = r.rating.clamp(1, 5);
      starCounts[s] = (starCounts[s] ?? 0) + 1;
    }
    final totalReviews = reviews.length;

    final userRating = userId != null
        ? ratingService.getUserRatingForActivity(userId, widget.activity.id)
        : null;

    // Pre-fill form
    if (userRating != null && _selectedStars == 0 && !_showReviewForm) {
      _selectedStars = userRating.rating;
      if (userRating.comment != null && _commentController.text.isEmpty) {
        _commentController.text = userRating.comment!;
      }
    }

    final bookingService = userId != null
        ? context.watch<BookingService>()
        : null;
    final hasBooked = bookingService != null
        ? bookingService.hasBookedActivity(userId!, widget.activity.id)
        : false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reviews',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),

        // Star breakdown
        if (totalReviews > 0) ...[
          ...List.generate(5, (i) {
            final star = 5 - i;
            final count = starCounts[star] ?? 0;
            final fraction =
                totalReviews > 0 ? count / totalReviews : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text(
                    '$star',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 6,
                        backgroundColor:
                            colorScheme.onSurface.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.tertiary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 24,
                    child: Text(
                      '$count',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
        ],

        // Rate & Review Card (only if signed in and booked, or has a rating)
        if (userId != null && (hasBooked || userRating != null)) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      userRating != null ? 'Your Review' : 'Rate & Review',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (userRating != null && !_showReviewForm)
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _showReviewForm = true;
                          _selectedStars = userRating.rating;
                          _commentController.text =
                              userRating.comment ?? '';
                        }),
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: const Text('Edit'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starValue = index + 1;
                    final isSelected = _selectedStars >= starValue ||
                        (userRating != null &&
                            !_showReviewForm &&
                            userRating.rating >= starValue);
                    return InkWell(
                      onTap: () => setState(() {
                        _selectedStars = starValue;
                        if (!_showReviewForm) _showReviewForm = true;
                      }),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, anim) =>
                              ScaleTransition(scale: anim, child: child),
                          child: Icon(
                            isSelected
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            key: ValueKey('$starValue-$isSelected'),
                            color: colorScheme.tertiary,
                            size: 40,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                if (userRating != null && !_showReviewForm) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'You rated ${userRating.rating} star${userRating.rating > 1 ? 's' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                  ),
                  if (userRating.comment != null &&
                      userRating.comment!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(userRating.comment!,
                          style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ],
                if (_showReviewForm ||
                    (userRating == null && _selectedStars > 0)) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _commentController,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: 'Share your experience (optional)...',
                      hintStyle: TextStyle(
                          color:
                              colorScheme.onSurface.withValues(alpha: 0.4)),
                      filled: true,
                      fillColor:
                          colorScheme.primary.withValues(alpha: 0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: colorScheme.outline
                                .withValues(alpha: 0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: colorScheme.outline
                                .withValues(alpha: 0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: colorScheme.primary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (_showReviewForm && userRating != null) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() {
                              _showReviewForm = false;
                              _selectedStars = userRating.rating;
                              _commentController.text =
                                  userRating.comment ?? '';
                            }),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              _selectedStars > 0 && !_isSubmitting
                                  ? () => _submitReview(userId)
                                  : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(
                                vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                )
                              : Text(userRating != null
                                  ? 'Update Review'
                                  : 'Submit Review'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Prompt to book before reviewing
        if (userId != null && !hasBooked && userRating == null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Icon(Icons.rate_review_outlined,
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                    size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Book this activity to leave a review',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Review cards
        if (reviewsWithComments.isNotEmpty) ...[
          Text(
            'Reviews (${reviewsWithComments.length})',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...reviewsWithComments
              .take(5)
              .map((review) => _ReviewCard(review: review)),
        ],
      ],
    );
  }

  Future<void> _submitReview(String userId) async {
    setState(() => _isSubmitting = true);
    try {
      final comment = _commentController.text.trim();
      await context.read<RatingService>().addOrUpdateRating(
            userId,
            widget.activity.id,
            _selectedStars,
            comment: comment.isNotEmpty ? comment : null,
          );
      if (mounted) {
        await Future.wait([
          context.read<RatingService>().loadActivityReviews(widget.activity.id, force: true),
          context.read<ActivityService>().refreshActivities(),
        ]);
      }
      if (mounted) {
        setState(() {
          _showReviewForm = false;
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit review')),
        );
      }
    }
  }
}

// ── Review Card ───────────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final RatingModel review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timeAgo = _formatTimeAgo(review.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Row(
                children: List.generate(
                    5,
                    (i) => Icon(
                          i < review.rating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: colorScheme.tertiary,
                          size: 16,
                        )),
              ),
              const Spacer(),
              Text(
                timeAgo,
                style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.comment!,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}

// ── Sticky Book Bar ───────────────────────────────────────────────────────────

class _StickyBookBar extends StatelessWidget {
  final ActivityModel activity;
  const _StickyBookBar({required this.activity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomPadding),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EGP ${activity.price.toStringAsFixed(0)}',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                'per person',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              if (activity.spotsLeft > 0 && activity.spotsLeft <= 5)
                Text(
                  'Only ${activity.spotsLeft} spot${activity.spotsLeft == 1 ? '' : 's'} left',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const Spacer(),
          FilledButton(
            onPressed: activity.spotsLeft > 0
                ? () => context
                    .push('${AppRoutes.bookingConfirm}/${activity.id}')
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              disabledBackgroundColor:
                  colorScheme.onSurface.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              activity.spotsLeft > 0 ? 'Book Now' : 'Fully Booked',
            ),
          ),
        ],
      ),
    );
  }
}
