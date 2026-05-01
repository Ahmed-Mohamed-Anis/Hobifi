import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:hobby_haven/nav.dart';
import 'package:hobby_haven/services/activity_service.dart';
import 'package:hobby_haven/services/auth_service.dart';
import 'package:hobby_haven/models/activity_model.dart';
import 'package:hobby_haven/theme.dart';
import 'package:hobby_haven/supabase/supabase_config.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hobby_haven/widgets/app_back_button.dart';
import 'package:hobby_haven/screens/business/activity_preview_screen.dart';
import 'package:hobby_haven/utils/input_sanitizer.dart';
import 'package:latlong2/latlong.dart';
import 'package:hobby_haven/widgets/location_picker.dart';

class CreateActivityScreen extends StatefulWidget {
  const CreateActivityScreen({super.key});

  @override
  State<CreateActivityScreen> createState() => _CreateActivityScreenState();
}

class _CreateActivityScreenState extends State<CreateActivityScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  double? _activityLat;
  double? _activityLng;
  final _priceController = TextEditingController();
  final _maxGuestsController = TextEditingController();
  String _selectedCategory = 'Art';
  bool _isInstantBooking = true;
  bool _isPublic = true;
  String? _imageUrl;
  final List<String> _imageUrls = [];
  bool _isUploading = false;

  static const List<String> _availableTags = [
    'Equipment Included',
    'Small Groups',
    'Beginner Friendly',
    'All Ages',
    'Materials Included',
    'Outdoor',
    'Indoor',
    'Wheelchair Accessible',
    'Refreshments Included',
  ];
  final Set<String> _selectedTags = {'Equipment Included', 'Small Groups'};

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);

  bool _repeats = false;
  String _frequency = 'weekly';
  DateTime? _repeatUntil;

  Future<String> _uploadBytes(Uint8List bytes, String filename) async {
    final auth = context.read<AuthService>();
    final userId = auth.currentUser?.id ?? 'anonymous';
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
      setState(() => _isUploading = true);
      final picker = ImagePicker();
      final pickedList = await picker.pickMultiImage(maxWidth: 1920, imageQuality: 85);
      if (pickedList.isEmpty) {
        setState(() => _isUploading = false);
        return;
      }

      for (final picked in pickedList) {
        final bytes = await picked.readAsBytes();
        final publicUrl = await _uploadBytes(bytes, picked.name);
        _imageUrls.add(publicUrl);
        _imageUrl ??= publicUrl;
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Failed to pick/upload images: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload images: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(now) ? _selectedDate : now,
      firstDate: now,
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

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push<LocationResult>(
      MaterialPageRoute(
        builder: (_) => LocationPickerWidget(
          initialLocation: _activityLat != null
              ? LatLng(_activityLat!, _activityLng!)
              : null,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _locationController.text = result.displayAddress;
        _activityLat = result.latitude;
        _activityLng = result.longitude;
      });
    }
  }

  List<DateTime> _occurrenceDates(DateTime start, String frequency, DateTime endInclusive) {
    final dates = <DateTime>[];
    var cursor = start;
    while (!cursor.isAfter(endInclusive)) {
      dates.add(cursor);
      switch (frequency) {
        case 'weekly':
          cursor = cursor.add(const Duration(days: 7));
        case 'biweekly':
          cursor = cursor.add(const Duration(days: 14));
        case 'monthly':
          cursor = DateTime(cursor.year, cursor.month + 1, cursor.day, cursor.hour, cursor.minute);
      }
    }
    return dates;
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

  String? _validateForm() {
    if (_titleController.text.trim().isEmpty) return 'Please enter a title';
    if (_titleController.text.trim().length < 3) return 'Title must be at least 3 characters';
    if (_titleController.text.trim().length > 100) return 'Title must be under 100 characters';
    if (_descriptionController.text.trim().isEmpty) return 'Please enter a description';
    if (_locationController.text.trim().isEmpty) return 'Please enter a location';

    final price = double.tryParse(_priceController.text);
    if (price == null || price < 0) return 'Please enter a valid price';

    final maxGuests = int.tryParse(_maxGuestsController.text);
    if (maxGuests == null || maxGuests < 1) return 'Max guests must be at least 1';

    final startAt = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _startTime.hour, _startTime.minute);
    final endAt = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _endTime.hour, _endTime.minute);

    if (!endAt.isAfter(startAt)) return 'End time must be after start time';
    if (startAt.isBefore(DateTime.now())) return 'Activity date must be in the future';

    return null;
  }

  ActivityModel _buildDraftActivity() {
    final authService = context.read<AuthService>();
    final now = DateTime.now();
    final startAt = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _startTime.hour, _startTime.minute);
    final endAt = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _endTime.hour, _endTime.minute);
    final dur = endAt.difference(startAt);
    final hours = dur.inMinutes / 60.0;
    final durationLabel = hours % 1 == 0 ? '${hours.toInt()}h' : '${hours.toStringAsFixed(1)}h';

    return ActivityModel(
      id: 'preview',
      businessId: authService.currentUser?.id ?? '',
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _selectedCategory,
      price: double.tryParse(_priceController.text) ?? 0,
      location: _locationController.text.trim(),
      imageUrl: _imageUrl ?? 'assets/images/pottery_class_hands_clay_null_1769445300693.jpg',
      imageUrls: List<String>.from(_imageUrls),
      rating: 0.0,
      reviewCount: 0,
      duration: durationLabel,
      maxGuests: int.tryParse(_maxGuestsController.text) ?? 10,
      spotsLeft: int.tryParse(_maxGuestsController.text) ?? 10,
      dateTime: startAt,
      startAt: startAt,
      endAt: endAt,
      isInstantBooking: _isInstantBooking,
      isPublic: _isPublic,
      features: _selectedTags.toList(),
      latitude: _activityLat,
      longitude: _activityLng,
      createdAt: now,
      updatedAt: now,
    );
  }

  void _handlePreview() {
    final error = _validateForm();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ActivityPreviewScreen(activity: _buildDraftActivity())),
    );
  }

  Future<void> _handleCreate() async {
    final error = _validateForm();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    final activityService = context.read<ActivityService>();
    final authService = context.read<AuthService>();
    final now = DateTime.now();

    try {
      final baseStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _startTime.hour, _startTime.minute);
      final baseEnd = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _endTime.hour, _endTime.minute);
      final dur = baseEnd.difference(baseStart);
      final hours = dur.inMinutes / 60.0;
      final durationLabel = hours % 1 == 0 ? '${hours.toInt()}h' : '${hours.toStringAsFixed(1)}h';

      List<DateTime> dates;
      if (_repeats) {
        if (_repeatUntil == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please pick an end date for the repeating activity.')),
          );
          return;
        }
        final endInclusive = DateTime(_repeatUntil!.year, _repeatUntil!.month, _repeatUntil!.day, 23, 59, 59);
        dates = _occurrenceDates(baseStart, _frequency, endInclusive);
        if (dates.length > 26) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please pick an earlier end date — max 26 sessions.')),
          );
          return;
        }
        if (dates.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('The end date must be on or after the start date.')),
          );
          return;
        }
      } else {
        dates = [baseStart];
      }

      int created = 0;
      for (final dt in dates) {
        final occurrenceStart = dt;
        final occurrenceEnd = dt.add(dur);
        final activity = ActivityModel(
          id: 'activity_${now.millisecondsSinceEpoch}_$created',
          businessId: authService.currentUser!.id,
          title: InputSanitizer.sanitize(_titleController.text, maxLength: 100),
          description: InputSanitizer.sanitize(_descriptionController.text, maxLength: 2000),
          category: _selectedCategory,
          price: double.tryParse(_priceController.text) ?? 0,
          location: _locationController.text.trim(),
          imageUrl: _imageUrl ?? 'assets/images/pottery_class_hands_clay_null_1769445300693.jpg',
          imageUrls: List<String>.from(_imageUrls),
          rating: 0.0,
          reviewCount: 0,
          duration: durationLabel,
          maxGuests: int.tryParse(_maxGuestsController.text) ?? 10,
          spotsLeft: int.tryParse(_maxGuestsController.text) ?? 10,
          dateTime: occurrenceStart,
          startAt: occurrenceStart,
          endAt: occurrenceEnd,
          isInstantBooking: _isInstantBooking,
          isPublic: _isPublic,
          features: _selectedTags.toList(),
          latitude: _activityLat,
          longitude: _activityLng,
          createdAt: now,
          updatedAt: now,
        );

        try {
          await activityService.createActivity(activity);
          created++;
        } catch (e) {
          debugPrint('Create activity (occurrence) error: $e');
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created $created session${created == 1 ? '' : 's'}.')),
      );
      context.go(AppRoutes.businessDashboard);
    } catch (e) {
      debugPrint('Create activity error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create activity: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dividerColor = colorScheme.outline.withValues(alpha: 0.2);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: AppSpacing.paddingLg,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: dividerColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const AppBackButton(),
                  Text(
                    'Create Activity',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: AppSpacing.paddingLg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FormLabel(label: 'Photos'),
                    Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(color: dividerColor, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (_imageUrls.isEmpty)
                              InkWell(
                                onTap: _isUploading ? null : _pickAndUploadImages,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo_rounded, color: colorScheme.primary, size: 32),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Upload Photos',
                                      style: theme.textTheme.labelLarge?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: _imageUrls.length + 1,
                                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                                        itemBuilder: (context, index) {
                                          if (index == _imageUrls.length) {
                                            return GestureDetector(
                                              onTap: _isUploading ? null : _pickAndUploadImages,
                                              child: Container(
                                                width: 120,
                                                decoration: BoxDecoration(
                                                  color: colorScheme.surfaceContainerLowest,
                                                  borderRadius: BorderRadius.circular(AppRadius.lg),
                                                  border: Border.all(color: dividerColor),
                                                ),
                                                child: Center(
                                                  child: Icon(Icons.add_rounded, color: colorScheme.primary),
                                                ),
                                              ),
                                            );
                                          }
                                          final url = _imageUrls[index];
                                          return ClipRRect(
                                            borderRadius: BorderRadius.circular(AppRadius.lg),
                                            child: Image.network(url, width: 180, height: 156, fit: BoxFit.cover),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (_isUploading)
                              Container(
                                color: Colors.black.withValues(alpha: 0.3),
                                child: const Center(child: CircularProgressIndicator()),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FormLabel(label: 'Activity Name'),
                    TextField(
                      controller: _titleController,
                      maxLength: 100,
                      decoration: const InputDecoration(hintText: 'e.g. Urban Pottery Workshop'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FormLabel(label: 'Category'),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          CategoryChip(label: 'Art', isSelected: _selectedCategory == 'Art', onTap: () => setState(() => _selectedCategory = 'Art')),
                          CategoryChip(label: 'Sports', isSelected: _selectedCategory == 'Sports', onTap: () => setState(() => _selectedCategory = 'Sports')),
                          CategoryChip(label: 'Music', isSelected: _selectedCategory == 'Music', onTap: () => setState(() => _selectedCategory = 'Music')),
                          CategoryChip(label: 'Cooking', isSelected: _selectedCategory == 'Cooking', onTap: () => setState(() => _selectedCategory = 'Cooking')),
                          CategoryChip(label: 'Tech', isSelected: _selectedCategory == 'Tech', onTap: () => setState(() => _selectedCategory = 'Tech')),
                          CategoryChip(label: 'Outdoor', isSelected: _selectedCategory == 'Outdoor', onTap: () => setState(() => _selectedCategory = 'Outdoor')),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FormLabel(label: 'Description'),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 4,
                      maxLength: 2000,
                      decoration: const InputDecoration(hintText: 'Describe what makes this activity special...'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FormLabel(label: 'Location'),
                    GestureDetector(
                      onTap: _pickLocation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(14),
                          color: colorScheme.surfaceContainerLowest,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_on_rounded,
                                color: colorScheme.onSurface.withValues(alpha: 0.5),
                                size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _locationController,
                                builder: (_, value, __) => Text(
                                  value.text.isEmpty ? 'Tap to set location on map' : value.text,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: value.text.isEmpty
                                        ? colorScheme.onSurface.withValues(alpha: 0.4)
                                        : colorScheme.onSurface,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded,
                                color: colorScheme.onSurface.withValues(alpha: 0.4)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FormLabel(label: 'Price (EGP)'),
                              TextField(
                                controller: _priceController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  hintText: '0.00',
                                  prefixIcon: Icon(Icons.payments_rounded),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FormLabel(label: 'Max Guests'),
                              TextField(
                                controller: _maxGuestsController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  hintText: '10',
                                  prefixIcon: Icon(Icons.group_rounded),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FormLabel(label: 'Schedule'),
                    Container(
                      padding: AppSpacing.paddingMd,
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(color: dividerColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              onPressed: _pickDate,
                              icon: Icon(Icons.event_rounded, color: colorScheme.primary),
                              label: Text(
                                '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                                style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.onSurface),
                              ),
                              style: TextButton.styleFrom(
                                backgroundColor: colorScheme.surfaceContainerLowest,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: _pickStartTime,
                              icon: Icon(Icons.schedule_rounded, color: colorScheme.primary),
                              label: Text(
                                _startTime.format(context),
                                style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.onSurface),
                              ),
                              style: TextButton.styleFrom(
                                backgroundColor: colorScheme.surfaceContainerLowest,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: _pickEndTime,
                              icon: Icon(Icons.schedule_rounded, color: colorScheme.primary),
                              label: Text(
                                _endTime.format(context),
                                style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.onSurface),
                              ),
                              style: TextButton.styleFrom(
                                backgroundColor: colorScheme.surfaceContainerLowest,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('This activity repeats'),
                      value: _repeats,
                      onChanged: (v) => setState(() => _repeats = v),
                    ),
                    if (_repeats) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _frequency,
                        decoration: const InputDecoration(labelText: 'Frequency'),
                        items: const [
                          DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                          DropdownMenuItem(value: 'biweekly', child: Text('Every 2 weeks')),
                          DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                        ],
                        onChanged: (v) => setState(() => _frequency = v ?? 'weekly'),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_rounded),
                        title: const Text('End date'),
                        subtitle: Text(_repeatUntil == null
                            ? 'Select'
                            : _repeatUntil!.toLocal().toString().split(' ').first),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(const Duration(days: 30)),
                            firstDate: DateTime.now().add(const Duration(days: 1)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) setState(() => _repeatUntil = picked);
                        },
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: AppSpacing.paddingLg,
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(color: dividerColor),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Instant Booking',
                                      style: theme.textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      'Users don\'t need to wait for your approval',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _isInstantBooking,
                                onChanged: (val) => setState(() => _isInstantBooking = val),
                                activeTrackColor: colorScheme.primary,
                              ),
                            ],
                          ),
                          Divider(color: dividerColor),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Public Activity',
                                      style: theme.textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      'Visible to all HOBIFI users',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _isPublic,
                                onChanged: (val) => setState(() => _isPublic = val),
                                activeTrackColor: colorScheme.primary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Features', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableTags.map((tag) {
                        final selected = _selectedTags.contains(tag);
                        return FilterChip(
                          label: Text(tag),
                          selected: selected,
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _selectedTags.add(tag);
                              } else {
                                _selectedTags.remove(tag);
                              }
                            });
                          },
                          selectedColor: colorScheme.primary.withValues(alpha: 0.15),
                          checkmarkColor: colorScheme.primary,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    OutlinedButton.icon(
                      onPressed: _handlePreview,
                      icon: const Icon(Icons.visibility_rounded),
                      label: const Text('Preview'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _handleCreate,
                      icon: const Icon(Icons.rocket_launch_rounded),
                      label: const Text('Launch Activity'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FormLabel extends StatelessWidget {
  final String label;

  const FormLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryChip({super.key, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary : colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: isSelected ? Colors.transparent : colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
