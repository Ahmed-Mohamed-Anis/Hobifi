import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hobby_haven/models/activity_model.dart';
import 'package:hobby_haven/models/booking_model.dart';
import 'package:hobby_haven/services/activity_service.dart';
import 'package:hobby_haven/services/booking_service.dart';
import 'package:hobby_haven/supabase/supabase_config.dart';
import 'package:hobby_haven/theme.dart';
import 'package:hobby_haven/utils/booking_code.dart';
import 'package:hobby_haven/utils/input_sanitizer.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BusinessActivityScreen extends StatefulWidget {
  final String activityId;
  const BusinessActivityScreen({super.key, required this.activityId});

  @override
  State<BusinessActivityScreen> createState() => _BusinessActivityScreenState();
}

class _BusinessActivityScreenState extends State<BusinessActivityScreen> {
  ActivityModel? _activity;
  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;

  // Controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();
  final _maxGuestsController = TextEditingController();
  final _cancellationHoursController = TextEditingController();

  String _selectedCategory = 'Art';
  bool _isInstantBooking = true;
  bool _isPublic = true;

  // Schedule
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 11, minute: 0);

  // Images
  String? _primaryImageUrl;
  final List<String> _gallery = [];

  // Stats
  int _paidBookings = 0;
  double _earned = 0.0;
  int _likesCount = 0;
  double _avgRating = 0.0;
  int _ratingsCount = 0;
  List<BookingModel> _attendeeBookings = [];
  Map<String, Map<String, dynamic>> _attendeeUsers = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final activityService = context.read<ActivityService>();
    try {
      final fromDb = await SupabaseService.selectSingle('activities', filters: {'id': widget.activityId});
      ActivityModel? model;
      if (fromDb != null) {
        model = ActivityModel.fromJson(fromDb);
      } else {
        // Fallback to provider cache
        model = activityService.getActivityById(widget.activityId);
      }
      if (model == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Activity not found')));
        context.pop();
        return;
      }
      _applyModel(model);
      await _fetchStats(model.id);
    } catch (e) {
      debugPrint('BusinessActivityScreen _init error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyModel(ActivityModel model) {
    _activity = model;
    _titleController.text = model.title;
    _descriptionController.text = model.description;
    _locationController.text = model.location;
    _priceController.text = model.price.toStringAsFixed(2);
    _maxGuestsController.text = model.maxGuests.toString();
    _selectedCategory = model.category;
    _isInstantBooking = model.isInstantBooking;
    _isPublic = model.isPublic;

    _selectedDate = model.startAt ?? model.dateTime;
    final start = model.startAt ?? model.dateTime;
    final end = model.endAt ?? model.dateTime.add(const Duration(hours: 2));
    _startTime = TimeOfDay(hour: start.hour, minute: start.minute);
    _endTime = TimeOfDay(hour: end.hour, minute: end.minute);

    _cancellationHoursController.text = (model.cancellationHours).toString();

    _primaryImageUrl = model.imageUrl;
    _gallery
      ..clear()
      ..addAll(model.imageUrls);
  }

  Future<void> _fetchStats(String activityId) async {
    try {
      // Fetch bookings, payments, likes, and ratings in parallel
      final bookingsFuture = SupabaseService.from('bookings')
          .select('price,status')
          .eq('activity_id', activityId)
          .inFilter('status', ['confirmed', 'completed']);
      final paymentsFuture = SupabaseService.from('payments')
          .select('business_earnings,status')
          .eq('activity_id', activityId)
          .eq('status', 'completed');
      final likesFuture = SupabaseService.from('likes')
          .select('id')
          .eq('activity_id', activityId);
      final ratingsFuture = SupabaseService.from('ratings')
          .select('rating')
          .eq('activity_id', activityId);

      final results = await Future.wait([bookingsFuture, paymentsFuture, likesFuture, ratingsFuture]);
      
      final bookingsList = (results[0] as List).cast<Map<String, dynamic>>();
      final paymentsList = (results[1] as List).cast<Map<String, dynamic>>();
      final likesList = (results[2] as List);
      final ratingsList = (results[3] as List).cast<Map<String, dynamic>>();
      
      // Use payments table if available (has 10% already deducted), otherwise fallback to 90% of bookings
      double earnings;
      if (paymentsList.isNotEmpty) {
        earnings = paymentsList.fold<double>(0.0, (sum, row) => sum + ((row['business_earnings'] as num?)?.toDouble() ?? 0.0));
      } else {
        earnings = bookingsList.fold<double>(0.0, (sum, row) => sum + (((row['price'] as num?)?.toDouble() ?? 0.0) * 0.9));
      }

      // Calculate average rating
      double avgRating = 0.0;
      if (ratingsList.isNotEmpty) {
        final totalRating = ratingsList.fold<int>(0, (sum, row) => sum + (row['rating'] as int));
        avgRating = totalRating / ratingsList.length;
      }

      // Fetch attendees (users who booked)
      List<BookingModel> attendeeBookings = [];
      Map<String, Map<String, dynamic>> attendeeUsers = {};
      try {
        final bookingRows = await SupabaseConfig.client
            .from('bookings')
            .select()
            .eq('activity_id', activityId)
            .inFilter('status', ['confirmed', 'pending', 'completed']);
        attendeeBookings = (bookingRows as List)
            .map((row) => BookingModel.fromJson(Map<String, dynamic>.from(row as Map)))
            .toList();
        final userIds = attendeeBookings.map((b) => b.userId).toSet().toList();
        if (userIds.isNotEmpty) {
          final users = await SupabaseConfig.client
              .from('users')
              .select('id, name, avatar_url')
              .inFilter('id', userIds);
          final userList = (users as List).cast<Map<String, dynamic>>();
          for (final u in userList) {
            final uid = u['id'] as String?;
            if (uid != null) attendeeUsers[uid] = u;
          }
        }
      } catch (e) {
        debugPrint('Failed to fetch attendees: $e');
      }

      if (mounted) {
        setState(() {
          _paidBookings = bookingsList.length;
          _earned = earnings;
          _likesCount = likesList.length;
          _avgRating = avgRating;
          _ratingsCount = ratingsList.length;
          _attendeeBookings = attendeeBookings;
          _attendeeUsers = attendeeUsers;
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch activity stats: $e');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _maxGuestsController.dispose();
    _cancellationHoursController.dispose();
    super.dispose();
  }

  Future<String> _uploadBytes(Uint8List bytes, String filename) async {
    final userId = _activity?.businessId ?? 'anonymous';
    final path = 'activities/$userId/${DateTime.now().millisecondsSinceEpoch}_$filename';
    const targetBucket = 'activity-images';
    try {
      await SupabaseConfig.client.storage.from(targetBucket).uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );
      return SupabaseConfig.client.storage.from(targetBucket).getPublicUrl(path);
    } catch (e) {
      debugPrint('Upload to bucket "$targetBucket" failed: $e');
      if (e.toString().contains('Bucket not found') || e.toString().contains('relation "storage.buckets"')) {
        throw Exception('Storage bucket not set up. Please apply the pending migration from the Supabase panel.');
      }
      throw Exception('Failed to upload image: ${e.toString()}');
    }
  }

  Future<void> _pickAndUploadImages() async {
    try {
      setState(() => _uploading = true);
      final picker = ImagePicker();
      final pickedList = await picker.pickMultiImage(maxWidth: 1920, imageQuality: 85);
      if (pickedList.isEmpty) return;
      for (final picked in pickedList) {
        final bytes = await picked.readAsBytes();
        final publicUrl = await _uploadBytes(bytes, picked.name);
        _gallery.add(publicUrl);
        _primaryImageUrl ??= publicUrl;
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Failed to pick/upload images: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload images: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(now) ? _selectedDate : now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(context: context, initialTime: _startTime);
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(context: context, initialTime: _endTime);
    if (picked != null) setState(() => _endTime = picked);
  }

  String? _validateForm() {
    if (_titleController.text.trim().isEmpty) return 'Please enter a title';
    if (_titleController.text.trim().length < 3) return 'Title must be at least 3 characters';
    if (_descriptionController.text.trim().isEmpty) return 'Please enter a description';
    if (_locationController.text.trim().isEmpty) return 'Please enter a location';

    final price = double.tryParse(_priceController.text);
    if (price == null || price < 0) return 'Please enter a valid price';

    final maxGuests = int.tryParse(_maxGuestsController.text);
    if (maxGuests == null || maxGuests < 1) return 'Max guests must be at least 1';

    // Check if reducing capacity below current bookings
    if (_activity != null) {
      final bookedCount = _activity!.maxGuests - _activity!.spotsLeft;
      if (maxGuests < bookedCount) {
        return 'Cannot reduce below $bookedCount (already booked). Cancel some bookings first.';
      }
    }

    final startAt = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _startTime.hour, _startTime.minute);
    final endAt = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _endTime.hour, _endTime.minute);

    if (!endAt.isAfter(startAt)) return 'End time must be after start time';

    return null;
  }

  Future<void> _confirmMarkAttended(BuildContext context, BookingModel booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as attended?'),
        content: const Text("Confirm the guest has checked in. This can't be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mark attended')),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final bookingService = context.read<BookingService>();
    final result = await bookingService.markAttended(booking.id);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message']?.toString() ?? 'Done')),
    );

    if (result['success'] == true && mounted) {
      setState(() {
        final idx = _attendeeBookings.indexWhere((b) => b.id == booking.id);
        if (idx >= 0) {
          _attendeeBookings[idx] = _attendeeBookings[idx].copyWith(
            status: BookingStatus.completed,
            updatedAt: DateTime.now(),
          );
        }
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_activity == null) return;

    final validationError = _validateForm();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    final svc = context.read<ActivityService>();
    setState(() => _saving = true);
    try {
      final startAt = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _startTime.hour, _startTime.minute);
      final endAt = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _endTime.hour, _endTime.minute);
      final dur = endAt.difference(startAt);
      final hours = dur.inMinutes / 60.0;
      final durationLabel = hours % 1 == 0 ? '${hours.toInt()}h' : '${hours.toStringAsFixed(1)}h';

      final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
      final maxGuests = int.tryParse(_maxGuestsController.text.trim()) ?? 0;

      final updated = _activity!.copyWith(
        title: InputSanitizer.sanitize(_titleController.text.trim(), maxLength: 100),
        description: InputSanitizer.sanitize(_descriptionController.text.trim(), maxLength: 2000),
        location: InputSanitizer.sanitize(_locationController.text.trim(), maxLength: 200),
        category: _selectedCategory,
        price: price,
        maxGuests: maxGuests,
        spotsLeft: () {
          final bookedCount = _activity!.maxGuests - _activity!.spotsLeft;
          return (maxGuests - bookedCount).clamp(0, maxGuests);
        }(),
        startAt: startAt,
        endAt: endAt,
        dateTime: startAt,
        duration: durationLabel,
        isInstantBooking: _isInstantBooking,
        isPublic: _isPublic,
        imageUrl: _primaryImageUrl ?? _activity!.imageUrl,
        imageUrls: List<String>.from(_gallery),
        cancellationHours: int.tryParse(_cancellationHoursController.text) ?? 24,
        updatedAt: DateTime.now(),
      );

      await svc.updateActivity(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved changes')));
        setState(() => _activity = updated);
      }
    } catch (e) {
      debugPrint('Save changes error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteListing() async {
    if (_activity == null) return;
    final activityService = context.read<ActivityService>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete listing?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => context.pop(true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await activityService.deleteActivity(_activity!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing deleted')));
        context.pop();
      }
    } catch (e) {
      debugPrint('Delete activity failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBusy = _loading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Activity'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _activity == null ? null : _deleteListing,
          ),
        ],
      ),
      body: isBusy
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: AppSpacing.paddingLg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top stats - Row 1
                    Row(
                      children: [
                        Expanded(child: _StatChip(icon: Icons.event_available, label: 'Bookings', value: '$_paidBookings', iconColor: AppColors.lightPrimary)),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: _StatChip(icon: Icons.payments, label: 'Earnings', value: '\$${_earned.toStringAsFixed(0)}', iconColor: const Color(0xFF047E0D))),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Top stats - Row 2
                    Row(
                      children: [
                        Expanded(child: _StatChip(icon: Icons.favorite_rounded, label: 'Likes', value: '$_likesCount', iconColor: const Color(0xFFFF0000))),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: _StatChip(icon: Icons.star_rounded, label: 'Rating', value: _ratingsCount > 0 ? '${_avgRating.toStringAsFixed(1)} ($_ratingsCount)' : 'N/A', iconColor: AppColors.lightAccent)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Active / Paused toggle
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: _isPublic
                            ? Colors.green.withValues(alpha: 0.08)
                            : Colors.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isPublic
                              ? Colors.green.withValues(alpha: 0.3)
                              : Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isPublic ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                            color: _isPublic ? Colors.green : Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isPublic ? 'Active' : 'Paused',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: _isPublic ? Colors.green : Colors.orange,
                                  ),
                                ),
                                Text(
                                  _isPublic ? 'Visible to explorers' : 'Hidden from feed',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: _isPublic,
                            onChanged: (v) => setState(() => _isPublic = v),
                            activeTrackColor: Colors.green,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Who's Coming
                    if (_attendeeBookings.isNotEmpty) ...[
                      Row(
                        children: [
                          Text("Who's Coming", style: theme.textTheme.titleLarge),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_attendeeBookings.length}/${_activity?.maxGuests ?? '?'}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ..._attendeeBookings.map((booking) {
                        final colorScheme = theme.colorScheme;
                        final isAttended = booking.status == BookingStatus.completed;
                        final user = _attendeeUsers[booking.userId];
                        final name = (user?['name'] as String?) ?? 'Guest';
                        final avatar = user?['avatar_url'] as String?;
                        return Opacity(
                          opacity: isAttended ? 0.5 : 1.0,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                                  backgroundImage: (avatar != null && avatar.startsWith('http'))
                                      ? NetworkImage(avatar)
                                      : null,
                                  child: (avatar == null || !avatar.startsWith('http'))
                                      ? Icon(Icons.person_rounded, size: 20, color: colorScheme.primary)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        bookingCodeFor(booking.id),
                                        style: theme.textTheme.labelMedium?.copyWith(
                                          color: colorScheme.primary,
                                          letterSpacing: 2,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                isAttended
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: colorScheme.tertiary.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          'Checked in',
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: colorScheme.tertiary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      )
                                    : TextButton(
                                        onPressed: () => _confirmMarkAttended(context, booking),
                                        child: const Text('Mark attended'),
                                      ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    // Images
                    Text('Images', style: theme.textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final url in _gallery)
                          _ImageTile(
                            url: url,
                            isPrimary: url == _primaryImageUrl,
                            onSetPrimary: () => setState(() => _primaryImageUrl = url),
                            onRemove: () => setState(() => _gallery.remove(url)),
                          ),
                        _AddImageTile(uploading: _uploading, onTap: _pickAndUploadImages),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Basic info
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Description'),
                      minLines: 3,
                      maxLines: 6,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _locationController,
                      decoration: const InputDecoration(labelText: 'Location'),
                      textInputAction: TextInputAction.next,
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Category + visibility
                    Row(children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedCategory,
                          items: const [
                            DropdownMenuItem(value: 'Art', child: Text('Art')),
                            DropdownMenuItem(value: 'Sports', child: Text('Sports')),
                            DropdownMenuItem(value: 'Music', child: Text('Music')),
                            DropdownMenuItem(value: 'Cooking', child: Text('Cooking')),
                            DropdownMenuItem(value: 'Tech', child: Text('Tech')),
                            DropdownMenuItem(value: 'Outdoor', child: Text('Outdoor')),
                          ],
                          onChanged: (v) => setState(() => _selectedCategory = v ?? 'Art'),
                          decoration: const InputDecoration(labelText: 'Category'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: SwitchListTile(
                          title: const Text('Instant booking'),
                          value: _isInstantBooking,
                          onChanged: (v) => setState(() => _isInstantBooking = v),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ]),

                    SwitchListTile(
                      title: const Text('Public listing'),
                      value: _isPublic,
                      onChanged: (v) => setState(() => _isPublic = v),
                      contentPadding: EdgeInsets.zero,
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Price & capacity
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _priceController,
                          decoration: const InputDecoration(prefixText: '\$', labelText: 'Price'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextField(
                          controller: _maxGuestsController,
                          decoration: const InputDecoration(labelText: 'Max guests'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ]),

                    const SizedBox(height: AppSpacing.md),

                    TextField(
                      controller: _cancellationHoursController,
                      decoration: const InputDecoration(
                        labelText: 'Cancellation window (hours)',
                        prefixIcon: Icon(Icons.cancel_schedule_send_rounded),
                      ),
                      keyboardType: TextInputType.number,
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Schedule
                    Text('Schedule', style: theme.textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.sm),
                    Row(children: [
                      Expanded(
                        child: _PickerTile(
                          icon: Icons.calendar_today,
                          label: 'Date',
                          value: '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                          onTap: _pickDate,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _PickerTile(
                          icon: Icons.access_time,
                          label: 'Start',
                          value: _startTime.format(context),
                          onTap: _pickStartTime,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _PickerTile(
                          icon: Icons.access_time_filled,
                          label: 'End',
                          value: _endTime.format(context),
                          onTap: _pickEndTime,
                        ),
                      ),
                    ]),

                    const SizedBox(height: AppSpacing.xl),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
                        label: const Text('Save changes'),
                        onPressed: _saving ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
                      ),
                    ),
                  ],
                ),
              ),
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
    final color = iconColor ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AppColors.lightSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.lightDivider)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: theme.textTheme.labelLarge?.copyWith(color: AppColors.lightSecondaryText))),
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

class _ImageTile extends StatelessWidget {
  final String url;
  final bool isPrimary;
  final VoidCallback onSetPrimary;
  final VoidCallback onRemove;
  const _ImageTile({required this.url, required this.isPrimary, required this.onSetPrimary, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final isNetwork = url.startsWith('http');
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: isNetwork
              ? Image.network(url, width: 96, height: 96, fit: BoxFit.cover)
              : Image.asset(url, width: 96, height: 96, fit: BoxFit.cover),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: InkWell(
            onTap: onRemove,
            child: Container(
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
              padding: const EdgeInsets.all(4),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
        Positioned(
          bottom: 4,
          left: 4,
          child: InkWell(
            onTap: onSetPrimary,
            child: Container(
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(children: [
                Icon(isPrimary ? Icons.star : Icons.star_border, color: isPrimary ? Colors.amber : Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(isPrimary ? 'Primary' : 'Make primary', style: const TextStyle(color: Colors.white, fontSize: 11)),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddImageTile extends StatelessWidget {
  final bool uploading;
  final VoidCallback onTap;
  const _AddImageTile({required this.uploading, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: uploading ? null : onTap,
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.lightDivider),
            color: AppColors.lightSurface,
          ),
          child: Center(
            child: uploading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add_a_photo_outlined),
          ),
        ),
      );
}

class _PickerTile extends StatelessWidget {
  final IconData icon; final String label; final String value; final VoidCallback onTap;
  const _PickerTile({required this.icon, required this.label, required this.value, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.lightDivider)),
        child: Row(children: [
          Icon(icon, color: AppColors.lightHint),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      ),
    );
  }
}
