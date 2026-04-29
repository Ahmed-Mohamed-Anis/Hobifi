import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hobby_haven/screens/auth_screen.dart';
import 'package:hobby_haven/screens/user/feed_screen.dart';
import 'package:hobby_haven/screens/user/activity_details_screen.dart';
import 'package:hobby_haven/screens/user/profile_screen.dart';
import 'package:hobby_haven/screens/user/bookings_screen.dart';
import 'package:hobby_haven/screens/user/friends_screen.dart';
import 'package:hobby_haven/screens/user/booking_confirm_screen.dart';
import 'package:hobby_haven/screens/user/payment_screen.dart';
import 'package:hobby_haven/screens/user/ticket_screen.dart';
import 'package:hobby_haven/screens/user/booking_history_screen.dart';
import 'package:hobby_haven/screens/business/dashboard_screen.dart';
import 'package:hobby_haven/screens/business/create_activity_screen.dart';
import 'package:hobby_haven/screens/business/activity_manage_screen.dart';
import 'package:hobby_haven/screens/business/wallet_screen.dart';
import 'package:hobby_haven/screens/business/business_profile_screen.dart';
import 'package:hobby_haven/screens/business/business_onboarding_screen.dart';
import 'package:hobby_haven/screens/onboarding_screen.dart';
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

// ─── Navigation keys for preserving state across tab switches ───
final _userShellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'userShell');
final _businessShellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'businessShell');
final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

class AppRouter {
  static GoRouter? _router;

  static GoRouter router(AuthService authService) {
    _router ??= GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: AppRoutes.auth,
      refreshListenable: authService,
      redirect: (context, state) {
        final isAuthenticated = authService.isAuthenticated;
        final isAuthRoute = state.matchedLocation == AppRoutes.auth;

        if (!isAuthenticated && !isAuthRoute) {
          return AppRoutes.auth;
        }

        if (isAuthenticated && isAuthRoute) {
          final user = authService.currentUser;
          if (user?.role.name == 'business') {
            // Un-onboarded business → wizard; otherwise dashboard
            if (user != null && !user.businessOnboarded) {
              return AppRoutes.businessOnboarding;
            }
            return AppRoutes.businessDashboard;
          }
          // New user with no interests → onboarding
          if (user != null && user.interests.isEmpty) {
            return AppRoutes.onboarding;
          }
          return AppRoutes.feed;
        }

        // Authenticated user navigating — check onboarding state
        if (isAuthenticated) {
          final user = authService.currentUser;
          final loc = state.matchedLocation;
          final isOnboarding = loc == AppRoutes.onboarding;
          final isBusinessOnboarding = loc == AppRoutes.businessOnboarding;

          // Business onboarding gate
          if (user != null &&
              user.role.name == 'business' &&
              !user.businessOnboarded &&
              !isBusinessOnboarding) {
            return AppRoutes.businessOnboarding;
          }
          // Already-onboarded business visiting the wizard → dashboard
          if (user != null &&
              user.role.name == 'business' &&
              user.businessOnboarded &&
              isBusinessOnboarding) {
            return AppRoutes.businessDashboard;
          }

          // Hard block: onboarded business users must never see user shell routes.
          // This catches any unexpected redirect that would land them at /feed etc.
          if (user != null && user.role.name == 'business' && user.businessOnboarded) {
            final isUserShellRoute = loc == AppRoutes.feed ||
                loc == AppRoutes.bookings ||
                loc == AppRoutes.friends ||
                loc == AppRoutes.profile ||
                loc == AppRoutes.onboarding;
            if (isUserShellRoute) return AppRoutes.businessDashboard;
          }

          // User role with no interests should go to onboarding
          if (user != null && user.role.name == 'user' && user.interests.isEmpty && !isOnboarding) {
            return AppRoutes.onboarding;
          }
          // Already onboarded — skip onboarding screen
          if (isOnboarding && user != null && user.interests.isNotEmpty) {
            return AppRoutes.feed;
          }
        }

        return null;
      },
      routes: [
        // ─── Auth (no shell) ───
        GoRoute(
          path: AppRoutes.auth,
          name: 'auth',
          pageBuilder: (context, state) => const NoTransitionPage(child: AuthScreen()),
        ),

        // ─── Onboarding (no shell) ───
        GoRoute(
          path: AppRoutes.onboarding,
          name: 'onboarding',
          pageBuilder: (context, state) => const NoTransitionPage(child: OnboardingScreen()),
        ),

        // ─── Business Onboarding (no shell) ───
        GoRoute(
          path: AppRoutes.businessOnboarding,
          name: 'business-onboarding',
          pageBuilder: (context, state) => const NoTransitionPage(child: BusinessOnboardingScreen()),
        ),

        // ─── User Shell with Bottom Nav ───
        ShellRoute(
          navigatorKey: _userShellNavigatorKey,
          builder: (context, state, child) => _UserShellScreen(
            location: state.uri.path,
            child: child,
          ),
          routes: [
            GoRoute(
              path: AppRoutes.feed,
              name: 'feed',
              pageBuilder: (context, state) => const NoTransitionPage(child: FeedScreen()),
            ),
            GoRoute(
              path: AppRoutes.bookings,
              name: 'bookings',
              pageBuilder: (context, state) => const NoTransitionPage(child: BookingsScreen()),
            ),
            GoRoute(
              path: AppRoutes.friends,
              name: 'friends',
              pageBuilder: (context, state) => const NoTransitionPage(child: FriendsScreen()),
            ),
            GoRoute(
              path: AppRoutes.profile,
              name: 'profile',
              pageBuilder: (context, state) => const NoTransitionPage(child: ProfileScreen()),
            ),
          ],
        ),

        // ─── Business Shell with Bottom Nav ───
        ShellRoute(
          navigatorKey: _businessShellNavigatorKey,
          builder: (context, state, child) => _BusinessShellScreen(
            location: state.uri.path,
            child: child,
          ),
          routes: [
            GoRoute(
              path: AppRoutes.businessDashboard,
              name: 'business-dashboard',
              pageBuilder: (context, state) => const NoTransitionPage(child: DashboardScreen()),
            ),
            GoRoute(
              path: AppRoutes.businessCreateActivity,
              name: 'business-create-activity',
              pageBuilder: (context, state) => const NoTransitionPage(child: CreateActivityScreen()),
            ),
            GoRoute(
              path: AppRoutes.businessWallet,
              name: 'business-wallet',
              pageBuilder: (context, state) => const NoTransitionPage(child: WalletScreen()),
            ),
            GoRoute(
              path: AppRoutes.businessProfile,
              name: 'business-profile',
              pageBuilder: (context, state) => const NoTransitionPage(child: BusinessProfileScreen()),
            ),
          ],
        ),

        // ─── Detail routes (outside shell — no bottom nav) ───
        GoRoute(
          path: '${AppRoutes.activity}/:id',
          name: 'activity',
          parentNavigatorKey: _rootNavigatorKey,
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
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            return _buildSmoothTransition(
              child: BusinessActivityScreen(activityId: id),
              state: state,
            );
          },
        ),
        GoRoute(
          path: '${AppRoutes.bookingConfirm}/:activityId',
          name: 'booking-confirm',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) {
            final id = state.pathParameters['activityId']!;
            return _buildSmoothTransition(
              child: BookingConfirmScreen(activityId: id),
              state: state,
            );
          },
        ),
        GoRoute(
          path: '${AppRoutes.payment}/:bookingId',
          name: 'payment',
          parentNavigatorKey: _rootNavigatorKey,
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
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) {
            final bookingId = state.pathParameters['bookingId']!;
            return _buildSmoothTransition(
              child: TicketScreen(bookingId: bookingId),
              state: state,
            );
          },
        ),
        GoRoute(
          path: AppRoutes.profileHistory,
          name: 'profile-history',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _buildSmoothTransition(
            child: const BookingHistoryScreen(),
            state: state,
          ),
        ),
      ],
    );
    return _router!;
  }
}

// ─── User Bottom Nav Shell ───
class _UserShellScreen extends StatelessWidget {
  final Widget child;
  final String location;
  const _UserShellScreen({required this.child, required this.location});

  int get _currentIndex {
    if (location.startsWith(AppRoutes.bookings)) return 1;
    if (location.startsWith(AppRoutes.friends)) return 2;
    if (location.startsWith(AppRoutes.profile)) return 3;
    return 0; // feed
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final idx = _currentIndex;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1)),
          ),
        ),
        child: NavigationBar(
          selectedIndex: idx,
          onDestinationSelected: (i) {
            switch (i) {
              case 0:
                context.go(AppRoutes.feed);
              case 1:
                context.go(AppRoutes.bookings);
              case 2:
                context.go(AppRoutes.friends);
              case 3:
                context.go(AppRoutes.profile);
            }
          },
          backgroundColor: colorScheme.surface,
          indicatorColor: colorScheme.primary.withValues(alpha: 0.12),
          indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          height: 56,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.explore_outlined, color: idx == 0 ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.5)),
              selectedIcon: Icon(Icons.explore_rounded, color: colorScheme.primary),
              label: 'Discover',
            ),
            NavigationDestination(
              icon: Icon(Icons.confirmation_number_outlined, color: idx == 1 ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.5)),
              selectedIcon: Icon(Icons.confirmation_number_rounded, color: colorScheme.primary),
              label: 'My Hobbies',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline_rounded, color: idx == 2 ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.5)),
              selectedIcon: Icon(Icons.people_rounded, color: colorScheme.primary),
              label: 'Friends',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded, color: idx == 3 ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.5)),
              selectedIcon: Icon(Icons.person_rounded, color: colorScheme.primary),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Business Bottom Nav Shell ───
class _BusinessShellScreen extends StatelessWidget {
  final Widget child;
  final String location;
  const _BusinessShellScreen({required this.child, required this.location});

  int get _currentIndex {
    if (location.startsWith(AppRoutes.businessCreateActivity)) return 1;
    if (location.startsWith(AppRoutes.businessWallet)) return 2;
    if (location.startsWith(AppRoutes.businessProfile)) return 3;
    return 0; // dashboard
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final idx = _currentIndex;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1)),
          ),
        ),
        child: NavigationBar(
          selectedIndex: idx,
          onDestinationSelected: (i) {
            switch (i) {
              case 0:
                context.go(AppRoutes.businessDashboard);
              case 1:
                context.go(AppRoutes.businessCreateActivity);
              case 2:
                context.go(AppRoutes.businessWallet);
              case 3:
                context.go(AppRoutes.businessProfile);
            }
          },
          backgroundColor: colorScheme.surface,
          indicatorColor: colorScheme.primary.withValues(alpha: 0.12),
          indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          height: 56,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined, color: idx == 0 ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.5)),
              selectedIcon: Icon(Icons.dashboard_rounded, color: colorScheme.primary),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_circle_outline_rounded, color: idx == 1 ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.5)),
              selectedIcon: Icon(Icons.add_circle_rounded, color: colorScheme.primary),
              label: 'Create',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined, color: idx == 2 ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.5)),
              selectedIcon: Icon(Icons.account_balance_wallet_rounded, color: colorScheme.primary),
              label: 'Wallet',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded, color: idx == 3 ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.5)),
              selectedIcon: Icon(Icons.person_rounded, color: colorScheme.primary),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class AppRoutes {
  static const String auth = '/';
  static const String onboarding = '/onboarding';
  static const String feed = '/feed';
  static const String bookings = '/bookings';
  static const String activity = '/activity';
  static const String businessActivity = '/business-activity';
  static const String profile = '/profile';
  static const String businessDashboard = '/business-dashboard';
  static const String businessCreateActivity = '/business-create-activity';
  static const String businessWallet = '/business-wallet';
  static const String bookingConfirm = '/booking-confirm';
  static const String payment = '/payment';
  static const String ticket = '/ticket';
  static const String businessProfile = '/business-profile';
  static const String businessOnboarding = '/business-onboarding';
  static const String profileHistory = '/profile/history';
  static const String friends = '/friends';
}
