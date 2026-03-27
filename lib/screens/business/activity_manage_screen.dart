import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hobby_haven/models/activity_model.dart';
import 'package:hobby_haven/services/activity_service.dart';
import 'package:hobby_haven/supabase/supabase_config.dart';
import 'package:hobby_haven/theme.dart';
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

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final fromDb = await SupabaseService.selectSingle('activities', filters: {'id': widget.activityId});
      ActivityModel? model;
      if (fromDb != null) {
        model = ActivityModel.fromJson(fromDb);
      } else {
        // Fallback to provider cache
        final svc = context.read<ActivityService>();
        model = svc.getActivityById(widget.activityId);
      }
      if (model == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Activity not found')));
          context.pop();
        }
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

      if (mounted) setState(() {
        _paidBookings = bookingsList.length;
        _earned = earnings;
        _likesCount = likesList.length;
        _avgRating = avgRating;
        _ratingsCount = ratingsList.length;
      });
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
    super.dispose();
  }

  Future<String> _uploadBytes(Uint8List bytes, String filename, {String mimeType = 'image/jpeg'}) async {
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

  Future<void> _saveChanges() async {
    if (_activity == null) return;
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
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        category: _selectedCategory,
        price: price,
        maxGuests: maxGuests,
        spotsLeft: maxGuests < _activity!.maxGuests ? _activity!.spotsLeft.clamp(0, maxGuests) : _activity!.spotsLeft,
        startAt: startAt,
        endAt: endAt,
        dateTime: startAt,
        duration: durationLabel,
        isInstantBooking: _isInstantBooking,
        isPublic: _isPublic,
        imageUrl: _primaryImageUrl ?? _activity!.imageUrl,
        imageUrls: List<String>.from(_gallery),
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
      await context.read<ActivityService>().deleteActivity(_activity!.id);
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
                    const SizedBox(height: AppSpacing.lg),

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
                          value: _selectedCategory,
                          items: const [
                            DropdownMenuItem(value: 'Art', child: Text('Art')),
                            DropdownMenuItem(value: 'Music', child: Text('Music')),
                            DropdownMenuItem(value: 'Outdoor', child: Text('Outdoor')),
                            DropdownMenuItem(value: 'Cooking', child: Text('Cooking')),
                            DropdownMenuItem(value: 'Tech', child: Text('Tech')),
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
