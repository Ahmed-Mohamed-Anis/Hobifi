import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:hobby_haven/services/auth_service.dart';
import 'package:hobby_haven/nav.dart';
import 'package:hobby_haven/theme.dart';

class BusinessOnboardingScreen extends StatefulWidget {
  const BusinessOnboardingScreen({super.key});

  @override
  State<BusinessOnboardingScreen> createState() => _BusinessOnboardingScreenState();
}

class _BusinessOnboardingScreenState extends State<BusinessOnboardingScreen> {
  int _step = 0;
  bool _saving = false;

  // Step 1
  final _nameController = TextEditingController();
  String? _category;
  String? _city;

  // Step 2
  final _descriptionController = TextEditingController();

  static const _categories = ['fitness', 'arts', 'food', 'music', 'outdoor', 'other'];
  static const _cities = ['Cairo', 'Alexandria', 'Giza', 'Other'];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _step1Valid =>
      _nameController.text.trim().isNotEmpty && _category != null && _city != null;

  Future<void> _finish({bool skippedStep2 = false}) async {
    setState(() => _saving = true);
    final auth = context.read<AuthService>();
    final result = await auth.completeBusinessOnboarding(
      businessName: _nameController.text.trim(),
      category: _category!,
      city: _city!,
      description: skippedStep2 ? null : _descriptionController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result['success'] == true) {
      context.go(AppRoutes.businessDashboard);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Could not save. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: _stepIndicator(active: true)),
                  const SizedBox(width: 8),
                  Expanded(child: _stepIndicator(active: _step >= 1)),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                _step == 0 ? 'Tell us about your business' : 'Introduce yourself',
                style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                _step == 0
                    ? 'This helps explorers find you.'
                    : 'Optional — skip if you\'re in a rush.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: _step == 0 ? _buildStep1() : _buildStep2(),
                ),
              ),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepIndicator({required bool active}) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: active
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Business name'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _category,
          decoration: const InputDecoration(labelText: 'Category'),
          items: [
            for (final c in _categories)
              DropdownMenuItem(value: c, child: Text(c[0].toUpperCase() + c.substring(1))),
          ],
          onChanged: (v) => setState(() => _category = v),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _city,
          decoration: const InputDecoration(labelText: 'City'),
          items: [for (final c in _cities) DropdownMenuItem(value: c, child: Text(c))],
          onChanged: (v) => setState(() => _city = v),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          maxLength: 240,
          decoration: const InputDecoration(
            labelText: 'Short description',
            hintText: 'What makes your hobby sessions special?',
          ),
        ),
        // Cover photo upload omitted — MVP
      ],
    );
  }

  Widget _buildActions() {
    if (_step == 0) {
      return FilledButton(
        onPressed: _step1Valid && !_saving ? () => setState(() => _step = 1) : null,
        child: const Text('Continue'),
      );
    }
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: _saving ? null : () => _finish(skippedStep2: true),
            child: const Text('Skip for now'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton(
            onPressed: _saving ? null : () => _finish(),
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Finish'),
          ),
        ),
      ],
    );
  }
}
