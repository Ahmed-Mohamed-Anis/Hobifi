import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:hobby_haven/services/auth_service.dart';
import 'package:hobby_haven/services/booking_service.dart';
import 'package:hobby_haven/services/payment_service.dart';
import 'package:hobby_haven/models/booking_model.dart';
import 'package:hobby_haven/theme.dart';
import 'package:hobby_haven/widgets/app_back_button.dart';
import 'package:url_launcher/url_launcher.dart';

enum _PaymentMethod { card, wallet }

class PaymentScreen extends StatefulWidget {
  final String bookingId;
  final String activityId;
  final String paymentUrl; // pre-fetched card iframe URL
  final String activityTitle;
  final double amount;

  const PaymentScreen({
    super.key,
    required this.bookingId,
    required this.activityId,
    required this.paymentUrl,
    required this.activityTitle,
    required this.amount,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with WidgetsBindingObserver {
  _PaymentMethod _selectedMethod = _PaymentMethod.card;
  final _walletPhoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _paymentCompleted = false;
  bool _paymentFailed = false;
  bool _isChecking = false;
  bool _walletPending = false; // waiting for wallet app confirmation
  String? _errorMessage;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _walletPhoneController.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  // When user returns to app (from browser or wallet app), start polling
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_paymentCompleted &&
        !_paymentFailed) {
      _startPolling();
    }
  }

  void _startPolling() {
    if (_pollTimer != null) return; // already polling
    setState(() => _isChecking = true);

    int attempts = 0;
    const maxAttempts = 20; // 20 * 3s = 60s

    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      attempts++;
      final bookingService = context.read<BookingService>();
      final status = await bookingService.fetchBookingStatus(widget.bookingId);

      if (!mounted) {
        timer.cancel();
        _pollTimer = null;
        return;
      }

      if (status == BookingStatus.confirmed) {
        timer.cancel();
        _pollTimer = null;
        setState(() {
          _paymentCompleted = true;
          _walletPending = false;
          _isChecking = false;
        });
        // Reload all bookings in background so bookings list is fresh
        final userId = context.read<AuthService>().currentUser?.id ?? '';
        bookingService.loadUserBookings(userId, force: true);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) context.go('/ticket/${widget.bookingId}');
        });
      } else if (status == BookingStatus.cancelled) {
        timer.cancel();
        _pollTimer = null;
        setState(() {
          _paymentFailed = true;
          _walletPending = false;
          _isChecking = false;
          _errorMessage = 'Payment was not successful. Please try again.';
        });
      } else if (attempts >= maxAttempts) {
        timer.cancel();
        _pollTimer = null;
        setState(() {
          _isChecking = false;
          _walletPending = false;
        });
        if (mounted) _showTimeoutDialog();
      }
    });
  }

  void _showTimeoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Payment Processing'),
          content: const Text(
            'Your payment is still being processed. This can take a few minutes.\n\nYou can check your bookings later — we\'ll update the status automatically.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.pop();
              },
              child: const Text('Go to Bookings'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _startPolling();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: const Text('Keep Waiting'),
            ),
          ],
        );
      },
    );
  }

  // ── CARD FLOW ──────────────────────────────────────────────────────────────
  Future<void> _payWithCard() async {
    if (widget.paymentUrl.isEmpty) {
      setState(() => _errorMessage = 'Payment URL not available. Please try again.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse(widget.paymentUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        setState(() => _errorMessage = 'Could not open payment page.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to open payment: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── WALLET FLOW ────────────────────────────────────────────────────────────
  Future<void> _payWithWallet() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = context.read<AuthService>().currentUser!;
      final paymentService = context.read<PaymentService>();

      final data = await paymentService.initializePayment(
        bookingId: widget.bookingId,
        userId: user.id,
        activityId: widget.activityId,
        amount: widget.amount,
        activityTitle: widget.activityTitle,
        userEmail: user.email,
        userName: user.name,
        userPhone: user.phone ?? '',
        paymentMethod: 'wallet',
        walletPhone: _walletPhoneController.text.trim(),
      );

      final redirectUrl = data['redirect_url'] as String?;
      if (redirectUrl == null || redirectUrl.isEmpty) {
        throw Exception('No redirect URL returned from wallet payment.');
      }

      final uri = Uri.parse(redirectUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        // Show waiting state after opening wallet app
        if (mounted) setState(() => _walletPending = true);
      } else {
        throw Exception('Could not open wallet app.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handlePay() {
    if (_selectedMethod == _PaymentMethod.card) {
      _payWithCard();
    } else {
      _payWithWallet();
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Success state
    if (_paymentCompleted) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.lightSuccess.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.lightSuccess,
                    size: 80,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Payment Successful!',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Your ticket is ready',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                CircularProgressIndicator(
                    color: colorScheme.primary, strokeWidth: 2),
              ],
            ),
          ),
        ),
      );
    }

    // Failure state
    if (_paymentFailed) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: AppSpacing.paddingXl,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.lightError.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.lightError,
                      size: 80,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Payment Failed',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _errorMessage ?? 'Something went wrong. Please try again.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => context.pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                      ),
                      child: const Text('Go Back'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: AppBackButton(onPressed: () => context.pop()),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'EGP ${widget.amount.toStringAsFixed(2)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Error banner
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: AppSpacing.paddingMd,
                color: AppColors.lightError.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.lightError),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: AppColors.lightError),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: AppColors.lightError),
                      onPressed: () =>
                          setState(() => _errorMessage = null),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: SingleChildScrollView(
                padding: AppSpacing.paddingXl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.xl),

                    // ── Order Summary ─────────────────────────────────────
                    _OrderSummaryCard(
                      activityTitle: widget.activityTitle,
                      bookingId: widget.bookingId,
                      amount: widget.amount,
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ── Payment Method Selector ───────────────────────────
                    Text(
                      'Payment Method',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: _MethodTile(
                            icon: Icons.credit_card_rounded,
                            label: 'Card',
                            subtitle: 'Visa, MC, Meeza',
                            selected:
                                _selectedMethod == _PaymentMethod.card,
                            onTap: () => setState(() {
                              _selectedMethod = _PaymentMethod.card;
                              _errorMessage = null;
                            }),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _MethodTile(
                            icon: Icons.phone_android_rounded,
                            label: 'Wallet',
                            subtitle: 'Vodafone, Orange, Etisalat',
                            selected:
                                _selectedMethod == _PaymentMethod.wallet,
                            onTap: () => setState(() {
                              _selectedMethod = _PaymentMethod.wallet;
                              _errorMessage = null;
                            }),
                          ),
                        ),
                      ],
                    ),

                    // ── Wallet Phone Input (animated) ─────────────────────
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: _selectedMethod == _PaymentMethod.wallet
                          ? Padding(
                              padding: const EdgeInsets.only(
                                  top: AppSpacing.lg),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Wallet Phone Number',
                                    style: theme.textTheme.titleSmall
                                        ?.copyWith(
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  TextFormField(
                                    controller: _walletPhoneController,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(11),
                                    ],
                                    decoration: InputDecoration(
                                      hintText: '01xxxxxxxxx',
                                      prefixIcon: const Icon(
                                          Icons.phone_rounded),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                            color: theme.dividerColor),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                            color: colorScheme.primary,
                                            width: 2),
                                      ),
                                      filled: true,
                                      fillColor:
                                          colorScheme.surfaceContainerHighest,
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Please enter your wallet phone number';
                                      }
                                      if (!RegExp(r'^01[0125]\d{8}$')
                                          .hasMatch(value.trim())) {
                                        return 'Enter a valid Egyptian mobile number (e.g. 01xxxxxxxxx)';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    'You will receive a confirmation request in your wallet app.',
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),

                    // ── Wallet waiting message ────────────────────────────
                    if (_walletPending) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        padding: AppSpacing.paddingMd,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color:
                                  colorScheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                'Waiting for approval in your wallet app…',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.xl),

                    // Security badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_rounded,
                          size: 16,
                          color:
                              colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Secured by Paymob',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),

            // ── Bottom Pay Button ─────────────────────────────────────────
            Container(
              padding: AppSpacing.paddingLg,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _handlePay,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                _selectedMethod == _PaymentMethod.wallet
                                    ? Icons.phone_android_rounded
                                    : Icons.payment_rounded,
                              ),
                        label: Text(
                          _isLoading
                              ? (_selectedMethod == _PaymentMethod.wallet
                                  ? 'Sending request…'
                                  : 'Opening…')
                              : 'Pay EGP ${widget.amount.toStringAsFixed(2)}',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.full),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    if (_isChecking) ...[
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Checking payment status…',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
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

// ── Reusable Widgets ──────────────────────────────────────────────────────────

class _OrderSummaryCard extends StatelessWidget {
  final String activityTitle;
  final String bookingId;
  final double amount;

  const _OrderSummaryCard({
    required this.activityTitle,
    required this.bookingId,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.confirmation_number_rounded,
                    color: colorScheme.primary, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activityTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Booking #${bookingId.substring(0, 8).toUpperCase()}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Divider(color: theme.dividerColor),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                'EGP ${amount.toStringAsFixed(2)}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _MethodTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.08)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? colorScheme.primary : theme.dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurface.withValues(alpha: 0.5),
                  size: 22,
                ),
                const Spacer(),
                if (selected)
                  Icon(Icons.check_circle_rounded,
                      color: colorScheme.primary, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
