import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:hobby_haven/services/auth_service.dart';
import 'package:hobby_haven/services/location_service.dart';
import 'package:hobby_haven/theme.dart';
import 'package:hobby_haven/nav.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _saving = false;

  final Set<String> _selectedInterests = {};
  final TextEditingController _cityController = TextEditingController();

  static const List<_InterestOption> _interests = [
    _InterestOption('Art', Icons.palette_rounded, Color(0xFFE91E63)),
    _InterestOption('Sports', Icons.sports_soccer_rounded, Color(0xFF4CAF50)),
    _InterestOption('Music', Icons.music_note_rounded, Color(0xFF9C27B0)),
    _InterestOption('Cooking', Icons.restaurant_rounded, Color(0xFFFF9800)),
    _InterestOption('Tech', Icons.computer_rounded, Color(0xFF2196F3)),
    _InterestOption('Outdoor', Icons.terrain_rounded, Color(0xFF795548)),
  ];

  bool get _canContinue =>
      _currentPage == 0 ? _selectedInterests.length >= 3 : true;

  @override
  void dispose() {
    _pageController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == 0) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  Future<void> _skip() async {
    final auth = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);

    final success = await auth.updateProfile(interests: ['All']);

    if (!success) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
      return;
    }

    if (mounted) context.go(AppRoutes.feed);
  }

  Future<void> _finish() async {
    final auth = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);

    final interests = _selectedInterests.toList();
    final city = _cityController.text.trim();

    final success = await auth.updateProfile(
      interests: interests.isEmpty ? ['All'] : interests,
      city: city.isEmpty ? null : city,
    );

    if (!success) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
      return;
    }

    if (mounted) {
      context.go(AppRoutes.feed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _InterestsPage(
                    interests: _interests,
                    selected: _selectedInterests,
                    onToggle: (label) => setState(() {
                      if (_selectedInterests.contains(label)) {
                        _selectedInterests.remove(label);
                      } else {
                        _selectedInterests.add(label);
                      }
                    }),
                  ),
                  _CityPage(controller: _cityController),
                ],
              ),
            ),

            // Progress dots
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(2, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _currentPage == i ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? colorScheme.primary
                        : colorScheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                )),
              ),
            ),

            // Skip link
            TextButton(
              onPressed: _saving ? null : _skip,
              child: Text(
                'Skip for now',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.45),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Continue / Get Started button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : (_canContinue ? _nextPage : null),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    disabledBackgroundColor:
                        colorScheme.primary.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _currentPage == 1 ? 'Get Started' : 'Continue',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
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

// ─── Page 1: Pick Interests ───

class _InterestsPage extends StatelessWidget {
  final List<_InterestOption> interests;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _InterestsPage({
    required this.interests,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: AppSpacing.horizontalLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'What are you into?',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Let\'s find what moves you — pick a few interests to personalize your feed.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.6,
              ),
              itemCount: interests.length,
              itemBuilder: (context, i) {
                final interest = interests[i];
                final isSelected = selected.contains(interest.label);
                return AnimatedScale(
                  scale: isSelected ? 0.95 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: GestureDetector(
                    onTap: () => onToggle(interest.label),
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? interest.color.withValues(alpha: 0.15)
                            : colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? interest.color
                              : colorScheme.outline.withValues(alpha: 0.2),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  interest.icon,
                                  size: 28,
                                  color: isSelected
                                      ? interest.color
                                      : colorScheme.onSurface
                                          .withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  interest.label,
                                  style:
                                      theme.textTheme.labelMedium?.copyWith(
                                    color: isSelected
                                        ? interest.color
                                        : colorScheme.onSurface
                                            .withValues(alpha: 0.7),
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: interest.color,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Center(
              child: Text(
                '${selected.length}/3 selected',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: selected.length >= 3
                      ? colorScheme.primary
                      : colorScheme.onSurface.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Page 2: City / Location ───

class _CityPage extends StatefulWidget {
  final TextEditingController controller;
  const _CityPage({required this.controller});

  @override
  State<_CityPage> createState() => _CityPageState();
}

class _CityPageState extends State<_CityPage> {
  bool _locationDetected = false;
  bool _detecting = false;

  Future<void> _useMyLocation() async {
    setState(() => _detecting = true);
    final locationService = context.read<LocationService>();
    final result = await locationService.getCurrentLocation();
    if (!mounted) return;
    if (result == null) {
      setState(() => _detecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location access denied — enter your city manually'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      _locationDetected = true;
      _detecting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: AppSpacing.horizontalLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            'Where are you?',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll show activities near you first.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 40),

          if (_locationDetected)
            // Confirmation chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.tertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.tertiary.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on_rounded, color: colorScheme.tertiary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Location detected',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.tertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _locationDetected = false),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Change',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // "Use my location" button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _detecting ? null : _useMyLocation,
                icon: _detecting
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      )
                    : Icon(Icons.my_location_rounded, color: colorScheme.primary),
                label: Text(
                  _detecting ? 'Detecting...' : 'Use my location',
                  style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.5)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Divider(color: colorScheme.outline.withValues(alpha: 0.3))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                Expanded(child: Divider(color: colorScheme.outline.withValues(alpha: 0.3))),
              ],
            ),
            const SizedBox(height: 12),
            // City text field
            TextField(
              controller: widget.controller,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'e.g. Cairo, Alexandria, London...',
                prefixIcon: Icon(Icons.location_on_rounded, color: colorScheme.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
                filled: true,
                fillColor: colorScheme.surface,
              ),
            ),
          ],

          const SizedBox(height: 16),
          Center(
            child: Text(
              'This is optional — you can always change it later.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Data class ───

class _InterestOption {
  final String label;
  final IconData icon;
  final Color color;

  const _InterestOption(this.label, this.icon, this.color);
}
