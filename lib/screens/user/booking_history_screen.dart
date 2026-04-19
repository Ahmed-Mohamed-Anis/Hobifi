import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hobby_haven/services/booking_service.dart';
import 'package:hobby_haven/services/auth_service.dart';
import 'package:hobby_haven/models/booking_model.dart';
import 'package:hobby_haven/screens/user/bookings_screen.dart' show BookingCard;
import 'package:hobby_haven/widgets/hobifi_empty_state.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    final all = bookingService.getUserBookings(authService.currentUser?.id ?? '');
    final completed = all.where((b) => b.status == BookingStatus.completed).toList();
    final cancelled = all.where((b) => b.status == BookingStatus.cancelled).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking History'),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          indicatorColor: theme.colorScheme.primary,
          tabs: const [Tab(text: 'Completed'), Tab(text: 'Cancelled')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(completed, 'No completed bookings yet'),
          _buildList(cancelled, 'No cancelled bookings'),
        ],
      ),
    );
  }

  Widget _buildList(List<BookingModel> bookings, String emptyLabel) {
    if (bookings.isEmpty) {
      return HobifiEmptyState(
        icon: Icons.history_rounded,
        title: emptyLabel,
        subtitle: 'Your past activity bookings will appear here.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: bookings.length,
      itemBuilder: (_, i) => BookingCard(booking: bookings[i]),
    );
  }
}
