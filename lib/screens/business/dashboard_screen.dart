import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:hobby_haven/services/activity_service.dart';
import 'package:hobby_haven/services/booking_service.dart';
import 'package:hobby_haven/services/auth_service.dart';
import 'package:hobby_haven/theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hobby_haven/nav.dart';
import 'package:hobby_haven/supabase/supabase_config.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  /// Fetch last 7 days revenue for the chart
  Future<List<_DailyRevenue>> _fetchRevenueChart(String businessId) async {
    try {
      final acts = await SupabaseService.select('activities',
          select: 'id', filters: {'business_id': businessId});
      final activityIds =
          acts.map((e) => e['id'] as String).whereType<String>().toList();
      if (activityIds.isEmpty) return _generateEmptyDays();

      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 6));

      final paymentsRows = await SupabaseService.from('payments')
          .select('business_earnings,created_at,status')
          .inFilter('activity_id', activityIds)
          .eq('status', 'completed')
          .gte('created_at', sevenDaysAgo.toIso8601String()) as List<dynamic>;

// Group by day
      final Map<String, double> dailyEarnings = {};
      for (int i = 0; i < 7; i++) {
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
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
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
      if (activityIds.isEmpty)
        return const _BusinessStats(
            earnings: 0, bookings: 0, likes: 0, avgRating: 0.0);

// Fetch paid bookings, payments, likes, and ratings in parallel
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

      final results = await Future.wait(
          [bookingsFuture, paymentsFuture, likesFuture, ratingsFuture]);
      final bookingsRows = (results[0] as List).cast<Map<String, dynamic>>();
      final paymentsRows = (results[1] as List).cast<Map<String, dynamic>>();
      final likesRows = (results[2] as List);
      final ratingsRows = (results[3] as List);

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

      return _BusinessStats(
          earnings: earnings,
          bookings: bookings,
          likes: likes,
          avgRating: avgRating);
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

// Aggregate bookings and revenue (use payment earnings if available, else 90% of booking price)
      for (final rowDynamic in bookingsRows) {
        final row = rowDynamic as Map<String, dynamic>;
        final String aId = row['activity_id'] as String;
        final double price = (row['price'] as num?)?.toDouble() ?? 0.0;
        final current = map[aId] ??
            const _PerActivityStats(
                bookings: 0, revenue: 0.0, likes: 0, avgRating: 0.0);
// Use 90% of price (after 10% platform fee)
        final revenue = price * 0.9;
        map[aId] = _PerActivityStats(
            bookings: current.bookings + 1,
            revenue: current.revenue + revenue,
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthService>();
      final bookings = context.read<BookingService>();
      if (auth.currentUser != null) {
        await bookings.loadBusinessBookings(auth.currentUser!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activityService = context.watch<ActivityService>();
    context.watch<BookingService>(); // Keep reactive but unused directly
    final authService = context.watch<AuthService>();
    final userId = authService.currentUser?.id;

// Data for the Activities list (can rely on providers; not used for top stats)
    final businessActivities = userId == null
        ? const []
        : activityService.getActivitiesByBusinessId(userId);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dashboard',
                              style: theme.textTheme.displayLarge?.copyWith(
                                  color: AppColors.lightPrimaryText,
                                  fontWeight: FontWeight.w900)),
                          Text(
                              'Welcome back, ${authService.currentUser?.name ?? 'Business'}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.lightSecondaryText)),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context.push(AppRoutes.businessWallet),
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                        ),
                        icon: Icon(Icons.account_balance_wallet_rounded,
                            color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => context.push(AppRoutes.businessProfile),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            border:
                                Border.all(color: AppColors.lightPrimary, width: 2),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: CircleAvatar(
                              backgroundColor: AppColors.lightSurface,
                              backgroundImage: (authService.currentUser?.avatarUrl !=
                                          null &&
                                      (authService.currentUser!.avatarUrl!
                                              .startsWith('http') ||
                                          authService.currentUser!.avatarUrl!
                                              .startsWith('https')))
                                  ? NetworkImage(authService.currentUser!.avatarUrl!)
                                  : null,
                              child: (authService.currentUser?.avatarUrl == null)
                                  ? const Icon(Icons.store_rounded,
                                      color: AppColors.lightPrimary)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (userId == null)
                Row(
                  children: const [
                    Expanded(child: _StatCardSkeleton()),
                    SizedBox(width: AppSpacing.md),
                    Expanded(child: _StatCardSkeleton()),
                    SizedBox(width: AppSpacing.md),
                    Expanded(child: _StatCardSkeleton()),
                  ],
                )
              else
                FutureBuilder<_BusinessStats>(
                  future: _fetchStats(userId),
                  builder: (context, snapshot) {
                    final loading =
                        snapshot.connectionState != ConnectionState.done;
                    final stats = snapshot.data ??
                        const _BusinessStats(
                            earnings: 0, bookings: 0, likes: 0, avgRating: 0.0);
                    if (loading &&
                        snapshot.hasError == false &&
                        snapshot.data == null) {
                      return Row(
                        children: const [
                          Expanded(child: _StatCardSkeleton()),
                          SizedBox(width: AppSpacing.md),
                          Expanded(child: _StatCardSkeleton()),
                          SizedBox(width: AppSpacing.md),
                          Expanded(child: _StatCardSkeleton()),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                icon: Icons.payments_rounded,
                                iconBg: AppColors.lightPrimary
                                    .withValues(alpha: 0.13),
                                iconColor: const Color(0xFF047E0D),
                                value: '\$${stats.earnings.toStringAsFixed(0)}',
                                label: 'Earnings',
                                trend: '',
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: StatCard(
                                icon: Icons.confirmation_number_rounded,
                                iconBg: AppColors.lightSecondary
                                    .withValues(alpha: 0.13),
                                iconColor: AppColors.lightSecondary,
                                value: stats.bookings.toString(),
                                label: 'Bookings',
                                trend: '',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                icon: Icons.favorite_rounded,
                                iconBg: const Color(0xFFF0DCDC),
                                iconColor: const Color(0xFFFF0000),
                                value: stats.likes.toString(),
                                label: 'Likes',
                                trend: '',
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: StatCard(
                                icon: Icons.star_rounded,
                                iconBg: AppColors.lightAccent
                                    .withValues(alpha: 0.13),
                                iconColor: AppColors.lightAccent,
                                value: stats.avgRating.toStringAsFixed(1),
                                label: 'Avg Rating',
                                trend: '',
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: AppSpacing.lg),
              if (userId != null)
                FutureBuilder<List<_DailyRevenue>>(
                  future: _fetchRevenueChart(userId),
                  builder: (context, snapshot) {
                    final revenueData = snapshot.data ?? _generateEmptyDays();
                    final maxY = revenueData
                        .map((e) => e.amount)
                        .fold<double>(0.0, (a, b) => a > b ? a : b);
                    final spots = revenueData
                        .map((e) => FlSpot(e.dayIndex.toDouble(), e.amount))
                        .toList();
                    final weekdays = [
                      'Mon',
                      'Tue',
                      'Wed',
                      'Thu',
                      'Fri',
                      'Sat',
                      'Sun'
                    ];

                    return Container(
                      padding: AppSpacing.paddingLg,
                      decoration: BoxDecoration(
                        color: AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            offset: const Offset(0, 10),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Revenue Trend',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                      color: AppColors.lightPrimaryText,
                                      fontWeight: FontWeight.bold)),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.lightBackground,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.full),
                                ),
                                child: Text('Last 7 Days',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                        color: AppColors.lightPrimary)),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          SizedBox(
                            height: 180,
                            child: LineChart(
                              LineChartData(
                                gridData: const FlGridData(show: false),
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        if (value.toInt() < 0 ||
                                            value.toInt() >= revenueData.length)
                                          return const SizedBox.shrink();
                                        final day =
                                            revenueData[value.toInt()].date;
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8),
                                          child: Text(weekdays[day.weekday - 1],
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                      color:
                                                          AppColors.lightHint)),
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
                                    color: AppColors.lightPrimary,
                                    barWidth: 4,
                                    dotData: FlDotData(
                                      show: true,
                                      getDotPainter:
                                          (spot, percent, bar, index) =>
                                              FlDotCirclePainter(
                                        radius: 4,
                                        color: AppColors.lightPrimary,
                                        strokeWidth: 2,
                                        strokeColor: Colors.white,
                                      ),
                                    ),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: AppColors.lightPrimary
                                          .withValues(alpha: 0.13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Your Activities',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Color(0xFFC6A2A2),
                          fontWeight: FontWeight.bold)),
                  InkWell(
                    onTap: () => context.push('/business-create-activity'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.lightPrimary,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.lightPrimary.withValues(alpha: 0.27),
                            offset: const Offset(0, 4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.add_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 4),
                          Text('Create New',
                              style: theme.textTheme.labelLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (userId != null)
                FutureBuilder<Map<String, _PerActivityStats>>(
                  future: _fetchPerActivityStats(userId),
                  builder: (context, snapshot) {
                    final agg =
                        snapshot.data ?? const <String, _PerActivityStats>{};
                    final activitiesToShow =
                        businessActivities.take(3).toList();
                    return Column(
                      children: activitiesToShow.map((activity) {
                        final stats = agg[activity.id];
                        final bookingsCount = stats?.bookings ?? 0;
                        final revenueVal = stats?.revenue ?? 0.0;
                        final likesCount = stats?.likes ?? 0;
                        final avgRating = stats?.avgRating ?? 0.0;
                        final image = (activity.imageUrls.isNotEmpty
                            ? activity.imageUrls.first
                            : activity.imageUrl);
                        return ActivityItem(
                          title: activity.title,
                          bookings: bookingsCount,
                          likes: likesCount,
                          avgRating: avgRating,
                          revenue: '\$${revenueVal.toStringAsFixed(0)}',
                          imageUrl: image,
                          onTap: () {
                            debugPrint(
                                'Dashboard: tapped activity ${activity.id}');
                            final loc = context.namedLocation(
                              'business-activity',
                              pathParameters: {'id': activity.id},
                            );
                            debugPrint('Dashboard: navigating to ' + loc);
                            context.push(loc);
                          },
                        );
                      }).toList(),
                    );
                  },
                )
              else
                const SizedBox.shrink(),
              const SizedBox(height: AppSpacing.xl),
// Earnings History Section
              if (userId != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Earnings',
                        style: theme.textTheme.titleLarge?.copyWith(
                            color: AppColors.lightPrimaryText,
                            fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF047E0D).withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.trending_up_rounded,
                              size: 14, color: Color(0xFF047E0D)),
                          const SizedBox(width: 4),
                          Text('90% to you',
                              style: theme.textTheme.labelSmall?.copyWith(
                                  color: const Color(0xFF047E0D),
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                FutureBuilder<List<_EarningsTransaction>>(
                  future: _fetchEarningsHistory(userId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(
                          child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator()));
                    }
                    final transactions = snapshot.data ?? [];
                    if (transactions.isEmpty) {
                      return Container(
                        padding: AppSpacing.paddingLg,
                        decoration: BoxDecoration(
                          color: AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.lightDivider),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.account_balance_wallet_outlined,
                                size: 48, color: AppColors.lightHint),
                            const SizedBox(height: AppSpacing.md),
                            Text('No earnings yet',
                                style: theme.textTheme.titleMedium?.copyWith(
                                    color: AppColors.lightSecondaryText)),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                                'Earnings will appear here after customers make payments',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: AppColors.lightHint),
                                textAlign: TextAlign.center),
                          ],
                        ),
                      );
                    }
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            offset: const Offset(0, 8),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Column(
                        children: transactions.asMap().entries.map((entry) {
                          final index = entry.key;
                          final tx = entry.value;
                          final isLast = index == transactions.length - 1;
                          return _EarningsRow(
                              transaction: tx, showDivider: !isLast);
                        }).toList(),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusinessStats {
  final double earnings;
  final int bookings;
  final int likes;
  final double avgRating;
  const _BusinessStats(
      {required this.earnings,
      required this.bookings,
      required this.likes,
      required this.avgRating});
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

class _EarningsRow extends StatelessWidget {
  final _EarningsTransaction transaction;
  final bool showDivider;
  const _EarningsRow({required this.transaction, this.showDivider = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = transaction.status == 'completed';
    final statusColor =
        isCompleted ? const Color(0xFF047E0D) : AppColors.lightAccent;
    final statusBg = isCompleted
        ? const Color(0xFF047E0D).withValues(alpha: 0.13)
        : AppColors.lightAccent.withValues(alpha: 0.13);

// Format date
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
                child: Icon(
                  isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.pending_rounded,
                  color: statusColor,
                  size: 20,
                ),
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
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.lightHint),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '+\$${transaction.amount.toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF047E0D),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      isCompleted ? 'Completed' : 'Pending',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: statusColor, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: AppColors.lightDivider),
      ],
    );
  }
}

class _StatCardSkeleton extends StatelessWidget {
  const _StatCardSkeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border:
            Border.all(color: AppColors.lightPrimary.withValues(alpha: 0.08)),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String value;
  final String label;
  final String trend;

  const StatCard({
    super.key,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.27),
            offset: const Offset(0, 8),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              Text(trend,
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.lightSuccess,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          const SizedBox(height: AppSpacing.xs),
          Text(value,
              style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppColors.lightPrimaryText,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: AppColors.lightSecondaryText)),
        ],
      ),
    );
  }
}

class ActivityItem extends StatelessWidget {
  final String title;
  final int bookings;
  final int likes;
  final double avgRating;
  final String revenue;
  final String imageUrl;
  final VoidCallback? onTap;

  const ActivityItem({
    super.key,
    required this.title,
    required this.bookings,
    required this.likes,
    required this.avgRating,
    required this.revenue,
    required this.imageUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNetwork = imageUrl.startsWith('http');
    return Material(
      color: AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.lightDivider),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: AppSpacing.paddingMd,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: isNetwork
                    ? Image.network(imageUrl,
                        width: 64, height: 64, fit: BoxFit.cover)
                    : Image.asset(imageUrl,
                        width: 64, height: 64, fit: BoxFit.cover),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.lightPrimaryText,
                            fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.group_rounded,
                          color: AppColors.lightHint, size: 14),
                      const SizedBox(width: 4),
                      Text('$bookings',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.lightSecondaryText)),
                      const SizedBox(width: 12),
                      const Icon(Icons.favorite_rounded,
                          color: AppColors.likeRed, size: 14),
                      const SizedBox(width: 4),
                      Text('$likes',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.lightSecondaryText)),
                      const SizedBox(width: 12),
                      const Icon(Icons.star_rounded,
                          color: AppColors.lightAccent, size: 14),
                      const SizedBox(width: 4),
                      Text(avgRating > 0 ? avgRating.toStringAsFixed(1) : 'N/A',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.lightSecondaryText)),
                    ]),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(revenue,
                      style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.lightAccent,
                          fontWeight: FontWeight.bold)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: const Color(0xFF39FF14).withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(AppRadius.full)),
                    child: Text('Active',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF39FF14),
                            fontWeight: FontWeight.bold)),
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
