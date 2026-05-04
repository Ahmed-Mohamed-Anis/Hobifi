import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hobby_haven/theme.dart';
import 'package:hobby_haven/nav.dart';
import 'package:hobby_haven/screens/splash_screen.dart';
import 'package:hobby_haven/services/auth_service.dart';
import 'package:hobby_haven/services/activity_service.dart';
import 'package:hobby_haven/services/booking_service.dart';
import 'package:hobby_haven/supabase/supabase_config.dart';
import 'package:hobby_haven/services/like_service.dart';
import 'package:hobby_haven/services/rating_service.dart';
import 'package:hobby_haven/services/payment_service.dart';
import 'package:hobby_haven/services/wallet_service.dart';
import 'package:hobby_haven/services/theme_service.dart';
import 'package:hobby_haven/services/location_service.dart';
import 'package:hobby_haven/services/connectivity_service.dart';
import 'package:hobby_haven/services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations for better performance
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set status bar style for splash screen
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));
  
  // Initialize Supabase
  await SupabaseConfig.initialize();

  // Initialize Firebase and push notifications
  try {
    await Firebase.initializeApp();
    await PushNotificationService.initialize();
  } catch (_) {}

  runApp(const MyApp());
}

/// Custom scroll behavior for smoother scrolling across platforms
class _SmoothScrollBehavior extends ScrollBehavior {
  const _SmoothScrollBehavior();
  
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // Use iOS-style bouncing physics for smoother feel
    return const BouncingScrollPhysics(
      decelerationRate: ScrollDecelerationRate.fast,
    );
  }
  
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    // Remove Android's glow effect for cleaner look
    return child;
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
        ChangeNotifierProvider(create: (_) => ThemeService()..initialize()),
        ChangeNotifierProvider(create: (_) => AuthService()..initialize()),
        ChangeNotifierProvider(create: (_) => ActivityService()..initialize()),
        ChangeNotifierProvider(create: (_) => LocationService()..loadSavedLocation()),
        ChangeNotifierProxyProvider<AuthService, BookingService>(
          create: (_) => BookingService(),
          update: (context, auth, bookingService) {
            final svc = bookingService ?? BookingService();
            final userId = auth.currentUser?.id;
            if (userId != null) {
              svc.loadUserBookings(userId);
            }
            return svc;
          },
        ),
        ChangeNotifierProxyProvider<AuthService, LikeService>(
          create: (_) => LikeService(),
          update: (context, auth, likeService) {
            final svc = likeService ?? LikeService();
            final userId = auth.currentUser?.id;
            if (userId != null) {
              // Fire-and-forget; service guards against duplicate loads
              svc.loadLikes(userId);
            }
            return svc;
          },
        ),
        ChangeNotifierProxyProvider<AuthService, RatingService>(
          create: (_) => RatingService(),
          update: (context, auth, ratingService) {
            final svc = ratingService ?? RatingService();
            final userId = auth.currentUser?.id;
            if (userId != null) {
              svc.loadUserRatings(userId);
            }
            return svc;
          },
        ),
        ChangeNotifierProxyProvider<AuthService, PaymentService>(
          create: (_) => PaymentService(),
          update: (context, auth, paymentService) {
            final svc = paymentService ?? PaymentService();
            final userId = auth.currentUser?.id;
            if (userId != null) {
              svc.loadUserPayments(userId);
            }
            return svc;
          },
        ),
        ChangeNotifierProxyProvider<AuthService, WalletService>(
          create: (_) => WalletService(),
          update: (context, auth, walletService) {
            final svc = walletService ?? WalletService();
            final user = auth.currentUser;
            // Only load wallet for business users
            if (user != null && user.role.name == 'business') {
              svc.loadWallet(user.id);
            }
            return svc;
          },
        ),
      ],
      child: Builder(
        builder: (context) {
          final themeService = context.watch<ThemeService>();
          final authService = context.read<AuthService>();
          return MaterialApp.router(
            title: 'HOBIFI',
            debugShowCheckedModeBanner: false,
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: themeService.themeMode,
            routerConfig: AppRouter.router(authService),
            scrollBehavior: const _SmoothScrollBehavior(),
            builder: (context, child) {
              return Stack(
                children: [
                  child!,
                  if (_showSplash)
                    SplashScreen(
                      onComplete: () {
                        if (mounted) setState(() => _showSplash = false);
                      },
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
