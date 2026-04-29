import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hobby_haven/services/booking_service.dart';
import 'package:hobby_haven/services/auth_service.dart';
import 'package:hobby_haven/models/booking_model.dart';
import 'package:hobby_haven/services/activity_service.dart';
import 'package:hobby_haven/theme.dart';
import 'package:hobby_haven/nav.dart';
import 'package:hobby_haven/screens/user/saved_screen.dart' show SavedContent;
import 'package:hobby_haven/widgets/hobifi_empty_state.dart';
import 'package:hobby_haven/widgets/hobifi_shimmer.dart';
import 'package:intl/intl.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = context.read<AuthService>();
      final bookingService = context.read<BookingService>();
      if (authService.currentUser != null) {
        bookingService.loadUserBookings(authService.currentUser!.id);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bookingService = context.watch<BookingService>();
    final authService = context.watch<AuthService>();

    final allBookings =
        bookingService.getUserBookings(authService.currentUser?.id ?? '');
    final upcomingBookings = allBookings
        .where((b) => b.status == BookingStatus.confirmed)
        .toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: AppSpacing.paddingLg,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Hobbies',
                          style: theme.textTheme.displayLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'You have ${upcomingBookings.length} upcoming activities',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.colorScheme.surface,
                    backgroundImage: (authService.currentUser?.avatarUrl !=
                                null &&
                            (authService.currentUser!.avatarUrl!
                                    .startsWith('http') ||
                                authService.currentUser!.avatarUrl!
                                    .startsWith('https')))
                        ? NetworkImage(authService.currentUser!.avatarUrl!)
                        : null,
                    child: (authService.currentUser?.avatarUrl == null)
                        ? Icon(Icons.person_rounded,
                            color: theme.colorScheme.primary)
                        : null,
                  ),
                ],
              ),
            ),

            // Tabs
            TabBar(
              controller: _tabController,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor:
                  theme.colorScheme.onSurface.withValues(alpha: 0.5),
              indicatorColor: theme.colorScheme.primary,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Upcoming'),
                Tab(text: 'Liked'),
              ],
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _UpcomingList(
                    bookings: upcomingBookings,
                    isLoading: bookingService.isLoading,
                  ),
                  const SavedContent(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingList extends StatelessWidget {
  final List<BookingModel> bookings;
  final bool isLoading;

  const _UpcomingList({required this.bookings, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return ListView.builder(
        itemCount: 3,
        itemBuilder: (_, __) => Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: HobifiShimmer.listTile(),
        ),
      );
    }

    Future<void> refresh() async {
      final authService = context.read<AuthService>();
      final bookingService = context.read<BookingService>();
      if (authService.currentUser != null) {
        await bookingService.loadUserBookings(authService.currentUser!.id);
      }
    }

    if (bookings.isEmpty) {
      return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: HobifiEmptyState(
                icon: Icons.confirmation_number_outlined,
                title: 'No bookings yet',
                subtitle:
                    'Explore activities and book your first experience!',
                actionLabel: 'Explore Activities',
                onAction: () => context.go(AppRoutes.feed),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: AppSpacing.horizontalLg,
        children: [
          ...bookings.map((b) => BookingCard(booking: b)),
          // Explore more banner
          Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            padding: AppSpacing.paddingXl,
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: theme.colorScheme.secondary.withValues(alpha: 0.19),
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.explore_rounded,
                    color: theme.colorScheme.tertiary, size: 40),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Looking for more?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Discover new hobbies tailored to your interests in the feed.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: () => context.go(AppRoutes.feed),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.tertiary,
                    foregroundColor: theme.colorScheme.onSurface,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text('Explore Activities'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BookingCard extends StatelessWidget {
  final BookingModel booking;

  const BookingCard({super.key, required this.booking});

  bool get _isUpcoming =>
      booking.status == BookingStatus.confirmed ||
      booking.status == BookingStatus.pending;

  Color _statusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.confirmed:
        return const Color(0xFF9BC53D);
      case BookingStatus.pending:
        return const Color(0xFFE88B3C);
      case BookingStatus.cancelled:
        return const Color(0xFFE53935);
      case BookingStatus.completed:
        return const Color(0xFF9E9E9E);
    }
  }

  Future<void> _showCancelDialog(BuildContext context) async {
    // 24h cancellation policy check
    final hoursUntil = booking.dateTime.difference(DateTime.now()).inHours;
    final isLate = hoursUntil < 24;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: Text(isLate ? 'Late Cancellation' : 'Cancel Booking'),
          content: Text(
            isLate
                ? 'This activity is less than 24 hours away. Cancelling now means no refund. Are you sure?'
                : 'Are you sure you want to cancel "${booking.activityTitle}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep Booking'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
              child: const Text('Cancel Booking'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      try {
        final bookingService = context.read<BookingService>();
        final activityService = context.read<ActivityService>();

        final result = await bookingService.cancelBookingServerSide(booking.id);

        await activityService.refreshActivities();

        if (context.mounted) {
          final message = result['message'] as String? ?? 'Booking cancelled';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to cancel: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isUpcoming = _isUpcoming;
    final statusColor = _statusColor(booking.status);
    final isNetwork = booking.activityImage.startsWith('http');

    return GestureDetector(
      onTap: () => context.push('${AppRoutes.ticket}/${booking.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: isNetwork
                    ? CachedNetworkImage(
                        imageUrl: booking.activityImage,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => HobifiShimmer.box(80, 80, radius: 12),
                        errorWidget: (_, __, ___) => Container(
                          width: 80,
                          height: 80,
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(Icons.image_not_supported_outlined,
                              color: colorScheme.onSurface.withValues(alpha: 0.4)),
                        ),
                      )
                    : Image.asset(
                        booking.activityImage,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.activityTitle,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEE, MMM d • h:mm a').format(booking.dateTime),
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
                            booking.location,
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

              // Right column: status badge + cancel action
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      booking.status.name[0].toUpperCase() + booking.status.name.substring(1),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isUpcoming) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _showCancelDialog(context),
                      child: Text(
                        'Cancel',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
