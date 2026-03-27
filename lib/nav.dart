import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hobby_haven/screens/auth_screen.dart';
import 'package:hobby_haven/screens/user/feed_screen.dart';
import 'package:hobby_haven/screens/user/activity_details_screen.dart';
import 'package:hobby_haven/screens/user/profile_screen.dart';
import 'package:hobby_haven/screens/user/payment_screen.dart';
import 'package:hobby_haven/screens/user/ticket_screen.dart';
import 'package:hobby_haven/screens/business/dashboard_screen.dart';
import 'package:hobby_haven/screens/business/create_activity_screen.dart';
import 'package:hobby_haven/screens/business/activity_manage_screen.dart';
import 'package:hobby_haven/screens/business/wallet_screen.dart';
import 'package:hobby_haven/screens/business/business_profile_screen.dart';
import 'package:hobby_haven/services/auth_service.dart';

/// Smooth page transition for push navigation
CustomTransitionPage<void> _buildSmoothTransition({
  required Widget child,
  required GoRouterState state,
  Duration duration = const Duration(milliseconds: 350),
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Smooth slide up with fade
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(curvedAnimation),
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
            ),
          ),
          child: child,
        ),
      );
    },
  );
}

class AppRouter {
  static GoRouter? _router;

  static GoRouter router(AuthService authService) {
    _router ??= GoRouter(
      initialLocation: AppRoutes.auth,
      refreshListenable: authService,
      redirect: (context, state) {
        final isAuthenticated = authService.isAuthenticated;
        final isAuthRoute = state.matchedLocation == AppRoutes.auth;

        // If not authenticated and not on auth page, redirect to auth
        if (!isAuthenticated && !isAuthRoute) {
          return AppRoutes.auth;
        }

        // If authenticated and on auth page, redirect to appropriate home
        if (isAuthenticated && isAuthRoute) {
          final role = authService.currentUser?.role.name;
          if (role == 'business') {
            return AppRoutes.businessDashboard;
          }
          return AppRoutes.feed;
        }

        // No redirect needed
        return null;
      },
      routes: [
        GoRoute(
          path: AppRoutes.auth,
          name: 'auth',
          pageBuilder: (context, state) => const NoTransitionPage(child: AuthScreen()),
        ),
        GoRoute(
          path: AppRoutes.feed,
          name: 'feed',
          pageBuilder: (context, state) => const NoTransitionPage(child: FeedScreen()),
        ),
        GoRoute(
          path: '${AppRoutes.activity}/:id',
          name: 'activity',
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            return _buildSmoothTransition(
              child: ActivityDetailsScreen(activityId: id),
              state: state,
            );
          },
        ),
        GoRoute(
          path: '${AppRoutes.businessActivity}/:id',
          name: 'business-activity',
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            return _buildSmoothTransition(
              child: BusinessActivityScreen(activityId: id),
              state: state,
            );
          },
        ),
        GoRoute(
          path: AppRoutes.profile,
          name: 'profile',
          pageBuilder: (context, state) => const NoTransitionPage(child: ProfileScreen()),
        ),
        GoRoute(
          path: AppRoutes.businessDashboard,
          name: 'business-dashboard',
          pageBuilder: (context, state) => const NoTransitionPage(child: DashboardScreen()),
        ),
        GoRoute(
          path: AppRoutes.businessCreateActivity,
          name: 'business-create-activity',
          pageBuilder: (context, state) => _buildSmoothTransition(
            child: const CreateActivityScreen(),
            state: state,
          ),
        ),
        GoRoute(
          path: AppRoutes.businessWallet,
          name: 'business-wallet',
          pageBuilder: (context, state) => _buildSmoothTransition(
            child: const WalletScreen(),
            state: state,
          ),
        ),
        GoRoute(
          path: AppRoutes.businessProfile,
          name: 'business-profile',
          pageBuilder: (context, state) => _buildSmoothTransition(
            child: const BusinessProfileScreen(),
            state: state,
          ),
        ),
        GoRoute(
          path: '${AppRoutes.payment}/:bookingId',
          name: 'payment',
          pageBuilder: (context, state) {
            final bookingId = state.pathParameters['bookingId']!;
            final extra = state.extra as Map<String, dynamic>? ?? {};
            return _buildSmoothTransition(
              child: PaymentScreen(
                bookingId: bookingId,
                activityId: extra['activityId'] as String? ?? '',
                paymentUrl: extra['paymentUrl'] as String? ?? '',
                activityTitle: extra['activityTitle'] as String? ?? '',
                amount: extra['amount'] as double? ?? 0.0,
              ),
              state: state,
            );
          },
        ),
        GoRoute(
          path: '${AppRoutes.ticket}/:bookingId',
          name: 'ticket',
          pageBuilder: (context, state) {
            final bookingId = state.pathParameters['bookingId']!;
            return _buildSmoothTransition(
              child: TicketScreen(bookingId: bookingId),
              state: state,
            );
          },
        ),
      ],
    );
    return _router!;
  }
}

class AppRoutes {
  static const String auth = '/';
  static const String feed = '/feed';
  static const String activity = '/activity';
  static const String businessActivity = '/business-activity';
  static const String profile = '/profile';
  static const String businessDashboard = '/business-dashboard';
  static const String businessCreateActivity = '/business-create-activity';
  static const String businessWallet = '/business-wallet';
  static const String payment = '/payment';
  static const String ticket = '/ticket';
  static const String businessProfile = '/business-profile';
}
