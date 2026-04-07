import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:hobby_haven/models/activity_model.dart';
import 'package:hobby_haven/theme.dart';

/// Read-only preview of an activity as users will see it.
/// Used by business owners before publishing.
class ActivityPreviewScreen extends StatefulWidget {
  final ActivityModel activity;

  const ActivityPreviewScreen({super.key, required this.activity});

  @override
  State<ActivityPreviewScreen> createState() => _ActivityPreviewScreenState();
}

class _ActivityPreviewScreenState extends State<ActivityPreviewScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activity = widget.activity;
    final images = activity.imageUrls.isNotEmpty ? activity.imageUrls : [activity.imageUrl];
    final start = activity.startAt ?? activity.dateTime;
    final end = activity.endAt ?? activity.dateTime.add(const Duration(hours: 2));
    final dateStr = DateFormat('EEE, MMM d, yyyy').format(start);
    final timeStr = '${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}';

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ─── Image carousel ───
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    SizedBox(
                      height: 400,
                      width: double.infinity,
                      child: Stack(
                        children: [
                          PageView.builder(
                            controller: _pageController,
                            itemCount: images.length,
                            onPageChanged: (i) => setState(() => _currentIndex = i),
                            itemBuilder: (context, index) {
                              final url = images[index];
                              final isNetwork = url.startsWith('http');
                              return isNetwork
                                  ? Image.network(url, height: 400, width: double.infinity, fit: BoxFit.cover)
                                  : Image.asset(url, height: 400, width: double.infinity, fit: BoxFit.cover);
                            },
                          ),
                          if (images.length > 1)
                            Positioned(
                              bottom: 16,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(images.length, (i) {
                                  final active = i == _currentIndex;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    width: active ? 22 : 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: active ? Colors.white : Colors.white.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  );
                                }),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Gradient overlay
                    IgnorePointer(
                      ignoring: true,
                      child: Container(
                        height: 400,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFF0A0A0F),
                              const Color(0xFF0A0A0F).withValues(alpha: 0.4),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Back button + PREVIEW badge
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0A0A0F).withValues(alpha: 0.53),
                                borderRadius: BorderRadius.circular(AppRadius.full),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                                onPressed: () => context.pop(),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(AppRadius.full),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.visibility_rounded, color: Colors.white, size: 16),
                                  const SizedBox(width: 6),
                                  Text('PREVIEW', style: theme.textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Title overlay
                    Positioned(
                      bottom: AppSpacing.lg,
                      left: AppSpacing.lg,
                      right: AppSpacing.lg,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: AppColors.lightAccent,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(activity.category.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(color: AppColors.lightPrimaryText, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Text(
                                  activity.title.isEmpty ? 'Untitled Activity' : activity.title,
                                  style: theme.textTheme.displayLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.lightAccent,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                ),
                                child: Text('\$${activity.price.toStringAsFixed(0)}', style: theme.textTheme.labelMedium?.copyWith(color: AppColors.lightOnSurface)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Details ───
              SliverToBoxAdapter(
                child: Padding(
                  padding: AppSpacing.paddingLg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stat chips
                      Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.md,
                        children: [
                          _StatChip(icon: Icons.star_rounded, label: 'Rating', value: 'New', iconColor: AppColors.lightAccent),
                          _StatChip(icon: Icons.event_rounded, label: 'Date', value: dateStr),
                          _StatChip(icon: Icons.access_time_filled_rounded, label: 'Time', value: timeStr),
                          _StatChip(icon: Icons.location_on_rounded, label: 'Location', value: activity.location),
                          _StatChip(icon: Icons.group_rounded, label: 'Capacity', value: '${activity.maxGuests} guests'),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Features
                      if (activity.features.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: activity.features.map((f) => Chip(
                            label: Text(f, style: theme.textTheme.labelSmall),
                            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.08),
                            side: BorderSide.none,
                          )).toList(),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],

                      // Description
                      Text('About this activity', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                      const SizedBox(height: 8),
                      Text(
                        activity.description.isEmpty ? 'No description provided.' : activity.description,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), height: 1.5),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Location
                      Text('Location', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_on_rounded, color: theme.colorScheme.primary),
                            const SizedBox(width: 12),
                            Expanded(child: Text(activity.location, style: theme.textTheme.bodyMedium)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ─── Bottom bar ───
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: AppSpacing.paddingLg,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    offset: const Offset(0, -4),
                    blurRadius: 12,
                  ),
                ],
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Total Price', style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text('\$${activity.price.toStringAsFixed(0)}', style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w900)),
                              Text('/person', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text('Book Now', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'This is a preview — users will see this when your activity is live.',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;

  const _StatChip({required this.icon, required this.label, required this.value, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor ?? colorScheme.primary),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.5))),
              Text(value, style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
            ],
          ),
        ],
      ),
    );
  }
}
