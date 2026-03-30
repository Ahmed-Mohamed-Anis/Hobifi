import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:hobby_haven/services/booking_service.dart';
import 'package:hobby_haven/services/auth_service.dart';
import 'package:hobby_haven/models/booking_model.dart';
import 'package:hobby_haven/services/activity_service.dart';
import 'package:hobby_haven/theme.dart';
import 'package:hobby_haven/nav.dart';
import 'package:intl/intl.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  String _selectedFilter = 'Upcoming';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = context.read<AuthService>();
      final bookingService = context.read<BookingService>();
      if (authService.currentUser != null) {
        bookingService.loadUserBookings(authService.currentUser!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bookingService = context.watch<BookingService>();
    final authService = context.watch<AuthService>();

    final allBookings = bookingService.getUserBookings(authService.currentUser?.id ?? '');
    final List<BookingModel> filteredBookings;
    switch (_selectedFilter) {
      case 'Completed':
        filteredBookings = allBookings.where((b) => b.status == BookingStatus.completed).toList();
      case 'Cancelled':
        filteredBookings = allBookings.where((b) => b.status == BookingStatus.cancelled).toList();
      default: // Upcoming
        filteredBookings = allBookings.where((b) => b.status == BookingStatus.confirmed || b.status == BookingStatus.pending).toList();
    }
    final upcomingBookings = allBookings.where((b) => b.status == BookingStatus.confirmed || b.status == BookingStatus.pending).toList();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: AppSpacing.paddingLg,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('My Hobbies', style: theme.textTheme.displayLarge?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface)),
                            Text('You have ${upcomingBookings.length} upcoming activities', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                          ],
                        ),
                      ],
                    ),
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: theme.colorScheme.surface,
                      backgroundImage: (authService.currentUser?.avatarUrl != null && (authService.currentUser!.avatarUrl!.startsWith('http') || authService.currentUser!.avatarUrl!.startsWith('https')))
                          ? NetworkImage(authService.currentUser!.avatarUrl!)
                          : null,
                      child: (authService.currentUser?.avatarUrl == null)
                          ? Icon(Icons.person_rounded, color: theme.colorScheme.primary)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: AppSpacing.horizontalLg + AppSpacing.verticalMd,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Upcoming'),
                      selected: _selectedFilter == 'Upcoming',
                      onSelected: (val) => setState(() => _selectedFilter = 'Upcoming'),
                      selectedColor: theme.colorScheme.primary,
                      labelStyle: TextStyle(color: _selectedFilter == 'Upcoming' ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Completed'),
                      selected: _selectedFilter == 'Completed',
                      onSelected: (val) => setState(() => _selectedFilter = 'Completed'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Cancelled'),
                      selected: _selectedFilter == 'Cancelled',
                      onSelected: (val) => setState(() => _selectedFilter = 'Cancelled'),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: AppSpacing.horizontalLg,
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => BookingCard(booking: filteredBookings[index]),
                  childCount: filteredBookings.length,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                margin: AppSpacing.paddingLg,
                padding: AppSpacing.paddingXl,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: theme.colorScheme.secondary.withValues(alpha: 0.19)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.explore_rounded, color: theme.colorScheme.tertiary, size: 40),
                    const SizedBox(height: AppSpacing.md),
                    Text('Looking for more?', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 8),
                    Text('Discover new hobbies tailored to your interests in the feed.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)), textAlign: TextAlign.center),
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
            ),
          ],
        ),
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
    final statusBg = booking.status == BookingStatus.confirmed
        ? const Color(0xFF00FF94)
        : booking.status == BookingStatus.cancelled
            ? colorScheme.error.withValues(alpha: 0.2)
            : const Color(0xFFFFE500);
    final statusTextColor = booking.status == BookingStatus.cancelled
        ? colorScheme.error
        : const Color(0xFF004D2D);
    final isNetwork = booking.activityImage.startsWith('http');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.13),
            offset: const Offset(0, 8),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: isNetwork
                    ? Image.network(booking.activityImage, height: 160, width: double.infinity, fit: BoxFit.cover)
                    : Image.asset(booking.activityImage, height: 160, width: double.infinity, fit: BoxFit.cover),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(booking.status.name.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(color: statusTextColor, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(booking.activityTitle, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text('\$${booking.price.toStringAsFixed(0)}', style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.tertiary, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_rounded, color: colorScheme.onSurface.withValues(alpha: 0.6), size: 16),
                    const SizedBox(width: 4),
                    Text(booking.location, style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.6))),
                  ],
                ),
                Divider(height: 24, color: theme.dividerColor),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Icon(Icons.event_available_rounded, color: colorScheme.primary, size: 20),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat('MMM dd, yyyy').format(booking.dateTime), style: theme.textTheme.labelMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w600)),
                            Text(DateFormat('hh:mm a').format(booking.dateTime), style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.6))),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (isUpcoming)
                          TextButton(
                            onPressed: () => _showCancelDialog(context),
                            style: TextButton.styleFrom(
                              backgroundColor: colorScheme.error.withValues(alpha: 0.1),
                              foregroundColor: colorScheme.error,
                            ),
                            child: const Text('Cancel'),
                          ),
                        if (isUpcoming) const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => context.push('${AppRoutes.ticket}/${booking.id}'),
                          style: TextButton.styleFrom(
                            backgroundColor: colorScheme.primary.withValues(alpha: 0.13),
                            foregroundColor: colorScheme.primary,
                          ),
                          child: const Text('View Ticket'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
