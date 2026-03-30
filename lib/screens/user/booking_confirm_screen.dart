import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:hobby_haven/models/activity_model.dart';
import 'package:hobby_haven/models/booking_model.dart';
import 'package:hobby_haven/services/auth_service.dart';
import 'package:hobby_haven/services/booking_service.dart';
import 'package:hobby_haven/services/activity_service.dart';
import 'package:hobby_haven/services/payment_service.dart';
import 'package:hobby_haven/supabase/supabase_config.dart';
import 'package:hobby_haven/nav.dart';
import 'package:hobby_haven/theme.dart';

class BookingConfirmScreen extends StatefulWidget {
  final String activityId;

  const BookingConfirmScreen({super.key, required this.activityId});

  @override
  State<BookingConfirmScreen> createState() => _BookingConfirmScreenState();
}

class _BookingConfirmScreenState extends State<BookingConfirmScreen> {
  bool _isProcessing = false;

  Future<void> _confirmAndPay(ActivityModel activity) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final authService = context.read<AuthService>();
    final bookingService = context.read<BookingService>();
    final paymentService = context.read<PaymentService>();
    final activityService = context.read<ActivityService>();

    final user = authService.currentUser;
    if (user == null) return;

    String? bookingId;

    try {
      // Atomically reserve spot + create booking in one transaction
      final result = await bookingService.createBookingAtomic(
        userId: user.id,
        activityId: activity.id,
        activityTitle: activity.title,
        activityImage: activity.imageUrl,
        location: activity.location,
        price: activity.price,
        dateTime: activity.dateTime,
      );

      if (result['ok'] != true) {
        await activityService.refreshActivities();
        if (mounted) {
          final reason = result['reason'] as String? ?? 'unknown';
          final message = reason == 'no_spots'
              ? 'Sorry, this activity just sold out!'
              : 'Could not create booking. Please try again.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      bookingId = result['booking_id'] as String;

      // Initialize payment
      final paymentData = await paymentService.initializePayment(
        bookingId: bookingId,
        userId: user.id,
        activityId: activity.id,
        amount: activity.price,
        activityTitle: activity.title,
        userEmail: user.email,
        userName: user.name,
        userPhone: user.phone ?? '',
      );

      if (mounted) {
        context.push(
          '${AppRoutes.payment}/$bookingId',
          extra: {
            'paymentUrl': paymentData['iframe_url'],
            'activityId': activity.id,
            'activityTitle': activity.title,
            'amount': activity.price,
          },
        );
      }
    } catch (e) {
      debugPrint('Payment initialization failed: $e');
      // If booking was created but payment init failed, release the spot
      if (bookingId != null) {
        try {
          await SupabaseConfig.client.rpc(
            'release_spot',
            params: {'p_activity_id': activity.id},
          );
          await bookingService.updateBookingStatus(bookingId, BookingStatus.cancelled);
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process booking: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final activityService = context.watch<ActivityService>();
    final activity = activityService.getActivityById(widget.activityId);

    if (activity == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Activity not found')),
      );
    }

    final activityDate = activity.startAt ?? activity.dateTime;
    final platformFee = activity.price * 0.10;
    final total = activity.price + platformFee;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Confirm Booking'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Activity summary card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                            offset: const Offset(0, 2),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              activity.imageUrl,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 80,
                                height: 80,
                                color: colorScheme.primary.withValues(alpha: 0.1),
                                child: Icon(Icons.image, color: colorScheme.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    activity.category,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  activity.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Booking details
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                            offset: const Offset(0, 2),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _DetailRow(
                            icon: Icons.calendar_today_rounded,
                            label: DateFormat('EEEE, MMM d').format(activityDate),
                          ),
                          const SizedBox(height: 14),
                          _DetailRow(
                            icon: Icons.access_time_rounded,
                            label: DateFormat('h:mm a').format(activityDate),
                          ),
                          const SizedBox(height: 14),
                          _DetailRow(
                            icon: Icons.location_on_rounded,
                            label: activity.location,
                          ),
                          const SizedBox(height: 14),
                          _DetailRow(
                            icon: Icons.person_rounded,
                            label: '1 person',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Price breakdown
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                            offset: const Offset(0, 2),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _PriceRow(
                            label: 'Activity',
                            amount: 'EGP ${activity.price.toStringAsFixed(2)}',
                            theme: theme,
                          ),
                          const SizedBox(height: 10),
                          _PriceRow(
                            label: 'Platform fee',
                            amount: 'EGP ${platformFee.toStringAsFixed(2)}',
                            theme: theme,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Divider(color: colorScheme.outline.withValues(alpha: 0.2)),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'EGP ${total.toStringAsFixed(2)}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Cancellation policy
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 20, color: colorScheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Free cancellation up to 24 hours before the activity',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Confirm & Pay button
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1)),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: _isProcessing ? null : () => _confirmAndPay(activity),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                    ),
                    child: _isProcessing
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.lock_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Confirm & Pay',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String amount;
  final ThemeData theme;

  const _PriceRow({required this.label, required this.amount, required this.theme});

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        Text(
          amount,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
