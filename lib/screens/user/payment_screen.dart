import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:hobby_haven/services/auth_service.dart';
import 'package:hobby_haven/services/booking_service.dart';
import 'package:hobby_haven/services/payment_service.dart';
import 'package:hobby_haven/models/booking_model.dart';
import 'package:hobby_haven/models/user_payment_method_model.dart';
import 'package:hobby_haven/theme.dart';
import 'package:hobby_haven/widgets/app_back_button.dart';
import 'package:hobby_haven/widgets/hobifi_shimmer.dart';

class PaymentScreen extends StatefulWidget {
  final String bookingId;
  final String activityId;
  final String paymentUrl;
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

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isLoading = false;
  bool _paymentCompleted = false;
  bool _paymentFailed = false;
  bool _isChecking = false;
  String? _errorMessage;
  Timer? _pollTimer;
  UserPaymentMethod? _selectedSavedCard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthService>().currentUser?.id;
      if (userId != null) {
        context.read<PaymentService>().loadSavedCards(userId);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    if (_pollTimer != null) return;
    setState(() => _isChecking = true);

    int attempts = 0;
    const maxAttempts = 20;

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
          _isChecking = false;
        });
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
          _isChecking = false;
          _errorMessage = 'Payment was not successful. Please try again.';
        });
      } else if (attempts >= maxAttempts) {
        timer.cancel();
        _pollTimer = null;
        setState(() => _isChecking = false);
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

  Future<void> _pay() async {
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final auth = context.read<AuthService>();
      final paymentService = context.read<PaymentService>();
      final user = auth.currentUser!;

      final result = await paymentService.initializePayment(
        bookingId: widget.bookingId,
        userId: user.id,
        activityId: widget.activityId,
        amount: widget.amount,
        activityTitle: widget.activityTitle,
        userEmail: user.email,
        userName: user.name,
        userPhone: user.phone ?? '',
        paymentMethod: _selectedSavedCard != null ? 'saved_card' : 'card',
        cardToken: _selectedSavedCard?.cardToken,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Saved card: if direct success, just poll; if 3DS needed, show WebView
      if (_selectedSavedCard != null) {
        if (result['success'] == true) {
          _startPolling();
        } else if (result['redirect_url'] != null) {
          await _showWebViewSheet(result['redirect_url'] as String);
        } else {
          setState(() => _errorMessage = 'Saved card payment failed. Please try with a new card.');
        }
        return;
      }

      // New card: show iframe in WebView sheet
      final iframeUrl = result['iframe_url'] as String?;
      if (iframeUrl == null || iframeUrl.isEmpty) {
        setState(() => _errorMessage = 'Payment URL not available. Please try again.');
        return;
      }
      await _showWebViewSheet(iframeUrl);
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = e.toString(); });
    }
  }

  Future<void> _showWebViewSheet(String url) async {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          final u = request.url.toLowerCase();
          if (u.contains('success=true') ||
              (u.contains('is_voided=false') && u.contains('pending=false'))) {
            Navigator.of(context).pop();
            _startPolling();
            return NavigationDecision.prevent;
          }
          if (u.contains('success=false')) {
            Navigator.of(context).pop();
            setState(() {
              _paymentFailed = true;
              _errorMessage = 'Payment was declined. Please try again.';
            });
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(url));

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.92,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), offset: const Offset(0, 2), blurRadius: 8),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                  const Icon(Icons.lock_rounded, size: 16, color: Colors.green),
                  const SizedBox(width: 6),
                  Text('Secure Payment · Paymob',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(ctx).pop()),
                ],
              ),
            ),
            Expanded(child: WebViewWidget(controller: controller)),
          ],
        ),
      ),
    );

    if (mounted && !_paymentCompleted && !_paymentFailed) {
      _startPolling();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                  child: const Icon(Icons.check_circle_rounded,
                      color: AppColors.lightSuccess, size: 80),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Payment Successful!',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    )),
                const SizedBox(height: AppSpacing.md),
                Text('Your ticket is ready',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    )),
                const SizedBox(height: AppSpacing.xl),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: colorScheme.primary),
                    const SizedBox(height: 16),
                    Text('Verifying payment...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        )),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

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
                    child: const Icon(Icons.error_outline_rounded,
                        color: AppColors.lightError, size: 80),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text('Payment Failed',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      )),
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
            Text('Payment',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                )),
            if (widget.activityTitle.isNotEmpty)
              Text(
                widget.activityTitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: AppSpacing.paddingMd,
              color: AppColors.lightError.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.lightError),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(_errorMessage!,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: AppColors.lightError)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.lightError),
                    onPressed: () => setState(() => _errorMessage = null),
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
                  _isChecking
                      ? HobifiShimmer.card()
                      : _OrderSummaryCard(
                          activityTitle: widget.activityTitle,
                          bookingId: widget.bookingId,
                          amount: widget.amount,
                        ),
                  const SizedBox(height: AppSpacing.xl),
                  // ── Saved cards ───────────────────────────────────────────
                  Consumer<PaymentService>(
                    builder: (_, paymentService, __) {
                      final saved = paymentService.savedCards;
                      if (saved.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Saved Cards',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: colorScheme.onSurface.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600,
                              )),
                          const SizedBox(height: 10),
                          ...saved.map((card) => _SavedCardTile(
                                card: card,
                                isSelected: _selectedSavedCard?.id == card.id,
                                onTap: () => setState(() {
                                  _selectedSavedCard =
                                      _selectedSavedCard?.id == card.id ? null : card;
                                }),
                              )),
                          const SizedBox(height: AppSpacing.md),
                          Divider(color: theme.dividerColor),
                          const SizedBox(height: AppSpacing.md),
                        ],
                      );
                    },
                  ),
                  // ── New card option ───────────────────────────────────────
                  GestureDetector(
                    onTap: () => setState(() => _selectedSavedCard = null),
                    child: Container(
                    padding: AppSpacing.paddingLg,
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _selectedSavedCard == null
                            ? colorScheme.primary
                            : colorScheme.outline.withValues(alpha: 0.2),
                        width: _selectedSavedCard == null ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.05), offset: const Offset(0, 2), blurRadius: 12),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.credit_card_rounded, color: colorScheme.primary, size: 22),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Pay with New Card',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: colorScheme.onSurface, fontWeight: FontWeight.bold,
                                  )),
                              const SizedBox(height: 2),
                              Text('Visa, Mastercard, Meeza',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                                  )),
                            ],
                          ),
                        ),
                        if (_selectedSavedCard == null)
                          Icon(Icons.check_circle_rounded, color: colorScheme.primary, size: 20),
                      ],
                    ),
                  ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_rounded,
                          size: 16,
                          color: colorScheme.onSurface.withValues(alpha: 0.4)),
                      const SizedBox(width: 6),
                      Text('Secured by Paymob',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.4),
                          )),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
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
                      onPressed: _isLoading || _isChecking ? null : _pay,
                      icon: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: colorScheme.onPrimary,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.payment_rounded),
                      label: Text(
                        _isLoading
                            ? 'Loading…'
                            : _selectedSavedCard != null
                                ? 'Pay EGP ${widget.amount.toStringAsFixed(2)} with ${_selectedSavedCard!.displayLabel}'
                                : 'Pay EGP ${widget.amount.toStringAsFixed(2)}',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.full),
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
                        Text('Checking payment status…',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                            )),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedCardTile extends StatelessWidget {
  final UserPaymentMethod card;
  final bool isSelected;
  final VoidCallback onTap;

  const _SavedCardTile({required this.card, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outline.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.credit_card_rounded, color: isSelected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.5), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                card.displayLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected) Icon(Icons.check_circle_rounded, color: colorScheme.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

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
              Text('Total Amount',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  )),
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
