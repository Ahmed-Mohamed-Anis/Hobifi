import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hobby_haven/services/activity_service.dart';
import 'package:hobby_haven/services/booking_service.dart';
import 'package:hobby_haven/services/auth_service.dart';
import 'package:hobby_haven/services/wallet_service.dart';
import 'package:hobby_haven/models/booking_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hobby_haven/nav.dart';
import 'package:hobby_haven/supabase/supabase_config.dart';
import 'package:hobby_haven/theme.dart';
import 'package:hobby_haven/widgets/hobifi_stat_card.dart';
import 'package:hobby_haven/widgets/hobifi_chip.dart';
import 'package:hobby_haven/widgets/hobifi_shimmer.dart';
import 'package:hobby_haven/widgets/hobifi_section_header.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Cached futures — created once, survive rebuilds
  Future<_BusinessStats>? _statsFuture;
  Future<List<_DailyRevenue>>? _revenueFuture;
  Future<Map<String, _PerActivityStats>>? _perActivityFuture;
  Future<List<_EarningsTransaction>>? _earningsFuture;
  int _selectedDays = 7; // 7, 30, or 90
  String _activitySortBy = 'revenue'; // 'revenue' | 'bookings' | 'fillRate'

  void _initDashboard(String businessId) {
    _statsFuture = _fetchStats(businessId);
    _revenueFuture = _fetchRevenueChart(businessId);
    _perActivityFuture = _fetchPerActivityStats(businessId);
    _earningsFuture = _fetchEarningsHistory(businessId);
  }

  void _refreshDashboard(String businessId) {
    setState(() {
      _initDashboard(businessId);
    });
  }

  /// Fetch last N days revenue for the chart
  Future<List<_DailyRevenue>> _fetchRevenueChart(String businessId) async {
    try {
      final acts = await SupabaseService.select('activities',
          select: 'id', filters: {'business_id': businessId});
      final activityIds =
          acts.map((e) => e['id'] as String).whereType<String>().toList();
      if (activityIds.isEmpty) return _generateEmptyDays();

      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(Duration(days: _selectedDays - 1));

      final paymentsRows = await SupabaseService.from('payments')
          .select('business_earnings,created_at,status')
          .inFilter('activity_id', activityIds)
          .eq('status', 'completed')
          .gte('created_at', sevenDaysAgo.toIso8601String()) as List<dynamic>;

// Group by day
      final Map<String, double> dailyEarnings = {};
      for (int i = 0; i < _selectedDays; i++) {
        final day =
            DateTime(sevenDaysAgo.year, sevenDaysAgo.month, sevenDaysAgo.day)
                .add(Duration(days: i));
        final key =
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        dailyEarnings[key] = 0.0;
      }

      for (final row in paymentsRows) {
        final createdAt = DateTime.parse(row['created_at'] as String);
        final key =
            '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
        final earnings = (row['business_earnings'] as num?)?.toDouble() ?? 0.0;
        dailyEarnings[key] = (dailyEarnings[key] ?? 0.0) + earnings;
      }

      final sortedKeys = dailyEarnings.keys.toList()..sort();
      return sortedKeys.asMap().entries.map((entry) {
        final date = DateTime.parse(entry.value);
        return _DailyRevenue(
            dayIndex: entry.key,
            amount: dailyEarnings[entry.value] ?? 0.0,
            date: date);
      }).toList();
    } catch (e) {
      debugPrint('Dashboard _fetchRevenueChart failed: $e');
      return _generateEmptyDays();
    }
  }

  List<_DailyRevenue> _generateEmptyDays() {
    final now = DateTime.now();
    return List.generate(_selectedDays, (i) {
      final day = now.subtract(Duration(days: _selectedDays - 1 - i));
      return _DailyRevenue(dayIndex: i, amount: 0.0, date: day);
    });
  }

  /// Fetch recent payment transactions for Earnings History
  Future<List<_EarningsTransaction>> _fetchEarningsHistory(
      String businessId) async {
    try {
      final acts = await SupabaseService.select('activities',
          select: 'id,title', filters: {'business_id': businessId});
      final activityIds =
          acts.map((e) => e['id'] as String).whereType<String>().toList();
      final activityTitles = <String, String>{};
      for (final a in acts) {
        activityTitles[a['id'] as String] = a['title'] as String? ?? 'Activity';
      }
      if (activityIds.isEmpty) return [];

      final paymentsRows = await SupabaseService.from('payments')
          .select('id,activity_id,business_earnings,created_at,status')
          .inFilter('activity_id', activityIds)
          .eq('status', 'completed')
          .order('created_at', ascending: false)
          .limit(10) as List<dynamic>;

      return paymentsRows.map((row) {
        final activityId = row['activity_id'] as String;
        return _EarningsTransaction(
          id: row['id'] as String,
          activityTitle: activityTitles[activityId] ?? 'Activity',
          amount: (row['business_earnings'] as num?)?.toDouble() ?? 0.0,
          date: DateTime.parse(row['created_at'] as String),
          status: row['status'] as String? ?? 'pending',
        );
      }).toList();
    } catch (e) {
      debugPrint('Dashboard _fetchEarningsHistory failed: $e');
      return [];
    }
  }

  Future<_BusinessStats> _fetchStats(String businessId) async {
    try {
// Get activities owned by this business
      final acts = await SupabaseService.select('activities',
          select: 'id', filters: {'business_id': businessId});
      final activityIds =
          acts.map((e) => e['id'] as String).whereType<String>().toList();
      if (activityIds.isEmpty) {
        return const _BusinessStats(
            earnings: 0, bookings: 0, likes: 0, avgRating: 0.0);
      }

      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      final twoWeeksAgo = now.subtract(const Duration(days: 14));

// Fetch paid bookings, payments, likes, ratings, and weekly deltas in parallel
      final bookingsFuture = SupabaseService.from('bookings')
          .select('price,status,activity_id')
          .inFilter('activity_id', activityIds)
          .inFilter('status', ['confirmed', 'completed']);
      final paymentsFuture = SupabaseService.from('payments')
          .select('business_earnings,status')
          .inFilter('activity_id', activityIds)
          .eq('status', 'completed');
      final likesFuture = SupabaseService.from('likes')
          .select('activity_id')
          .inFilter('activity_id', activityIds);
      final ratingsFuture = SupabaseService.from('ratings')
          .select('rating')
          .inFilter('activity_id', activityIds);
      // This week's payments (last 7 days)
      final paymentsThisWeekFuture = SupabaseService.from('payments')
          .select('business_earnings,created_at,status')
          .inFilter('activity_id', activityIds)
          .eq('status', 'completed')
          .gte('created_at', weekAgo.toIso8601String());
      // Last week's payments (7–14 days ago)
      final paymentsLastWeekFuture = SupabaseService.from('payments')
          .select('business_earnings,created_at,status')
          .inFilter('activity_id', activityIds)
          .eq('status', 'completed')
          .gte('created_at', twoWeeksAgo.toIso8601String())
          .lt('created_at', weekAgo.toIso8601String());
      // This week's bookings
      final bookingsThisWeekFuture = SupabaseService.from('bookings')
          .select('id,created_at,status')
          .inFilter('activity_id', activityIds)
          .inFilter('status', ['confirmed', 'completed'])
          .gte('created_at', weekAgo.toIso8601String());
      // Last week's bookings
      final bookingsLastWeekFuture = SupabaseService.from('bookings')
          .select('id,created_at,status')
          .inFilter('activity_id', activityIds)
          .inFilter('status', ['confirmed', 'completed'])
          .gte('created_at', twoWeeksAgo.toIso8601String())
          .lt('created_at', weekAgo.toIso8601String());

      final results = await Future.wait([
        bookingsFuture,
        paymentsFuture,
        likesFuture,
        ratingsFuture,
        paymentsThisWeekFuture,
        paymentsLastWeekFuture,
        bookingsThisWeekFuture,
        bookingsLastWeekFuture,
      ]);
      final bookingsRows = (results[0] as List).cast<Map<String, dynamic>>();
      final paymentsRows = (results[1] as List).cast<Map<String, dynamic>>();
      final likesRows = (results[2] as List);
      final ratingsRows = (results[3] as List);
      final paymentsThisWeek = (results[4] as List).cast<Map<String, dynamic>>();
      final paymentsLastWeek = (results[5] as List).cast<Map<String, dynamic>>();
      final bookingsThisWeek = (results[6] as List);
      final bookingsLastWeek = (results[7] as List);

// Use business_earnings from payments (already has 10% deducted)
// If no payments table yet, fallback to bookings with 10% deduction
      double earnings;
      if (paymentsRows.isNotEmpty) {
        earnings = paymentsRows.fold<double>(
            0.0,
            (sum, row) =>
                sum + ((row['business_earnings'] as num?)?.toDouble() ?? 0.0));
      } else {
// Fallback: Calculate 90% of booking prices
        earnings = bookingsRows.fold<double>(
            0.0,
            (sum, row) =>
                sum + (((row['price'] as num?)?.toDouble() ?? 0.0) * 0.9));
      }

      final bookings = bookingsRows.length;
      final likes = likesRows.length;

// Calculate average rating
      double avgRating = 0.0;
      if (ratingsRows.isNotEmpty) {
        final totalRating = ratingsRows.fold<int>(
            0, (sum, row) => sum + (row['rating'] as int));
        avgRating = totalRating / ratingsRows.length;
      }

// Compute week-over-week earnings trend
      final earningsThisWeek = paymentsThisWeek.fold<double>(
          0.0,
          (sum, row) =>
              sum + ((row['business_earnings'] as num?)?.toDouble() ?? 0.0));
      final earningsLastWeek = paymentsLastWeek.fold<double>(
          0.0,
          (sum, row) =>
              sum + ((row['business_earnings'] as num?)?.toDouble() ?? 0.0));

      String? earningsTrendStr;
      bool earningsTrendUp = true;
      if (earningsLastWeek > 0) {
        final pct =
            ((earningsThisWeek - earningsLastWeek) / earningsLastWeek * 100)
                .round();
        earningsTrendUp = pct >= 0;
        earningsTrendStr = pct >= 0 ? '+$pct%' : '$pct%';
      }

// Compute week-over-week bookings trend
      final bookingsThisWeekCount = bookingsThisWeek.length;
      final bookingsLastWeekCount = bookingsLastWeek.length;

      String? bookingsTrendStr;
      bool bookingsTrendUp = true;
      if (bookingsLastWeekCount > 0) {
        final pct = ((bookingsThisWeekCount - bookingsLastWeekCount) /
                    bookingsLastWeekCount *
                    100)
                .round();
        bookingsTrendUp = pct >= 0;
        bookingsTrendStr = pct >= 0 ? '+$pct%' : '$pct%';
      }

      return _BusinessStats(
          earnings: earnings,
          bookings: bookings,
          likes: likes,
          avgRating: avgRating,
          earningsTrend: earningsTrendStr,
          earningsTrendUp: earningsTrendUp,
          bookingsTrend: bookingsTrendStr,
          bookingsTrendUp: bookingsTrendUp);
    } catch (e) {
      debugPrint('Dashboard _fetchStats failed: $e');
      return const _BusinessStats(
          earnings: 0, bookings: 0, likes: 0, avgRating: 0.0);
    }
  }

  Future<Map<String, _PerActivityStats>> _fetchPerActivityStats(
      String businessId) async {
    try {
      final acts = await SupabaseService.select('activities',
          select: 'id', filters: {'business_id': businessId});
      final activityIds =
          acts.map((e) => e['id'] as String).whereType<String>().toList();
      if (activityIds.isEmpty) return <String, _PerActivityStats>{};

      final bookingsRows = await SupabaseService.from('bookings')
          .select('price,status,activity_id')
          .inFilter('activity_id', activityIds)
          .inFilter('status', ['confirmed', 'completed']) as List<dynamic>;

// Fetch payments for these activities
      final paymentsRows = await SupabaseService.from('payments')
          .select('business_earnings,activity_id,status')
          .inFilter('activity_id', activityIds)
          .eq('status', 'completed') as List<dynamic>;

// Fetch likes and ratings for these activities
      final likesRows = await SupabaseService.from('likes')
          .select('activity_id')
          .inFilter('activity_id', activityIds) as List<dynamic>;

      final ratingsRows = await SupabaseService.from('ratings')
          .select('activity_id,rating')
          .inFilter('activity_id', activityIds) as List<dynamic>;

      final Map<String, _PerActivityStats> map = {};

// Seed map with zeroes for all activities to ensure presence even if no bookings/likes/ratings
      for (final id in activityIds) {
        map[id] = const _PerActivityStats(
            bookings: 0, revenue: 0.0, likes: 0, avgRating: 0.0);
      }

// Create map of activity_id to business_earnings from payments
      final Map<String, double> paymentEarnings = {};
      for (final rowDynamic in paymentsRows) {
        final row = rowDynamic as Map<String, dynamic>;
        final String aId = row['activity_id'] as String;
        final double earnings =
            (row['business_earnings'] as num?)?.toDouble() ?? 0.0;
        paymentEarnings[aId] = (paymentEarnings[aId] ?? 0.0) + earnings;
      }

// Aggregate confirmed bookings count
      for (final rowDynamic in bookingsRows) {
        final row = rowDynamic as Map<String, dynamic>;
        final String aId = row['activity_id'] as String;
        final current = map[aId] ??
            const _PerActivityStats(
                bookings: 0, revenue: 0.0, likes: 0, avgRating: 0.0);
        map[aId] = _PerActivityStats(
            bookings: current.bookings + 1,
            revenue: paymentEarnings[aId] ?? 0.0,
            likes: current.likes,
            avgRating: current.avgRating);
      }

// Aggregate likes
      for (final rowDynamic in likesRows) {
        final row = rowDynamic as Map<String, dynamic>;
        final String aId = row['activity_id'] as String;
        final current = map[aId] ??
            const _PerActivityStats(
                bookings: 0, revenue: 0.0, likes: 0, avgRating: 0.0);
        map[aId] = _PerActivityStats(
            bookings: current.bookings,
            revenue: current.revenue,
            likes: current.likes + 1,
            avgRating: current.avgRating);
      }

// Calculate average ratings per activity
      final Map<String, List<int>> ratingsPerActivity = {};
      for (final rowDynamic in ratingsRows) {
        final row = rowDynamic as Map<String, dynamic>;
        final String aId = row['activity_id'] as String;
        final int rating = row['rating'] as int;
        ratingsPerActivity.putIfAbsent(aId, () => []).add(rating);
      }

      for (final entry in ratingsPerActivity.entries) {
        final aId = entry.key;
        final ratings = entry.value;
        final avgRating = ratings.reduce((a, b) => a + b) / ratings.length;
        final current = map[aId] ??
            const _PerActivityStats(
                bookings: 0, revenue: 0.0, likes: 0, avgRating: 0.0);
        map[aId] = _PerActivityStats(
            bookings: current.bookings,
            revenue: current.revenue,
            likes: current.likes,
            avgRating: avgRating);
      }

      return map;
    } catch (e) {
      debugPrint('Dashboard _fetchPerActivityStats failed: $e');
      return <String, _PerActivityStats>{};
    }
  }

  List<dynamic> _sortedActivities(
    List activities,
    Map<String, _PerActivityStats> agg,
  ) {
    final sorted = List.from(activities);
    switch (_activitySortBy) {
      case 'revenue':
        sorted.sort((a, b) =>
            (agg[b.id]?.revenue ?? 0).compareTo(agg[a.id]?.revenue ?? 0));
      case 'bookings':
        sorted.sort((a, b) =>
            (agg[b.id]?.bookings ?? 0).compareTo(agg[a.id]?.bookings ?? 0));
      case 'fillRate':
        double rate(a) =>
            a.maxGuests > 0 ? (a.maxGuests - a.spotsLeft) / a.maxGuests : 0.0;
        sorted.sort((a, b) => rate(b).compareTo(rate(a)));
    }
    return sorted;
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthService>();
      final bookings = context.read<BookingService>();
      final wallet = context.read<WalletService>();
      if (auth.currentUser != null) {
        await bookings.loadBusinessBookings(auth.currentUser!.id);
        wallet.loadWallet(auth.currentUser!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activityService = context.watch<ActivityService>();
    final bookingService = context.watch<BookingService>();
    final walletService = context.watch<WalletService>();
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;
    final userId = user?.id;

    // Initialize cached futures once when userId is available
    if (userId != null && _statsFuture == null) {
      _initDashboard(userId);
    }

    final businessActivities = userId == null
        ? const []
        : activityService.getActivitiesByBusinessId(userId);

    // Today's confirmed bookings, sorted by time
    final now = DateTime.now();
    final todayBookings = bookingService.businessBookings.where((b) {
      return b.dateTime.year == now.year &&
          b.dateTime.month == now.month &&
          b.dateTime.day == now.day &&
          b.status == BookingStatus.confirmed;
    }).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            if (userId != null) _refreshDashboard(userId);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _greeting(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.name ?? 'Dashboard',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Wallet button
                      IconButton(
                        onPressed: () =>
                            context.push(AppRoutes.businessWallet),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              colorScheme.primary.withValues(alpha: 0.1),
                        ),
                        icon: Icon(Icons.account_balance_wallet_rounded,
                            color: colorScheme.primary),
                      ),
                      const SizedBox(width: 8),
                      // Avatar circle
                      GestureDetector(
                        onTap: () =>
                            context.push(AppRoutes.businessProfile),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: colorScheme.primary, width: 2),
                          ),
                          child: ClipOval(
                            child: CircleAvatar(
                              backgroundColor: colorScheme.surfaceContainerHighest,
                              backgroundImage: (user?.avatarUrl != null &&
                                      (user!.avatarUrl!.startsWith('http') ||
                                          user.avatarUrl!
                                              .startsWith('https')))
                                  ? NetworkImage(user.avatarUrl!)
                                  : null,
                              child: user?.avatarUrl == null
                                  ? Icon(Icons.store_rounded,
                                      color: colorScheme.primary)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Today's Schedule ────────────────────────────────
                if (userId != null && todayBookings.isNotEmpty) ...[
                  HobifiSectionHeader(
                    title: "Today's Schedule",
                    subtitle: '${todayBookings.length} confirmed',
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: todayBookings.map((booking) {
                        return GestureDetector(
                          onTap: () => context
                              .push('${AppRoutes.ticket}/${booking.id}'),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: colorScheme.outline
                                      .withValues(alpha: 0.12)),
                            ),
                            child: Row(
                              children: [
                                // Time badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(9999),
                                  ),
                                  child: Text(
                                    DateFormat('h:mm a')
                                        .format(booking.dateTime),
                                    style:
                                        theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Title + location
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        booking.activityTitle,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.location_on_rounded,
                                            size: 12,
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.4),
                                          ),
                                          const SizedBox(width: 2),
                                          Expanded(
                                            child: Text(
                                              booking.location,
                                              style: theme
                                                  .textTheme.bodySmall
                                                  ?.copyWith(
                                                color: colorScheme.onSurface
                                                    .withValues(alpha: 0.5),
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
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                // ── All Bookings CTA ────────────────────────────────
                if (userId != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(AppRoutes.businessBookings),
                      icon: const Icon(Icons.calendar_month_rounded, size: 18),
                      label: const Text('All Bookings'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                // ── Stat Cards (horizontal scroll) ──────────────────
                if (userId == null)
                  _buildStatCardsShimmer()
                else
                  FutureBuilder<_BusinessStats>(
                    future: _statsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done &&
                          snapshot.data == null) {
                        return _buildStatCardsShimmer();
                      }
                      final stats = snapshot.data ??
                          const _BusinessStats(
                              earnings: 0,
                              bookings: 0,
                              likes: 0,
                              avgRating: 0.0);
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                        child: Row(
                          children: [
                            HobifiStatCard(
                              icon: Icons.payments_rounded,
                              label: 'Total Revenue',
                              value:
                                  'EGP ${stats.earnings.toStringAsFixed(0)}',
                              trend: stats.earningsTrend,
                              trendPositive: stats.earningsTrendUp,
                            ),
                            const SizedBox(width: 12),
                            HobifiStatCard(
                              icon: Icons.confirmation_number_rounded,
                              label: 'Total Bookings',
                              value: stats.bookings.toString(),
                              trend: stats.bookingsTrend,
                              trendPositive: stats.bookingsTrendUp,
                            ),
                            const SizedBox(width: 12),
                            HobifiStatCard(
                              icon: Icons.event_available_rounded,
                              label: 'Active Activities',
                              value: businessActivities.length.toString(),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                // ── Wallet Balance Card ──────────────────────────────
                if (userId != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: walletService.isLoading
                        ? HobifiShimmer(
                            width: double.infinity,
                            height: 72,
                            borderRadius: 16)
                        : Container(
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: colorScheme.outline
                                      .withValues(alpha: 0.15)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  offset: const Offset(0, 4),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                // Wallet icon circle
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: colorScheme.primary
                                        .withValues(alpha: 0.1),
                                  ),
                                  child: Icon(
                                    Icons.account_balance_wallet_rounded,
                                    color: colorScheme.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Balance column
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Available Balance',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                      Text(
                                        'EGP ${walletService.balance.toStringAsFixed(2)}',
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                                fontWeight: FontWeight.bold),
                                      ),
                                      if (walletService.pendingPayouts > 0)
                                        Text(
                                          'EGP ${walletService.pendingPayouts.toStringAsFixed(2)} pending',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.45),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // Withdraw button
                                TextButton(
                                  onPressed: () => context
                                      .push(AppRoutes.businessWallet),
                                  child: const Text('Withdraw'),
                                ),
                              ],
                            ),
                          ),
                  ),

                // ── Revenue Chart ────────────────────────────────────
                if (userId != null) ...[
                  // Period selector
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        for (final days in [7, 30, 90])
                          HobifiChip(
                            label: '${days}d',
                            isSelected: _selectedDays == days,
                            onTap: () {
                              setState(() => _selectedDays = days);
                              _refreshDashboard(userId);
                            },
                          ),
                      ],
                    ),
                  ),
                  FutureBuilder<List<_DailyRevenue>>(
                    future: _revenueFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                              ConnectionState.waiting &&
                          snapshot.data == null) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                          child: HobifiShimmer(
                              width: double.infinity,
                              height: 220,
                              borderRadius: 20),
                        );
                      }
                      final revenueData =
                          snapshot.data ?? _generateEmptyDays();
                      final maxY = revenueData
                          .map((e) => e.amount)
                          .fold<double>(0.0, (a, b) => a > b ? a : b);
                      final spots = revenueData
                          .map((e) =>
                              FlSpot(e.dayIndex.toDouble(), e.amount))
                          .toList();
                      const weekdays = [
                        'Mon',
                        'Tue',
                        'Wed',
                        'Thu',
                        'Fri',
                        'Sat',
                        'Sun'
                      ];

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                offset: const Offset(0, 8),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Revenue Trend',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 180,
                                child: LineChart(
                                  LineChartData(
                                    gridData: FlGridData(
                                      show: true,
                                      drawVerticalLine: false,
                                      horizontalInterval:
                                          maxY > 0 ? maxY / 4 : 25,
                                      getDrawingHorizontalLine: (value) =>
                                          FlLine(
                                        color: colorScheme.outline
                                            .withValues(alpha: 0.1),
                                        strokeWidth: 1,
                                      ),
                                    ),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            // Skip non-integer positions (fl_chart calls this for intermediate values too)
                                            if (value != value.roundToDouble()) return const SizedBox.shrink();
                                            final idx = value.toInt();
                                            if (idx < 0 || idx >= revenueData.length) {
                                              return const SizedBox.shrink();
                                            }
                                            // Step: show every nth label so they don't crowd
                                            final step = _selectedDays <= 7 ? 1 : _selectedDays <= 30 ? 5 : 15;
                                            if (idx % step != 0) return const SizedBox.shrink();

                                            final day = revenueData[idx].date;
                                            final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
                                            final String label;
                                            if (_selectedDays <= 7) {
                                              label = weekdays[day.weekday - 1];
                                            } else if (_selectedDays <= 30) {
                                              label = '${months[day.month - 1]} ${day.day}';
                                            } else {
                                              label = '${months[day.month - 1]} ${day.day}';
                                            }

                                            return Padding(
                                              padding: const EdgeInsets.only(top: 8),
                                              child: Text(
                                                label,
                                                style: theme.textTheme.labelSmall?.copyWith(
                                                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                                                ),
                                              ),
                                            );
                                          },
                                          reservedSize: 28,
                                        ),
                                      ),
                                      leftTitles: const AxisTitles(
                                          sideTitles:
                                              SideTitles(showTitles: false)),
                                      topTitles: const AxisTitles(
                                          sideTitles:
                                              SideTitles(showTitles: false)),
                                      rightTitles: const AxisTitles(
                                          sideTitles:
                                              SideTitles(showTitles: false)),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    minY: 0,
                                    maxY: maxY > 0 ? maxY * 1.2 : 100,
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: spots,
                                        isCurved: true,
                                        color: colorScheme.primary,
                                        barWidth: 3,
                                        dotData: FlDotData(
                                          show: true,
                                          getDotPainter: (spot, percent,
                                                  bar, index) =>
                                              FlDotCirclePainter(
                                            radius: 3,
                                            color: colorScheme.primary,
                                            strokeWidth: 2,
                                            strokeColor: colorScheme.surface,
                                          ),
                                        ),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              colorScheme.primary
                                                  .withValues(alpha: 0.3),
                                              colorScheme.primary
                                                  .withValues(alpha: 0.0),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],

                // ── Per-Activity Breakdown ───────────────────────────
                if (userId != null) ...[
                  HobifiSectionHeader(
                    title: 'Your Activities',
                    onSeeAll: businessActivities.isEmpty
                        ? null
                        : () => context.push(AppRoutes.businessCreateActivity),
                  ),
                  // Sort control tabs
                  if (businessActivities.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Row(
                        children: [
                          for (final entry in {
                            'revenue': 'Revenue',
                            'bookings': 'Bookings',
                            'fillRate': 'Fill Rate',
                          }.entries)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: HobifiChip(
                                label: entry.value,
                                isSelected: _activitySortBy == entry.key,
                                onTap: () => setState(() => _activitySortBy = entry.key),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (businessActivities.isEmpty)
                    _buildEmptyActivitiesCTA(context)
                  else
                    FutureBuilder<Map<String, _PerActivityStats>>(
                      future: _perActivityFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting &&
                            snapshot.data == null) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: List.generate(
                                3,
                                (_) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: HobifiShimmer(
                                      width: double.infinity, height: 100, borderRadius: 16),
                                ),
                              ),
                            ),
                          );
                        }
                        final agg = snapshot.data ?? const <String, _PerActivityStats>{};
                        final activitiesToShow = _sortedActivities(businessActivities, agg);
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: activitiesToShow.map((activity) {
                              final stats = agg[activity.id];
                              final fillRate = activity.maxGuests > 0
                                  ? ((activity.maxGuests - activity.spotsLeft) /
                                          activity.maxGuests)
                                      .clamp(0.0, 1.0)
                                  : 0.0;
                              return _ActivityBreakdownCard(
                                title: activity.title,
                                imageUrl: activity.imageUrl,
                                bookings: stats?.bookings ?? 0,
                                revenue: stats?.revenue ?? 0.0,
                                fillRate: fillRate,
                                avgRating: stats?.avgRating ?? 0.0,
                                onTap: () {
                                  final loc = context.namedLocation(
                                    'business-activity',
                                    pathParameters: {'id': activity.id},
                                  );
                                  context.push(loc);
                                },
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                ],

                // ── Recent Earnings ──────────────────────────────────
                if (userId != null) ...[
                  HobifiSectionHeader(
                    title: 'Recent Earnings',
                    onSeeAll: () =>
                        context.push(AppRoutes.businessWallet),
                  ),
                  FutureBuilder<List<_EarningsTransaction>>(
                    future: _earningsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                              ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: List.generate(
                              3,
                              (_) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: HobifiShimmer.listTile(),
                              ),
                            ),
                          ),
                        );
                      }
                      final transactions = snapshot.data ?? [];
                      if (transactions.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: colorScheme.outline
                                      .withValues(alpha: 0.15)),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 48,
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No earnings yet',
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Earnings appear here after payments',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.4),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                offset: const Offset(0, 4),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: Column(
                            children:
                                transactions.asMap().entries.map((entry) {
                              final index = entry.key;
                              final tx = entry.value;
                              final isLast =
                                  index == transactions.length - 1;
                              return _EarningsRow(
                                transaction: tx,
                                showDivider: !isLast,
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCardsShimmer() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          HobifiShimmer(width: 180, height: 80, borderRadius: 16),
          const SizedBox(width: 12),
          HobifiShimmer(width: 180, height: 80, borderRadius: 16),
          const SizedBox(width: 12),
          HobifiShimmer(width: 180, height: 80, borderRadius: 16),
        ],
      ),
    );
  }

  Widget _buildEmptyActivitiesCTA(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(Icons.rocket_launch_rounded,
                size: 48, color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Welcome to HOBIFI!',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first activity to start getting bookings from explorers.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () =>
                  context.go(AppRoutes.businessCreateActivity),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Activity'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data Models ────────────────────────────────────────────────────────────────

class _BusinessStats {
  final double earnings;
  final int bookings;
  final int likes;
  final double avgRating;
  final String? earningsTrend;
  final bool earningsTrendUp;
  final String? bookingsTrend;
  final bool bookingsTrendUp;
  const _BusinessStats({
    required this.earnings,
    required this.bookings,
    required this.likes,
    required this.avgRating,
    this.earningsTrend,
    this.earningsTrendUp = true,
    this.bookingsTrend,
    this.bookingsTrendUp = true,
  });
}

class _PerActivityStats {
  final int bookings;
  final double revenue;
  final int likes;
  final double avgRating;
  const _PerActivityStats(
      {required this.bookings,
      required this.revenue,
      required this.likes,
      required this.avgRating});
}

class _DailyRevenue {
  final int dayIndex;
  final double amount;
  final DateTime date;
  const _DailyRevenue(
      {required this.dayIndex, required this.amount, required this.date});
}

class _EarningsTransaction {
  final String id;
  final String activityTitle;
  final double amount;
  final DateTime date;
  final String status;
  const _EarningsTransaction(
      {required this.id,
      required this.activityTitle,
      required this.amount,
      required this.date,
      required this.status});
}

// ── Earnings Row ───────────────────────────────────────────────────────────────

class _EarningsRow extends StatelessWidget {
  final _EarningsTransaction transaction;
  final bool showDivider;
  const _EarningsRow({required this.transaction, this.showDivider = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color statusColor;
    Color statusBg;
    String statusLabel;
    IconData statusIcon;

    switch (transaction.status) {
      case 'completed':
        statusColor = const Color(0xFF9BC53D); // lime
        statusBg = const Color(0xFF9BC53D).withValues(alpha: 0.13);
        statusLabel = 'Completed';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'refunded':
        statusColor = const Color(0xFFE53935); // red
        statusBg = const Color(0xFFE53935).withValues(alpha: 0.13);
        statusLabel = 'Refunded';
        statusIcon = Icons.replay_rounded;
        break;
      default:
        statusColor = const Color(0xFFE88B3C); // orange
        statusBg = const Color(0xFFE88B3C).withValues(alpha: 0.13);
        statusLabel = 'Pending';
        statusIcon = Icons.pending_rounded;
    }

    final now = DateTime.now();
    final diff = now.difference(transaction.date);
    String dateText;
    if (diff.inDays == 0) {
      dateText = 'Today';
    } else if (diff.inDays == 1) {
      dateText = 'Yesterday';
    } else if (diff.inDays < 7) {
      dateText = '${diff.inDays} days ago';
    } else {
      dateText =
          '${transaction.date.day}/${transaction.date.month}/${transaction.date.year}';
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.activityTitle,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '+EGP ${transaction.amount.toStringAsFixed(2)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF9BC53D),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Text(
                      statusLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: colorScheme.outline.withValues(alpha: 0.1),
          ),
      ],
    );
  }
}

// ── Activity Breakdown Card ────────────────────────────────────────────────────

class _ActivityBreakdownCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final int bookings;
  final double revenue;
  final double fillRate;
  final double avgRating;
  final VoidCallback? onTap;

  const _ActivityBreakdownCard({
    required this.title,
    this.imageUrl,
    required this.bookings,
    required this.revenue,
    required this.fillRate,
    required this.avgRating,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl!,
                      width: 52, height: 52, fit: BoxFit.cover,
                      placeholder: (_, __) => HobifiShimmer.box(52, 52),
                      errorWidget: (_, __, ___) => Container(
                        width: 52, height: 52,
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(Icons.image_rounded, color: colorScheme.outline, size: 20),
                      ),
                    ),
                  ),
                if (imageUrl != null) const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('EGP ${revenue.toStringAsFixed(0)}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colorScheme.primary, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.confirmation_number_outlined, size: 13,
                            color: colorScheme.onSurface.withValues(alpha: 0.4)),
                          const SizedBox(width: 3),
                          Text('$bookings bookings',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.5))),
                          const Spacer(),
                          if (avgRating > 0) ...[
                            Icon(Icons.star_rounded, size: 13, color: colorScheme.tertiary),
                            const SizedBox(width: 2),
                            Text(avgRating.toStringAsFixed(1),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurface.withValues(alpha: 0.6))),
                          ] else ...[
                            Text('${(fillRate * 100).toStringAsFixed(0)}% full',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurface.withValues(alpha: 0.5))),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: fillRate,
                        borderRadius: BorderRadius.circular(4),
                        backgroundColor: colorScheme.outline.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.lime),
                        minHeight: 6,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
