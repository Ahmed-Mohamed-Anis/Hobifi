import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hobby_haven/models/booking_model.dart';
import 'package:hobby_haven/services/auth_service.dart';
import 'package:hobby_haven/services/booking_service.dart';
import 'package:hobby_haven/theme.dart';
import 'package:hobby_haven/widgets/hobifi_shimmer.dart';
import 'package:hobby_haven/widgets/hobifi_empty_state.dart';

class BusinessBookingsScreen extends StatefulWidget {
  const BusinessBookingsScreen({super.key});

  @override
  State<BusinessBookingsScreen> createState() => _BusinessBookingsScreenState();
}

class _BusinessBookingsScreenState extends State<BusinessBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabLabels = ['All', 'Confirmed', 'Pending', 'Completed', 'Cancelled'];
  static const _statusFilters = [
    null,
    BookingStatus.confirmed,
    BookingStatus.pending,
    BookingStatus.completed,
    BookingStatus.cancelled,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthService>().currentUser?.id;
      if (userId != null) {
        context.read<BookingService>().loadBusinessBookingsAll(userId);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<BookingModel> _filtered(List<BookingModel> all, BookingStatus? status) =>
      status == null ? all : all.where((b) => b.status == status).toList();

  void _showDetail(BuildContext context, BookingModel booking) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, sc) => SingleChildScrollView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Booking Detail',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _DetailRow(label: 'Activity', value: booking.activityTitle),
              _DetailRow(
                label: 'Date & Time',
                value: DateFormat('EEE, MMM d y · h:mm a').format(booking.dateTime),
              ),
              _DetailRow(label: 'Amount', value: 'EGP ${booking.price.toStringAsFixed(2)}'),
              _DetailRow(
                label: 'Booking Code',
                value: '#${booking.id.substring(0, 8).toUpperCase()}',
              ),
              _DetailRow(label: 'Status', value: booking.status.name.toUpperCase()),
              _DetailRow(
                label: 'Booked on',
                value: DateFormat('MMM d, y').format(booking.createdAt),
              ),
              if (booking.status == BookingStatus.confirmed) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      final bookingSvc = context.read<BookingService>();
                      final authSvc = context.read<AuthService>();
                      Navigator.of(ctx).pop();
                      final result = await bookingSvc.cancelBookingBusiness(booking.id);
                      if (result['success'] != true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(result['error'] as String? ?? 'Cancellation failed')),
                        );
                        return;
                      }
                      final userId = authSvc.currentUser?.id;
                      if (userId != null) {
                        await bookingSvc.loadBusinessBookingsAll(userId);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      side: BorderSide(color: colorScheme.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel Booking'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookingService = context.watch<BookingService>();
    final allBookings = bookingService.businessBookings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Bookings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
        ),
      ),
      body: bookingService.isLoading && allBookings.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: List.generate(5, (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: HobifiShimmer.listTile(),
                )),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: List.generate(_statusFilters.length, (i) {
                final items = _filtered(allBookings, _statusFilters[i]);
                if (items.isEmpty) {
                  return HobifiEmptyState(
                    icon: Icons.event_busy_rounded,
                    title: _statusFilters[i] == null ? 'No bookings yet' : 'No ${_statusFilters[i]!.name} bookings',
                    subtitle: _statusFilters[i] == null
                        ? 'Bookings appear here after guests book your activities.'
                        : null,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    final userId = context.read<AuthService>().currentUser?.id;
                    if (userId != null) {
                      await context.read<BookingService>().loadBusinessBookingsAll(userId);
                    }
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, idx) {
                      final b = items[idx];
                      return _BookingRow(booking: b, onTap: () => _showDetail(context, b));
                    },
                  ),
                );
              }),
            ),
    );
  }
}

class _BookingRow extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback onTap;

  const _BookingRow({required this.booking, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final statusColor = switch (booking.status) {
      BookingStatus.confirmed => colorScheme.primary,
      BookingStatus.completed => AppColors.lime,
      BookingStatus.cancelled => colorScheme.error,
      BookingStatus.pending => AppColors.orange,
    };

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: booking.activityImage,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => HobifiShimmer.box(56, 56),
                  errorWidget: (_, __, ___) => Container(
                    width: 56,
                    height: 56,
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(Icons.image_rounded, color: colorScheme.outline),
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('MMM d · h:mm a').format(booking.dateTime),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'EGP ${booking.price.toStringAsFixed(0)}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Text(
                      booking.status.name,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: statusColor, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.5)),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
