import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hobby_haven/services/auth_service.dart';
import 'package:hobby_haven/services/wallet_service.dart';
import 'package:hobby_haven/theme.dart';
import 'package:hobby_haven/widgets/app_back_button.dart';
import 'package:intl/intl.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthService>();
      if (auth.currentUser != null) {
        context.read<WalletService>().loadWallet(auth.currentUser!.id, force: true);
      }
    });
  }

  void _showPayoutRequestSheet() {
    final walletService = context.read<WalletService>();
    final auth = context.read<AuthService>();
    final availableBalance = walletService.balance - walletService.pendingPayouts;

    if (availableBalance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No available balance for payout')),
      );
      return;
    }

    final amountController = TextEditingController(text: availableBalance.toStringAsFixed(2));
    final bankNameController = TextEditingController();
    final accountNumberController = TextEditingController();
    final holderNameController = TextEditingController(text: auth.currentUser?.name ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colorScheme = theme.colorScheme;
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Request Payout',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Available: \$${availableBalance.toStringAsFixed(2)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount', prefixText: '\$ '),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter amount';
                    final amount = double.tryParse(v);
                    if (amount == null || amount <= 0) return 'Invalid amount';
                    if (amount > availableBalance) return 'Exceeds available balance';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: bankNameController,
                  decoration: const InputDecoration(labelText: 'Bank Name'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: accountNumberController,
                  decoration: const InputDecoration(labelText: 'Account Number / IBAN'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: holderNameController,
                  decoration: const InputDecoration(labelText: 'Account Holder Name'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;

                      final amount = double.parse(amountController.text);
                      Navigator.of(ctx).pop();

                      final success = await walletService.requestPayout(
                        businessId: auth.currentUser!.id,
                        amount: amount,
                        bankName: bankNameController.text,
                        accountNumber: accountNumberController.text,
                        accountHolderName: holderNameController.text,
                      );

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success
                                ? 'Payout request submitted for review'
                                : 'Failed to submit request'),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                    ),
                    child: const Text('Submit Request'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final walletService = context.watch<WalletService>();

    return Scaffold(
      body: SafeArea(
        child: walletService.isLoading
            ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
            : RefreshIndicator(
                onRefresh: () async {
                  final auth = context.read<AuthService>();
                  if (auth.currentUser != null) {
                    await walletService.loadWallet(auth.currentUser!.id, force: true);
                  }
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Padding(
                        padding: AppSpacing.paddingLg,
                        child: Row(
                          children: [
                            const AppBackButton(),
                            const SizedBox(width: 12),
                            Text('Wallet', style: theme.textTheme.headlineMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            )),
                          ],
                        ),
                      ),

                      // Balance Card
                      Padding(
                        padding: AppSpacing.horizontalLg,
                        child: Container(
                          width: double.infinity,
                          padding: AppSpacing.paddingXl,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Available Balance',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '\$${walletService.balance.toStringAsFixed(2)}',
                                style: theme.textTheme.displayMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  _BalanceStat(
                                    label: 'Total Earned',
                                    value: '\$${walletService.totalEarned.toStringAsFixed(2)}',
                                  ),
                                  const SizedBox(width: 32),
                                  _BalanceStat(
                                    label: 'Withdrawn',
                                    value: '\$${walletService.totalWithdrawn.toStringAsFixed(2)}',
                                  ),
                                ],
                              ),
                              if (walletService.pendingPayouts > 0) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(AppRadius.full),
                                  ),
                                  child: Text(
                                    'Pending payouts: \$${walletService.pendingPayouts.toStringAsFixed(2)}',
                                    style: theme.textTheme.labelSmall?.copyWith(color: Colors.white),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: walletService.balance > 0 ? _showPayoutRequestSheet : null,
                                  icon: const Icon(Icons.account_balance_rounded, size: 20),
                                  label: const Text('Request Payout'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: colorScheme.primary,
                                    disabledBackgroundColor: Colors.white.withValues(alpha: 0.3),
                                    disabledForegroundColor: Colors.white.withValues(alpha: 0.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppRadius.full),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Payout Requests
                      if (walletService.payoutRequests.isNotEmpty) ...[
                        Padding(
                          padding: AppSpacing.horizontalLg,
                          child: Text('Payout Requests', style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          )),
                        ),
                        const SizedBox(height: 12),
                        ...walletService.payoutRequests.map((req) => Padding(
                          padding: AppSpacing.horizontalLg + const EdgeInsets.only(bottom: 8),
                          child: _PayoutRequestCard(request: req),
                        )),
                        const SizedBox(height: 16),
                      ],

                      // Transaction History
                      Padding(
                        padding: AppSpacing.horizontalLg,
                        child: Text('Transaction History', style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        )),
                      ),
                      const SizedBox(height: 12),
                      if (walletService.transactions.isEmpty)
                        Padding(
                          padding: AppSpacing.paddingXl,
                          child: Center(
                            child: Text(
                              'No transactions yet',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        )
                      else
                        ...walletService.transactions.map((tx) => Padding(
                          padding: AppSpacing.horizontalLg + const EdgeInsets.only(bottom: 8),
                          child: _TransactionCard(transaction: tx),
                        )),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  final String label;
  final String value;
  const _BalanceStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.7))),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final WalletTransaction transaction;
  const _TransactionCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEarning = transaction.type == 'earning';
    final icon = isEarning ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
    final color = isEarning ? AppColors.lightSuccess : AppColors.lightError;
    final sign = isEarning ? '+' : '-';

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description.isNotEmpty ? transaction.description : transaction.type.toUpperCase(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  DateFormat('MMM dd, yyyy · hh:mm a').format(transaction.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$sign\$${transaction.amount.toStringAsFixed(2)}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _PayoutRequestCard extends StatelessWidget {
  final PayoutRequest request;
  const _PayoutRequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color statusColor;
    IconData statusIcon;
    switch (request.status) {
      case 'approved':
        statusColor = Colors.blue;
        statusIcon = Icons.thumb_up_rounded;
      case 'completed':
        statusColor = AppColors.lightSuccess;
        statusIcon = Icons.check_circle_rounded;
      case 'rejected':
        statusColor = AppColors.lightError;
        statusIcon = Icons.cancel_rounded;
      default: // pending
        statusColor = Colors.orange;
        statusIcon = Icons.schedule_rounded;
    }

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payout to ${request.bankName}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${request.status.toUpperCase()} · ${DateFormat('MMM dd').format(request.requestedAt)}',
                  style: theme.textTheme.labelSmall?.copyWith(color: statusColor),
                ),
                if (request.adminNote != null && request.adminNote!.isNotEmpty)
                  Text(
                    request.adminNote!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '\$${request.amount.toStringAsFixed(2)}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
