import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hobby_haven/services/auth_service.dart';
import 'package:hobby_haven/services/activity_service.dart';
import 'package:hobby_haven/services/booking_service.dart';
import 'package:hobby_haven/services/theme_service.dart';
import 'package:hobby_haven/theme.dart';
import 'package:hobby_haven/nav.dart';
import 'package:hobby_haven/utils/input_sanitizer.dart';

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  bool _changingPhoto = false;
  bool _editingBio = false;
  bool _savingBio = false;
  bool _editingPhone = false;
  bool _savingPhone = false;
  late TextEditingController _bioController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController();
    _phoneController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthService>();
      if (auth.currentUser != null) {
        _bioController.text = auth.currentUser!.bio ?? '';
        _phoneController.text = auth.currentUser!.phone ?? '';
        context.read<BookingService>().loadBusinessBookings(auth.currentUser!.id);
      }
    });
  }

  @override
  void dispose() {
    _bioController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _savePhone() async {
    final auth = context.read<AuthService>();
    setState(() => _savingPhone = true);
    final ok = await auth.updateProfile(phone: _phoneController.text.trim());
    if (mounted) {
      setState(() {
        _savingPhone = false;
        _editingPhone = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Phone number updated' : 'Failed to update phone number')),
      );
    }
  }

  Future<void> _saveBio() async {
    final auth = context.read<AuthService>();
    setState(() => _savingBio = true);
    final ok = await auth.updateProfile(bio: InputSanitizer.sanitize(_bioController.text, maxLength: 200));
    if (mounted) {
      setState(() {
        _savingBio = false;
        _editingBio = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Bio updated' : 'Failed to update bio')),
      );
    }
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
    final activityService = context.watch<ActivityService>();
    final bookingService = context.watch<BookingService>();
    final themeService = context.watch<ThemeService>();

    final user = auth.currentUser;
    final activities = user == null ? <dynamic>[] : activityService.getActivitiesByBusinessId(user.id);
    final bookings = bookingService.businessBookings;
    final double avgRating = activities.isEmpty
        ? 0.0
        : activities.fold<double>(0.0, (sum, a) => sum + (a.rating as double)) / activities.length;

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
                                ? Icon(Icons.store_rounded, size: 48, color: colorScheme.primary)
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
                      // Business name
                      Text(
                        user?.name ?? '—',
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
                            Icon(Icons.store_rounded, color: colorScheme.primary, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'BUSINESS',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Bio section
                      if (_editingBio)
                        Column(
                          children: [
                            TextField(
                              controller: _bioController,
                              maxLines: 3,
                              maxLength: 200,
                              decoration: InputDecoration(
                                hintText: 'Tell people about your business...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: _savingBio
                                      ? null
                                      : () => setState(() {
                                            _editingBio = false;
                                            _bioController.text = user?.bio ?? '';
                                          }),
                                  child: const Text('Cancel'),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: _savingBio ? null : _saveBio,
                                  child: _savingBio
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Text('Save'),
                                ),
                              ],
                            ),
                          ],
                        )
                      else
                        GestureDetector(
                          onTap: () => setState(() => _editingBio = true),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.onSurface.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              (user?.bio != null && user!.bio!.isNotEmpty) ? user.bio! : 'Tap to add a bio...',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: (user?.bio != null && user!.bio!.isNotEmpty)
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurface.withValues(alpha: 0.4),
                                fontStyle: (user?.bio != null && user!.bio!.isNotEmpty)
                                    ? FontStyle.normal
                                    : FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      // Phone number edit
                      if (_editingPhone)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: 'Phone Number',
                                hintText: '+201000000000',
                                prefixIcon: const Icon(Icons.phone_rounded),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: _savingPhone
                                      ? null
                                      : () => setState(() {
                                            _editingPhone = false;
                                            _phoneController.text = user?.phone ?? '';
                                          }),
                                  child: const Text('Cancel'),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: _savingPhone ? null : _savePhone,
                                  child: _savingPhone
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Text('Save'),
                                ),
                              ],
                            ),
                          ],
                        )
                      else
                        GestureDetector(
                          onTap: () => setState(() => _editingPhone = true),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.onSurface.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.phone_rounded, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                                const SizedBox(width: 8),
                                Text(
                                  (user?.phone != null && user!.phone!.isNotEmpty) ? user.phone! : 'Tap to add a phone number...',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: (user?.phone != null && user!.phone!.isNotEmpty)
                                        ? colorScheme.onSurface
                                        : colorScheme.onSurface.withValues(alpha: 0.4),
                                    fontStyle: (user?.phone != null && user!.phone!.isNotEmpty)
                                        ? FontStyle.normal
                                        : FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      // Stats row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatItem(value: '${activities.length}', label: 'Activities'),
                          Container(width: 1, height: 40, color: colorScheme.outline.withValues(alpha: 0.3)),
                          _StatItem(value: '${bookings.length}', label: 'Bookings'),
                          Container(width: 1, height: 40, color: colorScheme.outline.withValues(alpha: 0.3)),
                          _StatItem(value: avgRating.toStringAsFixed(1), label: 'Rating'),
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
                activeThumbColor: colorScheme.primary,
                activeTrackColor: colorScheme.primary.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
