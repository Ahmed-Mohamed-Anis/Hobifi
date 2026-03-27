import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:hobby_haven/services/booking_service.dart';
import 'package:hobby_haven/models/booking_model.dart';
import 'package:hobby_haven/theme.dart';
import 'package:hobby_haven/nav.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TicketScreen extends StatelessWidget {
  final String bookingId;

  const TicketScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bookingService = context.watch<BookingService>();

    // Find the booking
    BookingModel? booking;
    try {
      booking = bookingService.bookings.firstWhere((b) => b.id == bookingId);
    } catch (_) {
      booking = null;
    }

    if (booking == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.go(AppRoutes.profile),
          ),
        ),
        body: const Center(child: Text('Ticket not found')),
      );
    }
    final dateStr = DateFormat('EEE, MMM d, yyyy').format(booking.dateTime);
    final timeStr = DateFormat('h:mm a').format(booking.dateTime);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.lightPrimaryText),
          onPressed: () => context.go(AppRoutes.profile),
        ),
        title: Text(
          'Your Ticket',
          style: theme.textTheme.titleLarge?.copyWith(
            color: AppColors.lightPrimaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: const [],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingLg,
        child: Column(
          children: [
            // Ticket Card
            Container(
              decoration: BoxDecoration(
                color: AppColors.lightSurface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    offset: const Offset(0, 8),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header Image
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: Stack(
                      children: [
                        booking.activityImage.startsWith('http')
                            ? Image.network(
                                booking.activityImage,
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : Image.asset(
                                booking.activityImage,
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.6),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          left: 16,
                          right: 16,
                          child: Text(
                            booking.activityTitle,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getStatusColor(booking.status),
                              borderRadius: BorderRadius.circular(AppRadius.full),
                            ),
                            child: Text(
                              _getStatusText(booking.status),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Dashed divider
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: List.generate(
                        30,
                        (index) => Expanded(
                          child: Container(
                            height: 2,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            color: index.isEven
                                ? AppColors.lightDivider
                                : Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Ticket Details
                  Padding(
                    padding: AppSpacing.paddingLg,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoItem(
                                context,
                                icon: Icons.calendar_today_rounded,
                                label: 'Date',
                                value: dateStr,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _buildInfoItem(
                                context,
                                icon: Icons.access_time_rounded,
                                label: 'Time',
                                value: timeStr,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _buildInfoItem(
                          context,
                          icon: Icons.location_on_rounded,
                          label: 'Location',
                          value: booking.location,
                          fullWidth: true,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoItem(
                                context,
                                icon: Icons.confirmation_number_rounded,
                                label: 'Ticket #',
                                value: booking.id.substring(0, 8).toUpperCase(),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _buildInfoItem(
                                context,
                                icon: Icons.paid_rounded,
                                label: 'Amount',
                                value: '\$${booking.price.toStringAsFixed(2)}',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // QR Code Section
                  Container(
                    padding: AppSpacing.paddingLg,
                    decoration: const BoxDecoration(
                      color: AppColors.lightBackground,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Scan at entry',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.lightSecondaryText,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: QrImageView(
                            data: 'HOBBYTICKET:${booking.id}',
                            version: QrVersions.auto,
                            size: 160,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: AppColors.lightPrimaryText,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: AppColors.lightPrimaryText,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          booking.id.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.lightHint,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.go(AppRoutes.feed),
                icon: const Icon(Icons.explore_rounded),
                label: const Text('Explore More'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.lightPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Help Section
            Container(
              padding: AppSpacing.paddingMd,
              decoration: BoxDecoration(
                color: AppColors.lightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.lightDivider),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.lightPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.help_outline_rounded,
                      color: AppColors.lightPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Need help?',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppColors.lightPrimaryText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Contact support for any issues',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.lightSecondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.lightHint,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool fullWidth = false,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.lightPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.lightPrimary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.lightHint,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.lightPrimaryText,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: fullWidth ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.confirmed:
        return AppColors.lightSuccess;
      case BookingStatus.completed:
        return AppColors.lightPrimary;
      case BookingStatus.pending:
        return AppColors.lightAccent;
      case BookingStatus.cancelled:
        return AppColors.lightError;
    }
  }

  String _getStatusText(BookingStatus status) {
    switch (status) {
      case BookingStatus.confirmed:
        return 'CONFIRMED';
      case BookingStatus.completed:
        return 'COMPLETED';
      case BookingStatus.pending:
        return 'PENDING';
      case BookingStatus.cancelled:
        return 'CANCELLED';
    }
  }
}
