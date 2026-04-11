# Payment Perfection Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all payment flow bugs so card payments work end-to-end: correct pricing display, disable non-functional wallet option, and verify the full booking→payment→confirmation cycle.

**Architecture:** The payment flow is: BookingConfirmScreen → atomic booking RPC → paymob-init edge function → Paymob iframe (browser) → paymob-webhook callback → booking confirmed → polling detects success → ticket screen. We fix the UI layer (wrong prices, non-functional wallet option) and verify the backend is correctly wired.

**Tech Stack:** Flutter/Dart, Supabase Edge Functions (Deno/TypeScript), Paymob payment gateway

---

### Task 1: Fix price display on booking confirm screen

The confirm screen shows a fake "Platform fee" line item and inflated total to the user. The platform fee is actually deducted from the business's share — the user pays exactly the activity price. The UI must reflect this.

**Files:**
- Modify: `lib/screens/user/booking_confirm_screen.dart:131-133` (price calculation)
- Modify: `lib/screens/user/booking_confirm_screen.dart:276-312` (price breakdown UI)

- [ ] **Step 1: Remove platform fee from price calculation**

In `lib/screens/user/booking_confirm_screen.dart`, replace lines 131-133:

```dart
    final activityDate = activity.startAt ?? activity.dateTime;
    final platformFee = activity.price * 0.10;
    final total = activity.price + platformFee;
```

with:

```dart
    final activityDate = activity.startAt ?? activity.dateTime;
```

- [ ] **Step 2: Simplify the price breakdown UI**

Replace the price breakdown container (lines 274-313) — remove the "Platform fee" line and the divider/total row. Show just the single price:

```dart
                    // Price
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                            offset: const Offset(0, 2),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'EGP ${activity.price.toStringAsFixed(2)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
```

- [ ] **Step 3: Verify no other references to `platformFee` or `total` in this file**

Search for any remaining references to the removed variables. There should be none after the changes above.

- [ ] **Step 4: Hot-reload and verify**

Run the app, navigate to an activity → Book → Confirm screen. Verify:
- No "Platform fee" line
- Total shows exactly the activity price (e.g., "EGP 100.00")
- "Confirm & Pay" button still works

- [ ] **Step 5: Commit**

```bash
git add lib/screens/user/booking_confirm_screen.dart
git commit -m "fix: remove misleading platform fee from user-facing booking total

The platform fee is deducted from the business share, not charged to the user.
The confirm screen was showing an inflated total (price + 10%) that didn't match
what Paymob actually charges."
```

---

### Task 2: Disable wallet payment option in payment screen

Wallet payments require `PAYMOB_WALLET_INTEGRATION_ID` which is not configured. Remove the wallet option from the UI so users only see card payment.

**Files:**
- Modify: `lib/screens/user/payment_screen.dart`

- [ ] **Step 1: Remove wallet-related state and controllers**

In `_PaymentScreenState`, remove:
- The `_selectedMethod` field and `_PaymentMethod` enum usage
- The `_walletPhoneController` and `_formKey`
- The `_walletPending` state
- The `_payWithWallet()` method
- The `_handlePay()` method (replace with direct `_payWithCard` call)

- [ ] **Step 2: Remove wallet UI elements**

Remove from the `build` method:
- The "Payment Method" label and `Row` with `_MethodTile` selector (lines 428-466)
- The `AnimatedSize` wallet phone input section (lines 469-546)
- The wallet pending message container (lines 549-583)
- The `Form` wrapper (replace with just `Column`)

- [ ] **Step 3: Update pay button**

Change the pay button to call `_payWithCard()` directly instead of `_handlePay()`. Remove wallet-specific label text:

```dart
SizedBox(
  width: double.infinity,
  height: 56,
  child: ElevatedButton.icon(
    onPressed: _isLoading ? null : _payWithCard,
    icon: _isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          )
        : const Icon(Icons.payment_rounded),
    label: Text(
      _isLoading ? 'Opening…' : 'Pay EGP ${widget.amount.toStringAsFixed(2)}',
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
```

- [ ] **Step 4: Clean up unused imports and enum**

Remove:
- The `_PaymentMethod` enum at the top of the file
- The `flutter/services.dart` import (was only for `FilteringTextInputFormatter`)
- The `_MethodTile` widget class at the bottom of the file

- [ ] **Step 5: Hot-reload and verify**

Run the app, navigate to payment screen. Verify:
- Only card payment is shown (no wallet option)
- "Pay EGP X.XX" button opens the Paymob iframe in browser
- Polling still works when returning to the app

- [ ] **Step 6: Commit**

```bash
git add lib/screens/user/payment_screen.dart
git commit -m "fix: disable wallet payment option until integration ID is configured

Wallet payments (Vodafone Cash, Orange, etc.) require PAYMOB_WALLET_INTEGRATION_ID
which is not yet set. Remove the option from UI to prevent user-facing errors."
```

---

### Task 3: End-to-end payment test with Paymob

This is a manual verification task — no code changes, just testing the full flow.

**Prerequisites:** Paymob dashboard must have the webhook callback URL set to:
`https://cetytjbfjtpltdcfkilg.supabase.co/functions/v1/paymob-webhook`

- [ ] **Step 1: Verify webhook URL is configured in Paymob dashboard**

The user must confirm this is set. Without it, payments succeed in Paymob but bookings stay "pending".

- [ ] **Step 2: Test a card payment end-to-end**

1. Open the app (Chrome or device)
2. Log in as a user (Explorer role)
3. Find an activity with available spots
4. Tap Book → Confirm & Pay
5. Verify the total shown matches the activity price (no platform fee added)
6. Tap "Pay EGP X.XX" — Paymob iframe should open
7. Use a real or test card
8. After payment, return to the app
9. Polling should detect the payment and show "Payment Successful!"
10. Should redirect to ticket screen

- [ ] **Step 3: Verify webhook processed correctly**

Check Supabase logs for the webhook:

```bash
supabase functions logs paymob-webhook --project-ref cetytjbfjtpltdcfkilg
```

Verify:
- HMAC verification passed
- Payment status updated to "completed"
- Booking status updated to "confirmed"
- Business wallet credited

- [ ] **Step 4: Verify booking shows as confirmed**

In the app, check the user's bookings list. The booking should show as "Confirmed" with a valid ticket.

- [ ] **Step 5: Test cancellation flow**

1. Find a confirmed booking more than 24h before the activity
2. Cancel it
3. Verify refund is marked as "requested"
4. Verify business wallet was debited

---

### Task 4: Fix webhook order ID lookup (potential bug)

The webhook currently looks up payments by `booking_id` using the `merchant_order_id` from Paymob. But `paymob-init` sets `merchant_order_id` to `booking_id` while storing the Paymob `orderId` as `transaction_id`. Need to verify this lookup path works.

**Files:**
- Read: `lib/supabase/functions/paymob-webhook/index.ts:119-135`

- [ ] **Step 1: Trace the lookup chain**

In `paymob-init`:
- `merchant_order_id` is set to `booking_id` (line 102)
- `transaction_id` in DB is set to `orderId.toString()` (Paymob order ID) (line 250)

In `paymob-webhook`:
- `orderId = obj.order?.merchant_order_id || obj.order?.id?.toString()` (line 119)
- Looks up: `.eq("booking_id", orderId)` (line 135)

This should work because `merchant_order_id = booking_id` and the query uses `booking_id`. Verify by checking the actual Paymob callback payload structure in logs.

- [ ] **Step 2: Check Supabase edge function logs after a test payment**

```bash
supabase functions logs paymob-webhook --project-ref cetytjbfjtpltdcfkilg
```

Look for the "Webhook received:" log line. Confirm `orderId` matches the booking UUID.

- [ ] **Step 3: If lookup fails, fix the query**

If `merchant_order_id` comes back as the Paymob order ID (not booking_id), we need to change the webhook to look up by `transaction_id` instead:

```typescript
// Change from:
.eq("booking_id", orderId)
// To:
.eq("transaction_id", orderId)
```

Only apply this fix if the test in Step 2 reveals a mismatch. Do NOT change speculatively.
