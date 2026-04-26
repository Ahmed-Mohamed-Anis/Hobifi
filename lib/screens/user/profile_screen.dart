import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hobby_haven/services/auth_service.dart';
import 'package:hobby_haven/services/booking_service.dart';
import 'package:hobby_haven/theme.dart';
import 'package:hobby_haven/nav.dart';
import 'package:hobby_haven/services/like_service.dart';
import 'package:hobby_haven/services/rating_service.dart';
import 'package:hobby_haven/services/theme_service.dart';
import 'package:hobby_haven/services/location_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _changingPhoto = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthService>();
      final bookings = context.read<BookingService>();
      if (auth.currentUser != null) {
        bookings.loadUserBookings(auth.currentUser!.id);
        context.read<LikeService>().loadLikes(auth.currentUser!.id);
        context.read<RatingService>().loadUserRatings(auth.currentUser!.id);
      }
    });
  }

  Future<void> _pickAndUploadAvatar() async {
    final auth = context.read<AuthService>();
    if (auth.currentUser == null) return;
    try {
      setState(() => _changingPhoto = true);
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file == null) return;
      final Uint8List bytes = await file.readAsBytes();
      final String ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
      final ok = await auth.changeAvatar(bytes, fileExt: ext);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile photo')),
        );
      }
    } catch (e) {
      debugPrint('Failed to change avatar: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _changingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final auth = context.watch<AuthService>();
    final bookings = context.watch<BookingService>();
    final likeService = context.watch<LikeService>();
    final themeService = context.watch<ThemeService>();
    final ratingService = context.watch<RatingService>();
    final locationService = context.watch<LocationService>();

    final user = auth.currentUser;
    final userBookings = user == null ? 0 : bookings.getUserBookings(user.id).length;
    final likedCount = likeService.likedActivityIds.length;
    final reviewCount = ratingService.ratings.length;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header
              Padding(
                padding: AppSpacing.paddingLg,
                child: Row(
                  children: [
                    Text('Profile', style: theme.textTheme.headlineMedium?.copyWith(color: colorScheme.onSurface)),
                  ],
                ),
              ),
              // Profile card
              Padding(
                padding: AppSpacing.horizontalLg,
                child: Container(
                  padding: AppSpacing.paddingLg,
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                        offset: const Offset(0, 4),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Avatar + edit
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                            backgroundImage: (user?.avatarUrl != null &&
                                    (user!.avatarUrl!.startsWith('http') || user.avatarUrl!.startsWith('https')))
                                ? NetworkImage(user.avatarUrl!)
                                : null,
                            child: (user?.avatarUrl == null)
                                ? Icon(Icons.person_rounded, size: 48, color: colorScheme.primary)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: InkWell(
                              onTap: _changingPhoto ? null : _pickAndUploadAvatar,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(AppRadius.full),
                                  border: Border.all(color: colorScheme.surface, width: 3),
                                ),
                                child: _changingPhoto
                                    ? Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimary),
                                      )
                                    : Icon(Icons.photo_camera_rounded, color: colorScheme.onPrimary, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // User info
                      Text(
                        (user?.username != null && user!.username!.isNotEmpty)
                            ? '@${user.username}'
                            : (user?.name ?? '—'),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '',
                        style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.7)),
                      ),
                      const SizedBox(height: 12),
                      // Role badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, color: colorScheme.primary, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              user?.role.name.toUpperCase() ?? '',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (user != null && user.interests.isNotEmpty && user.interests.first != 'All') ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: user.interests.map((interest) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(9999),
                              border: Border.all(color: colorScheme.primary.withValues(alpha: 0.15)),
                            ),
                            child: Text(
                              interest,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )).toList(),
                        ),
                      ],
                      // Location chip
                      if (user?.city != null && user!.city!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on_rounded, size: 14, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                            const SizedBox(width: 4),
                            Text(
                              user.city!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ] else if (locationService.savedLocation != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.my_location_rounded, size: 14, color: colorScheme.tertiary),
                            const SizedBox(width: 4),
                            Text(
                              'GPS location saved',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.tertiary,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      // Stats row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatItem(value: '$userBookings', label: 'Bookings'),
                          Container(width: 1, height: 40, color: colorScheme.outline.withValues(alpha: 0.3)),
                          _StatItem(value: '$likedCount', label: 'Liked'),
                          Container(width: 1, height: 40, color: colorScheme.outline.withValues(alpha: 0.3)),
                          _StatItem(value: '$reviewCount', label: 'Reviews'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Settings section
              Padding(
                padding: AppSpacing.horizontalLg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Settings',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Booking History
                    _SettingsRow(
                      icon: Icons.history_rounded,
                      title: 'Booking History',
                      subtitle: 'Completed and cancelled activities',
                      onTap: () => context.push(AppRoutes.profileHistory),
                    ),
                    const SizedBox(height: 12),
                    // Dark Mode Toggle
                    _DarkModeToggle(
                      isDarkMode: themeService.isDarkMode,
                      onToggle: () => themeService.toggleTheme(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Logout button
              Padding(
                padding: AppSpacing.horizontalLg,
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await auth.signOut();
                      if (context.mounted) context.go(AppRoutes.auth);
                    },
                    icon: const Icon(Icons.logout_rounded, color: Colors.red),
                    label: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.7)),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: colorScheme.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DarkModeToggle extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback onToggle;

  const _DarkModeToggle({required this.isDarkMode, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDarkMode
                        ? [const Color(0xFF1E1B7A), const Color(0xFF4A47B8)]
                        : [AppColors.orange, AppColors.lime],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dark Mode',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDarkMode ? 'Switch to light theme' : 'Switch to dark theme',
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: isDarkMode,
                onChanged: (_) => onToggle(),
                activeTrackColor: colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
