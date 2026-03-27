import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:hobby_haven/services/activity_service.dart';
import 'package:hobby_haven/services/booking_service.dart';
import 'package:hobby_haven/services/auth_service.dart';
import 'package:hobby_haven/models/booking_model.dart';
import 'package:hobby_haven/models/activity_model.dart';
import 'package:hobby_haven/theme.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hobby_haven/nav.dart';
import 'package:hobby_haven/services/like_service.dart';
import 'package:hobby_haven/services/rating_service.dart';
import 'package:hobby_haven/models/rating_model.dart';
import 'package:hobby_haven/services/payment_service.dart';
import 'package:uuid/uuid.dart';

class ActivityDetailsScreen extends StatefulWidget {
final String activityId;

const ActivityDetailsScreen({super.key, required this.activityId});

@override
State<ActivityDetailsScreen> createState() => _ActivityDetailsScreenState();
}

class _ActivityDetailsScreenState extends State<ActivityDetailsScreen> {
final PageController _pageController = PageController();
int _currentIndex = 0;

Future<void> _openMaps(String address) async {
final query = Uri.encodeComponent(address);
final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
try {
final can = await canLaunchUrl(url);
if (can) {
await launchUrl(url, mode: LaunchMode.externalApplication);
}
} catch (e) {
debugPrint('Failed to open maps: $e');
}
}

Future<void> _handleBookAndPay(BuildContext context, ActivityModel activity) async {
final authService = context.read<AuthService>();
final bookingService = context.read<BookingService>();
final paymentService = context.read<PaymentService>();
final activityService = context.read<ActivityService>();

final user = authService.currentUser;
if (user == null) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Please sign in to book activities.')),
);
return;
}

// Check if spots are available
if (activity.spotsLeft <= 0) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Sorry, this activity is fully booked.')),
);
return;
}

// Check if activity date is in the past
final activityDate = activity.startAt ?? activity.dateTime;
if (activityDate.isBefore(DateTime.now())) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('This activity has already passed.')),
);
return;
}

// Show loading
showDialog(
context: context,
barrierDismissible: false,
builder: (ctx) => Center(
child: CircularProgressIndicator(color: Theme.of(ctx).colorScheme.primary),
),
);

try {
final now = DateTime.now();
final bookingId = const Uuid().v4();

// Create pending booking first
final booking = BookingModel(
id: bookingId,
userId: user.id,
activityId: activity.id,
activityTitle: activity.title,
activityImage: activity.imageUrl,
location: activity.location,
price: activity.price,
dateTime: activity.dateTime,
status: BookingStatus.pending,
createdAt: now,
updatedAt: now,
);
await bookingService.createBooking(booking);

// Decrement spots_left
try {
await activityService.updateActivity(
activity.copyWith(spotsLeft: activity.spotsLeft - 1),
);
} catch (e) {
debugPrint('Failed to update spots: $e');
}

// Initialize payment with Paymob
final paymentData = await paymentService.initializePayment(
bookingId: bookingId,
userId: user.id,
activityId: activity.id,
amount: activity.price,
activityTitle: activity.title,
userEmail: user.email,
userName: user.name,
userPhone: user.phone ?? '+201000000000',
);

if (context.mounted) {
Navigator.of(context).pop(); // Close loading

// Navigate to payment screen
context.push(
'${AppRoutes.payment}/$bookingId',
extra: {
'paymentUrl': paymentData['iframe_url'],
'activityId': activity.id,
'activityTitle': activity.title,
'amount': activity.price,
},
);
}
} catch (e) {
if (context.mounted) {
Navigator.of(context).pop(); // Close loading
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text('Failed to initialize payment: $e')),
);
}
debugPrint('Payment initialization failed: $e');
}
}

@override
void dispose() {
_pageController.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
final theme = Theme.of(context);
final activityService = context.watch<ActivityService>();
final activity = activityService.getActivityById(widget.activityId);
final likeService = context.watch<LikeService>();
final auth = context.read<AuthService>();

if (activity == null) {
return Scaffold(
appBar: AppBar(),
body: const Center(child: Text('Activity not found')),
);
}

final images = activity.imageUrls.isNotEmpty ? activity.imageUrls : [activity.imageUrl];
final start = activity.startAt ?? activity.dateTime;
final end = activity.endAt ?? activity.dateTime.add(const Duration(hours: 2));
final dateStr = DateFormat('EEE, MMM d, yyyy').format(start);
final timeStr = '${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}';
final isLiked = likeService.isLiked(activity.id);

return Scaffold(
body: Stack(
children: [
CustomScrollView(
slivers: [
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
// Make gradient overlay ignore touch so swipes reach PageView
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
Row(
children: [
Container(
width: 44,
height: 44,
decoration: BoxDecoration(
color: const Color(0xFF0A0A0F).withValues(alpha: 0.53),
borderRadius: BorderRadius.circular(AppRadius.full),
),
child: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
),
const SizedBox(width: AppSpacing.md),
InkWell(
onTap: () async {
final userId = auth.currentUser?.id;
if (userId == null) {
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to like activities.')));
return;
}
await context.read<LikeService>().toggleLike(userId, activity.id);
},
borderRadius: BorderRadius.circular(AppRadius.full),
child: Container(
width: 44,
height: 44,
decoration: BoxDecoration(
color: const Color(0xFF0A0A0F).withValues(alpha: 0.53),
borderRadius: BorderRadius.circular(AppRadius.full),
),
child: Icon(
isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
color: isLiked ? AppColors.likeRed : Colors.white,
size: 20,
),
),
),
],
),
],
),
),
),
Positioned(
bottom: AppSpacing.lg,
left: AppSpacing.lg,
right: AppSpacing.lg,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Container(
padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
decoration: BoxDecoration(
color: AppColors.lightAccent,
borderRadius: BorderRadius.circular(AppRadius.sm),
),
child: Text(activity.category.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(color: AppColors.lightPrimaryText, fontWeight: FontWeight.bold)),
),
],
),
const SizedBox(height: 8),
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
crossAxisAlignment: CrossAxisAlignment.end,
children: [
Expanded(
child: Text(activity.title, style: theme.textTheme.displayLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900), maxLines: 2, overflow: TextOverflow.ellipsis),
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
SliverToBoxAdapter(
child: Padding(
padding: AppSpacing.paddingLg,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
// Top quick stats as chips aligned with app style
Wrap(
spacing: AppSpacing.md,
runSpacing: AppSpacing.md,
children: [
DetailStatChip(
icon: Icons.star_rounded,
label: 'Rating',
value: activity.rating.toString(),
iconColor: AppColors.lightAccent,
),
DetailStatChip(
icon: Icons.event_rounded,
label: 'Date',
value: dateStr,
),
DetailStatChip(
icon: Icons.access_time_filled_rounded,
label: 'Time',
value: timeStr,
),
DetailStatChip(
icon: Icons.location_on_rounded,
label: 'Location',
value: 'View on map',
onTap: () => _openMaps(activity.location),
iconColor: Theme.of(context).colorScheme.primary,
),
],
),
const SizedBox(height: AppSpacing.lg),
RatingSection(activityId: activity.id),
const SizedBox(height: AppSpacing.lg),
Wrap(
spacing: 8,
runSpacing: 8,
children: activity.features.map((f) => FeatureTag(label: f)).toList(),
),
const SizedBox(height: AppSpacing.lg),
Text('About this activity', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
const SizedBox(height: 8),
Text(activity.description, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), height: 1.5)),
const SizedBox(height: AppSpacing.lg),
Text('Location', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
const SizedBox(height: 8),
Container(
height: 160,
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(AppRadius.lg),
border: Border.fromBorderSide(BorderSide(color: theme.dividerColor)),
),
child: ClipRRect(
borderRadius: BorderRadius.circular(AppRadius.lg),
child: Stack(
children: [
Image.asset('assets/images/map_location_city_null_1769445313494.jpg', fit: BoxFit.cover, width: double.infinity),
Center(
child: InkWell(
onTap: () => _openMaps(activity.location),
child: Container(
padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
decoration: BoxDecoration(
color: Colors.black.withValues(alpha: 0.6),
borderRadius: BorderRadius.circular(AppRadius.full),
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
const Icon(Icons.navigation_rounded, color: AppColors.lightPrimary, size: 16),
const SizedBox(width: 4),
Text('Open in Maps', style: theme.textTheme.labelMedium?.copyWith(color: Colors.white)),
],
),
),
),
),
Positioned(
left: 12,
right: 12,
bottom: 12,
child: Container(
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
decoration: BoxDecoration(
color: Colors.black.withValues(alpha: 0.45),
borderRadius: BorderRadius.circular(AppRadius.md),
),
child: Row(
children: [
const Icon(Icons.location_on_rounded, color: Colors.white, size: 16),
const SizedBox(width: 6),
Expanded(
child: Text(
activity.location,
style: theme.textTheme.labelSmall?.copyWith(color: Colors.white),
maxLines: 2,
overflow: TextOverflow.ellipsis,
),
),
],
),
),
),
],
),
),
),
const SizedBox(height: 100),
],
),
),
),
],
),
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
child: Row(
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
child: InkWell(
onTap: activity.spotsLeft > 0 ? () => _handleBookAndPay(context, activity) : null,
child: Container(
height: 56,
decoration: BoxDecoration(
color: activity.spotsLeft > 0 ? theme.colorScheme.primary : theme.disabledColor,
borderRadius: BorderRadius.circular(AppRadius.full),
boxShadow: activity.spotsLeft > 0 ? [
BoxShadow(
color: theme.colorScheme.primary.withValues(alpha: 0.27),
offset: const Offset(0, 8),
blurRadius: 16,
),
] : null,
),
child: Row(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(
activity.spotsLeft > 0 ? Icons.bolt_rounded : Icons.block_rounded,
color: theme.colorScheme.onPrimary, size: 20,
),
const SizedBox(width: 8),
Text(
activity.spotsLeft > 0 ? 'Book Now' : 'Fully Booked',
style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w800),
),
],
),
),
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

class FeatureTag extends StatelessWidget {
final String label;

const FeatureTag({super.key, required this.label});

@override
Widget build(BuildContext context) {
final theme = Theme.of(context);
final colorScheme = theme.colorScheme;
return Container(
padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
decoration: BoxDecoration(
color: colorScheme.surface,
borderRadius: BorderRadius.circular(AppRadius.full),
border: Border.fromBorderSide(BorderSide(color: theme.dividerColor)),
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(Icons.check_circle, color: colorScheme.tertiary, size: 16),
const SizedBox(width: 4),
Text(label, style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.6))),
],
),
);
}
}

class RatingSection extends StatefulWidget {
  final String activityId;

  const RatingSection({super.key, required this.activityId});

  @override
  State<RatingSection> createState() => _RatingSectionState();
}

class _RatingSectionState extends State<RatingSection> {
  final TextEditingController _commentController = TextEditingController();
  int _selectedStars = 0;
  bool _isSubmitting = false;
  bool _showReviewForm = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RatingService>().loadActivityReviews(widget.activityId);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthService>();
    final ratingService = context.watch<RatingService>();
    final userId = auth.currentUser?.id;
    final colorScheme = theme.colorScheme;

    if (userId == null) return const SizedBox.shrink();

    final userRating = ratingService.getUserRatingForActivity(userId, widget.activityId);
    final reviews = ratingService.getCachedActivityReviews(widget.activityId);
    // Reviews with comments
    final reviewsWithComments = reviews.where((r) => r.comment != null && r.comment!.trim().isNotEmpty).toList();

    // Pre-fill form if user already has a rating
    if (userRating != null && _selectedStars == 0 && !_showReviewForm) {
      _selectedStars = userRating.rating;
      if (userRating.comment != null && _commentController.text.isEmpty) {
        _commentController.text = userRating.comment!;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rate & Review Card
        Container(
          padding: AppSpacing.paddingLg,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.fromBorderSide(BorderSide(color: theme.dividerColor)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    userRating != null ? 'Your Review' : 'Rate & Review',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (userRating != null && !_showReviewForm)
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _showReviewForm = true;
                        _selectedStars = userRating.rating;
                        _commentController.text = userRating.comment ?? '';
                      }),
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Edit'),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Star rating row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starValue = index + 1;
                  final isSelected = _selectedStars >= starValue ||
                      (userRating != null && !_showReviewForm && userRating.rating >= starValue);
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedStars = starValue;
                        if (!_showReviewForm) _showReviewForm = true;
                      });
                    },
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                        child: Icon(
                          isSelected ? Icons.star_rounded : Icons.star_border_rounded,
                          key: ValueKey('$starValue-$isSelected'),
                          color: colorScheme.tertiary,
                          size: 40,
                        ),
                      ),
                    ),
                  );
                }),
              ),

              // Display current rating or show form
              if (userRating != null && !_showReviewForm) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'You rated ${userRating.rating} star${userRating.rating > 1 ? 's' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ),
                if (userRating.comment != null && userRating.comment!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      userRating.comment!,
                      style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
                    ),
                  ),
                ],
              ],

              // Review form
              if (_showReviewForm || (userRating == null && _selectedStars > 0)) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: 'Share your experience (optional)...',
                    hintStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.4)),
                    filled: true,
                    fillColor: colorScheme.primary.withValues(alpha: 0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.dividerColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_showReviewForm && userRating != null)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() {
                            _showReviewForm = false;
                            _selectedStars = userRating.rating;
                            _commentController.text = userRating.comment ?? '';
                          }),
                          child: const Text('Cancel'),
                        ),
                      ),
                    if (_showReviewForm && userRating != null) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _selectedStars > 0 && !_isSubmitting
                            ? () => _submitReview(userId)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(userRating != null ? 'Update Review' : 'Submit Review'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Reviews from others
        if (reviewsWithComments.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Reviews (${reviewsWithComments.length})',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          ...reviewsWithComments.take(5).map((review) => _ReviewCard(review: review)),
        ],
      ],
    );
  }

  Future<void> _submitReview(String userId) async {
    setState(() => _isSubmitting = true);
    try {
      final comment = _commentController.text.trim();
      await context.read<RatingService>().addOrUpdateRating(
        userId,
        widget.activityId,
        _selectedStars,
        comment: comment.isNotEmpty ? comment : null,
      );
      // Reload reviews
      if (mounted) {
        await context.read<RatingService>().loadActivityReviews(widget.activityId, force: true);
      }
      if (mounted) {
        setState(() {
          _showReviewForm = false;
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit review')),
        );
      }
    }
  }
}

class _ReviewCard extends StatelessWidget {
  final RatingModel review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timeAgo = _formatTimeAgo(review.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Star display
              Row(
                children: List.generate(5, (i) => Icon(
                  i < review.rating ? Icons.star_rounded : Icons.star_border_rounded,
                  color: colorScheme.tertiary,
                  size: 16,
                )),
              ),
              const Spacer(),
              Text(
                timeAgo,
                style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.comment!,
              style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}

/// Detail stat chip used on the activity details screen for quick facts
class DetailStatChip extends StatelessWidget {
final IconData icon;
final String label;
final String value;
final VoidCallback? onTap;
final Color? iconColor;
const DetailStatChip({super.key, required this.icon, required this.label, required this.value, this.onTap, this.iconColor});

@override
Widget build(BuildContext context) {
final theme = Theme.of(context);
final iconFg = iconColor ?? theme.colorScheme.primary;
return Material(
color: AppColors.lightSurface,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md), side: const BorderSide(color: AppColors.lightDivider)),
child: InkWell(
borderRadius: BorderRadius.circular(AppRadius.md),
onTap: onTap,
child: Padding(
padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
Container(
padding: const EdgeInsets.all(8),
decoration: BoxDecoration(color: iconFg.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
child: Icon(icon, color: iconFg, size: 18),
),
const SizedBox(width: 10),
Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(label, style: theme.textTheme.labelSmall?.copyWith(color: AppColors.lightSecondaryText)),
SizedBox(
width: 160,
child: Text(value, style: theme.textTheme.labelLarge?.copyWith(color: AppColors.lightPrimaryText, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
),
],
)
],
),
),
),
);
}
}
