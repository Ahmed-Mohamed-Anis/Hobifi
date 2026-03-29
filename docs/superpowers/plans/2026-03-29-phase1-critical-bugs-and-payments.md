# Phase 1: Critical Bugs + Payment Flow — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all critical bugs in the booking/payment flow and complete the Paymob payment integration so the core loop (browse -> book -> pay -> attend) is reliable for production.

**Architecture:** All payment-critical logic lives server-side (Supabase DB functions + Deno edge functions). The Flutter client calls RPCs and edge functions but never directly manipulates payment/booking state. Spot reservation and booking creation are merged into a single atomic DB function. Payment timeout cleanup runs via pg_cron.

**Tech Stack:** Flutter/Dart (client), Supabase PostgreSQL (DB + RPC), Deno/TypeScript (edge functions), Paymob (payment gateway)

---

### Task 1: Add `payment_expires_at` column and booking cleanup cron

Adds a TTL to pending bookings so abandoned payments auto-cancel and release spots.

**Files:**
- Create: `lib/supabase/migrations/20260330_booking_expiry_cleanup.sql`
- Modify: `lib/models/booking_model.dart`

- [ ] **Step 1: Write the migration SQL**

Create file `lib/supabase/migrations/20260330_booking_expiry_cleanup.sql`:

```sql
-- Add payment expiry column to bookings
ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS payment_expires_at TIMESTAMPTZ;

-- Backfill: set expiry for any existing pending bookings (15 min from creation)
UPDATE bookings
SET payment_expires_at = created_at + INTERVAL '15 minutes'
WHERE status = 'pending' AND payment_expires_at IS NULL;

-- Add CHECK constraint: spots_left must never go negative
ALTER TABLE activities
  ADD CONSTRAINT chk_spots_left_non_negative CHECK (spots_left >= 0);

-- Cleanup function: cancels expired pending bookings and releases spots
CREATE OR REPLACE FUNCTION cleanup_expired_bookings()
RETURNS JSONB AS $$
DECLARE
  v_booking RECORD;
  v_count INTEGER := 0;
BEGIN
  FOR v_booking IN
    SELECT id, activity_id
    FROM bookings
    WHERE status = 'pending'
      AND payment_expires_at IS NOT NULL
      AND payment_expires_at < NOW()
    FOR UPDATE SKIP LOCKED
  LOOP
    -- Cancel the booking
    UPDATE bookings SET status = 'cancelled' WHERE id = v_booking.id;

    -- Release the spot
    PERFORM release_spot(v_booking.activity_id);

    -- Fail any associated pending payment
    UPDATE payments SET status = 'failed'
    WHERE booking_id = v_booking.id AND status IN ('pending', 'processing');

    v_count := v_count + 1;
  END LOOP;

  RETURN jsonb_build_object('cleaned_up', v_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Schedule cleanup every 5 minutes via pg_cron
-- NOTE: pg_cron must be enabled in Supabase dashboard (Database > Extensions > pg_cron)
-- Run this in the SQL editor after enabling pg_cron:
-- SELECT cron.schedule('cleanup-expired-bookings', '*/5 * * * *', 'SELECT cleanup_expired_bookings()');
```

- [ ] **Step 2: Run the migration in Supabase SQL editor**

Copy the SQL above into the Supabase SQL Editor and execute. Then enable pg_cron:
1. Go to Database > Extensions > enable `pg_cron`
2. Run: `SELECT cron.schedule('cleanup-expired-bookings', '*/5 * * * *', 'SELECT cleanup_expired_bookings()');`

Expected: No errors. Verify with `SELECT * FROM cron.job;` — should show the scheduled job.

- [ ] **Step 3: Update BookingModel to include `paymentExpiresAt`**

In `lib/models/booking_model.dart`, add the field:

```dart
class BookingModel {
  final String id;
  final String userId;
  final String activityId;
  final String activityTitle;
  final String activityImage;
  final String location;
  final double price;
  final DateTime dateTime;
  final BookingStatus status;
  final DateTime? paymentExpiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  BookingModel({
    required this.id,
    required this.userId,
    required this.activityId,
    required this.activityTitle,
    required this.activityImage,
    required this.location,
    required this.price,
    required this.dateTime,
    required this.status,
    this.paymentExpiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) => BookingModel(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    activityId: json['activity_id'] as String,
    activityTitle: json['activity_title'] as String,
    activityImage: json['activity_image'] as String,
    location: json['location'] as String,
    price: (json['price'] as num).toDouble(),
    dateTime: DateTime.parse(json['date_time'] as String),
    status: BookingStatus.values.firstWhere((e) => e.name == json['status'], orElse: () => BookingStatus.pending),
    paymentExpiresAt: json['payment_expires_at'] != null ? DateTime.parse(json['payment_expires_at'] as String) : null,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'activity_id': activityId,
    'activity_title': activityTitle,
    'activity_image': activityImage,
    'location': location,
    'price': price,
    'date_time': dateTime.toIso8601String(),
    'status': status.name,
    if (paymentExpiresAt != null) 'payment_expires_at': paymentExpiresAt!.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  BookingModel copyWith({
    String? id,
    String? userId,
    String? activityId,
    String? activityTitle,
    String? activityImage,
    String? location,
    double? price,
    DateTime? dateTime,
    BookingStatus? status,
    DateTime? paymentExpiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => BookingModel(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    activityId: activityId ?? this.activityId,
    activityTitle: activityTitle ?? this.activityTitle,
    activityImage: activityImage ?? this.activityImage,
    location: location ?? this.location,
    price: price ?? this.price,
    dateTime: dateTime ?? this.dateTime,
    status: status ?? this.status,
    paymentExpiresAt: paymentExpiresAt ?? this.paymentExpiresAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

enum BookingStatus {
  pending,
  confirmed,
  completed,
  cancelled
}
```

- [ ] **Step 4: Verify the app compiles**

Run: `cd /Users/anis/Developer/Hobifi && flutter analyze`
Expected: No new errors related to BookingModel.

- [ ] **Step 5: Commit**

```bash
git add lib/supabase/migrations/20260330_booking_expiry_cleanup.sql lib/models/booking_model.dart
git commit -m "feat: add payment expiry column and booking cleanup cron job"
```

---

### Task 2: Atomic booking creation with spot reservation

Merges `reserve_spot()` + booking INSERT into a single atomic RPC to eliminate race conditions.

**Files:**
- Create: `lib/supabase/migrations/20260330_atomic_booking_creation.sql`
- Modify: `lib/services/booking_service.dart`
- Modify: `lib/screens/user/booking_confirm_screen.dart`

- [ ] **Step 1: Write the atomic RPC migration**

Create file `lib/supabase/migrations/20260330_atomic_booking_creation.sql`:

```sql
-- Atomic booking creation: reserves spot + creates booking in one transaction.
-- Returns JSON: { "ok": true, "booking_id": "uuid" } or { "ok": false, "reason": "..." }
CREATE OR REPLACE FUNCTION create_booking_with_reservation(
  p_user_id UUID,
  p_activity_id UUID,
  p_activity_title TEXT,
  p_activity_image TEXT,
  p_location TEXT,
  p_price NUMERIC(10,2),
  p_date_time TIMESTAMPTZ
)
RETURNS JSONB AS $$
DECLARE
  v_spots INTEGER;
  v_booking_id UUID;
  v_expires_at TIMESTAMPTZ;
BEGIN
  -- Lock the activity row and check spots
  SELECT spots_left INTO v_spots
  FROM activities
  WHERE id = p_activity_id
  FOR UPDATE;

  IF v_spots IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'activity_not_found');
  END IF;

  IF v_spots <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'no_spots');
  END IF;

  -- Decrement spots
  UPDATE activities
  SET spots_left = spots_left - 1, updated_at = NOW()
  WHERE id = p_activity_id;

  -- Create booking with 15-minute payment window
  v_booking_id := gen_random_uuid();
  v_expires_at := NOW() + INTERVAL '15 minutes';

  INSERT INTO bookings (id, user_id, activity_id, activity_title, activity_image, location, price, date_time, status, payment_expires_at)
  VALUES (v_booking_id, p_user_id, p_activity_id, p_activity_title, p_activity_image, p_location, p_price, p_date_time, 'pending', v_expires_at);

  RETURN jsonb_build_object('ok', true, 'booking_id', v_booking_id, 'expires_at', v_expires_at);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

- [ ] **Step 2: Run migration in Supabase SQL editor**

Expected: Function created successfully.

- [ ] **Step 3: Add `createBookingAtomic` method to BookingService**

In `lib/services/booking_service.dart`, add a new method and update imports:

```dart
import 'package:flutter/foundation.dart';
import 'package:hobby_haven/models/booking_model.dart';
import 'package:hobby_haven/supabase/supabase_config.dart';

class BookingService extends ChangeNotifier {
  List<BookingModel> _bookings = [];
  List<BookingModel> _businessBookings = [];
  bool _isLoading = false;
  String? _loadedForUserId;

  List<BookingModel> get bookings => _bookings;
  List<BookingModel> get businessBookings => _businessBookings;
  bool get isLoading => _isLoading;

  /// Atomically reserves a spot and creates a booking in one transaction.
  /// Returns the result map with 'ok', 'booking_id', 'expires_at' on success,
  /// or 'ok' = false with 'reason' on failure.
  Future<Map<String, dynamic>> createBookingAtomic({
    required String userId,
    required String activityId,
    required String activityTitle,
    required String activityImage,
    required String location,
    required double price,
    required DateTime dateTime,
  }) async {
    try {
      final result = await SupabaseConfig.client.rpc(
        'create_booking_with_reservation',
        params: {
          'p_user_id': userId,
          'p_activity_id': activityId,
          'p_activity_title': activityTitle,
          'p_activity_image': activityImage,
          'p_location': location,
          'p_price': price,
          'p_date_time': dateTime.toIso8601String(),
        },
      );
      final map = Map<String, dynamic>.from(result as Map);
      if (map['ok'] == true) {
        await loadUserBookings(userId, force: true);
      }
      return map;
    } catch (e) {
      debugPrint('Failed to create atomic booking: $e');
      return {'ok': false, 'reason': 'exception', 'message': e.toString()};
    }
  }

  Future<void> loadUserBookings(String userId, {bool force = false}) async {
    // ... existing code unchanged ...
```

Keep all existing methods (`loadUserBookings`, `_autoCompleteExpiredBookings`, `loadBusinessBookings`, `getUserBookings`, `getBookingsByStatus`, `hasBookedActivity`, `createBooking`, `updateBookingStatus`, `deleteBooking`) unchanged.

- [ ] **Step 4: Update `booking_confirm_screen.dart` to use atomic RPC**

Replace the `_confirmAndPay` method in `lib/screens/user/booking_confirm_screen.dart`:

```dart
  Future<void> _confirmAndPay(ActivityModel activity) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final authService = context.read<AuthService>();
    final bookingService = context.read<BookingService>();
    final paymentService = context.read<PaymentService>();
    final activityService = context.read<ActivityService>();

    final user = authService.currentUser;
    if (user == null) return;

    String? bookingId;

    try {
      // Atomically reserve spot + create booking in one transaction
      final result = await bookingService.createBookingAtomic(
        userId: user.id,
        activityId: activity.id,
        activityTitle: activity.title,
        activityImage: activity.imageUrl,
        location: activity.location,
        price: activity.price,
        dateTime: activity.dateTime,
      );

      if (result['ok'] != true) {
        await activityService.refreshActivities();
        if (mounted) {
          final reason = result['reason'] as String? ?? 'unknown';
          final message = reason == 'no_spots'
              ? 'Sorry, this activity just sold out!'
              : 'Could not create booking. Please try again.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      bookingId = result['booking_id'] as String;

      // Initialize payment
      final paymentData = await paymentService.initializePayment(
        bookingId: bookingId,
        userId: user.id,
        activityId: activity.id,
        amount: activity.price,
        activityTitle: activity.title,
        userEmail: user.email,
        userName: user.name,
        userPhone: user.phone ?? '',
      );

      if (mounted) {
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
      debugPrint('Payment initialization failed: $e');
      // If booking was created but payment init failed, release the spot
      if (bookingId != null) {
        try {
          await SupabaseConfig.client.rpc(
            'release_spot',
            params: {'p_activity_id': activity.id},
          );
          await bookingService.updateBookingStatus(bookingId, BookingStatus.cancelled);
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process booking: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
```

- [ ] **Step 5: Verify compilation**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add lib/supabase/migrations/20260330_atomic_booking_creation.sql lib/services/booking_service.dart lib/screens/user/booking_confirm_screen.dart
git commit -m "feat: atomic booking creation with spot reservation RPC"
```

---

### Task 3: Payment completion polling

Replace the fragile `didChangeAppLifecycleState` approach with proper status polling.

**Files:**
- Modify: `lib/screens/user/payment_screen.dart`
- Modify: `lib/services/booking_service.dart`

- [ ] **Step 1: Add `fetchBookingStatus` method to BookingService**

Add this method to `lib/services/booking_service.dart` (after `createBookingAtomic`):

```dart
  /// Fetch a single booking's current status from the database.
  /// Used for polling payment status without reloading all bookings.
  Future<BookingStatus?> fetchBookingStatus(String bookingId) async {
    try {
      final data = await SupabaseService.selectSingle(
        'bookings',
        select: 'status',
        filters: {'id': bookingId},
      );
      if (data == null) return null;
      return BookingStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => BookingStatus.pending,
      );
    } catch (e) {
      debugPrint('Failed to fetch booking status: $e');
      return null;
    }
  }
```

- [ ] **Step 2: Rewrite payment status checking in payment_screen.dart**

Replace the `_checkPaymentStatus` method and add polling in `lib/screens/user/payment_screen.dart`:

```dart
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
```

Also remove the old `_checkPaymentStatus` and `_showStatusCheckDialog` methods.

- [ ] **Step 3: Verify compilation**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/user/payment_screen.dart lib/services/booking_service.dart
git commit -m "feat: poll booking status after payment instead of single lifecycle check"
```

---

### Task 4: Webhook error handling hardening

Make the webhook fail loudly so Paymob retries on critical errors.

**Files:**
- Modify: `lib/supabase/functions/paymob-webhook/index.ts`

- [ ] **Step 1: Harden HMAC verification and error responses**

Rewrite the main handler in `lib/supabase/functions/paymob-webhook/index.ts`. Replace the entire `serve` callback (lines 71-193). The key changes are:
1. HMAC verification returns 401 on failure (not just a log)
2. `credit_wallet()` failure returns 500 (triggers Paymob retry)
3. `release_spot()` failure returns 500 (triggers Paymob retry)
4. GET redirect ONLY returns HTML redirect — no DB mutations

```typescript
serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const hmacSecret = Deno.env.get("PAYMOB_HMAC_SECRET") || "";
  const supabase = createClient(supabaseUrl, supabaseKey);

  try {
    // ── GET: Browser redirect only — no DB mutations ──
    if (req.method === "GET") {
      const url = new URL(req.url);
      const success = url.searchParams.get("success") === "true";
      const merchantOrderId = url.searchParams.get("merchant_order_id") || "";
      // Return a simple HTML page that tells the user to return to the app
      const html = `<!DOCTYPE html><html><body style="display:flex;align-items:center;justify-content:center;height:100vh;font-family:sans-serif;">
        <div style="text-align:center;">
          <h2>${success ? "Payment Successful!" : "Payment Failed"}</h2>
          <p>${success ? "Please return to the Hobifi app to see your ticket." : "Please return to the Hobifi app to try again."}</p>
        </div>
      </body></html>`;
      return new Response(html, {
        status: 200,
        headers: { ...CORS_HEADERS, "Content-Type": "text/html" },
      });
    }

    // ── POST: Webhook (server-to-server) — requires HMAC ──
    if (!hmacSecret) {
      console.error("PAYMOB_HMAC_SECRET not configured");
      return new Response(
        JSON.stringify({ error: "Webhook signature verification not configured" }),
        { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const callbackData = await req.json();
    const receivedHmac = callbackData.hmac || "";

    const isValid = await verifyHmac(callbackData, receivedHmac, hmacSecret);
    if (!isValid) {
      console.error("HMAC verification failed — rejecting webhook");
      return new Response(
        JSON.stringify({ error: "Invalid HMAC signature" }),
        { status: 401, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const { obj } = callbackData;
    const transactionId = obj.id?.toString() || "";
    const orderId = obj.order?.merchant_order_id || obj.order?.id?.toString();
    const isSuccess = obj.success === true;
    const isPending = obj.pending === true;
    const paymentMethod = obj.source_data?.type || "card";

    console.log("Webhook received:", { transactionId, orderId, isSuccess, isPending });

    let status = "failed";
    if (isSuccess) status = "completed";
    else if (isPending) status = "processing";

    // Find payment by booking_id
    const { data: paymentData, error: findError } = await supabase
      .from("payments")
      .select("id, booking_id, activity_id, business_earnings, status")
      .eq("booking_id", orderId)
      .single();

    if (findError || !paymentData) {
      console.error("Payment not found for order:", orderId, findError);
      return new Response(
        JSON.stringify({ error: "Payment not found", orderId }),
        { status: 404, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // Idempotency: skip if already completed
    if (paymentData.status === "completed") {
      console.log("Payment already completed, skipping:", paymentData.id);
      return new Response(
        JSON.stringify({ success: true, status: "already_completed" }),
        { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // Update payment status
    const normalizedMethod = paymentMethod === "wallet" ? "wallet" : paymentMethod === "applepay" ? "applePay" : "card";
    const { error: updatePaymentError } = await supabase
      .from("payments")
      .update({ status, transaction_id: transactionId, payment_method: normalizedMethod })
      .eq("id", paymentData.id);

    if (updatePaymentError) {
      console.error("Failed to update payment:", updatePaymentError);
      return new Response(
        JSON.stringify({ error: "Failed to update payment record" }),
        { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // Update booking status
    const bookingStatus = isSuccess ? "confirmed" : isPending ? "pending" : "cancelled";
    const { error: updateBookingError } = await supabase
      .from("bookings")
      .update({ status: bookingStatus })
      .eq("id", paymentData.booking_id);

    if (updateBookingError) {
      console.error("Failed to update booking:", updateBookingError);
      return new Response(
        JSON.stringify({ error: "Failed to update booking record" }),
        { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // Release spot on failure
    if (!isSuccess && !isPending) {
      const { error: releaseError } = await supabase.rpc("release_spot", {
        p_activity_id: paymentData.activity_id,
      });
      if (releaseError) {
        console.error("Failed to release spot:", releaseError);
        return new Response(
          JSON.stringify({ error: "Failed to release spot — will retry" }),
          { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
      }
      console.log("Released spot for failed payment:", paymentData.booking_id);
    }

    // Credit business wallet on success
    if (isSuccess && paymentData.business_earnings > 0) {
      const { data: activity } = await supabase
        .from("activities")
        .select("business_id, title")
        .eq("id", paymentData.activity_id)
        .single();

      if (activity) {
        const { error: creditError } = await supabase.rpc("credit_wallet", {
          p_business_id: activity.business_id,
          p_amount: paymentData.business_earnings,
          p_booking_id: paymentData.booking_id,
          p_description: `Earning from booking: ${activity.title}`,
        });

        if (creditError) {
          console.error("credit_wallet failed:", creditError);
          return new Response(
            JSON.stringify({ error: "Failed to credit wallet — will retry" }),
            { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
          );
        }
        console.log(`Credited ${paymentData.business_earnings} to business ${activity.business_id}`);
      }
    }

    return new Response(
      JSON.stringify({ success: true, status, booking_id: paymentData.booking_id }),
      { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Webhook error:", error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : "Unknown error" }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }
});
```

- [ ] **Step 2: Also fix HMAC verifyHmac to reject (not warn) on missing data**

Replace lines 15-18 of `verifyHmac` function:

```typescript
async function verifyHmac(data: any, receivedHmac: string, hmacSecret: string): Promise<boolean> {
  if (!hmacSecret || !receivedHmac) {
    console.error("HMAC verification failed: missing secret or received HMAC");
    return false;
  }
```

(Change `console.warn` to `console.error` — this is now a hard rejection, not a soft warning.)

- [ ] **Step 3: Deploy the edge function**

Run: `supabase functions deploy paymob-webhook`
Expected: Function deployed successfully.

- [ ] **Step 4: Commit**

```bash
git add lib/supabase/functions/paymob-webhook/index.ts
git commit -m "fix: harden webhook error handling — fail loudly for Paymob retry"
```

---

### Task 5: Capacity reduction bug fix

Prevent negative `spots_left` when a host lowers `maxGuests`.

**Files:**
- Modify: `lib/screens/business/activity_manage_screen.dart`

- [ ] **Step 1: Fix the spots calculation in `_save()`**

In `lib/screens/business/activity_manage_screen.dart`, find the `_save()` method around line 286-310. Replace the `spotsLeft` calculation line (line 310):

Old:
```dart
        spotsLeft: (_activity!.spotsLeft + (maxGuests - _activity!.maxGuests)).clamp(0, maxGuests),
```

New:
```dart
        spotsLeft: () {
          final bookedCount = _activity!.maxGuests - _activity!.spotsLeft;
          return (maxGuests - bookedCount).clamp(0, maxGuests);
        }(),
```

- [ ] **Step 2: Add validation in `_validate()` to warn about overbooking**

In the `_validate()` method, after the maxGuests check (around line 272), add:

```dart
    final maxGuests = int.tryParse(_maxGuestsController.text);
    if (maxGuests == null || maxGuests < 1) return 'Max guests must be at least 1';

    // Check if reducing capacity below current bookings
    if (_activity != null) {
      final bookedCount = _activity!.maxGuests - _activity!.spotsLeft;
      if (maxGuests < bookedCount) {
        return 'Cannot reduce below $bookedCount (already booked). Cancel some bookings first.';
      }
    }
```

- [ ] **Step 3: Verify compilation**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/business/activity_manage_screen.dart
git commit -m "fix: prevent negative spots_left when reducing maxGuests"
```

---

### Task 6: Duplicate payment prevention

Add a partial unique index and make `paymob-init` handle conflicts atomically.

**Files:**
- Create: `lib/supabase/migrations/20260330_unique_pending_payment.sql`
- Modify: `lib/supabase/functions/paymob-init/index.ts`

- [ ] **Step 1: Write the migration for partial unique index**

Create file `lib/supabase/migrations/20260330_unique_pending_payment.sql`:

```sql
-- Prevent duplicate pending/processing payments for the same booking.
-- Only one active payment per booking at a time.
CREATE UNIQUE INDEX IF NOT EXISTS idx_payments_booking_active
  ON payments (booking_id)
  WHERE status IN ('pending', 'processing');
```

- [ ] **Step 2: Run migration in Supabase SQL editor**

Expected: Index created successfully.

- [ ] **Step 3: Update `paymob-init` to handle conflicts and return existing payment**

In `lib/supabase/functions/paymob-init/index.ts`, replace the "Save / update payment record" section (lines 130-161) with:

```typescript
    // ── Save / update payment record in DB ──────────────────────────────────
    const platformFee = Math.round(amount * 10) / 100;
    const businessEarnings = Math.round((amount - platformFee) * 100) / 100;

    // Check for existing active payment (pending/processing) for this booking
    const { data: existingPayment } = await supabase
      .from("payments")
      .select("id, transaction_id")
      .eq("booking_id", booking_id)
      .in("status", ["pending", "processing"])
      .maybeSingle();

    if (existingPayment) {
      // Update existing payment with new Paymob order/token
      const { error: updateError } = await supabase
        .from("payments")
        .update({
          transaction_id: orderId.toString(),
          payment_method,
        })
        .eq("id", existingPayment.id);
      if (updateError) console.error("Failed to update payment record:", updateError);
    } else {
      // Create new payment — the partial unique index prevents duplicates
      const { error: paymentError } = await supabase.from("payments").insert({
        booking_id,
        user_id,
        activity_id,
        amount,
        platform_fee: platformFee,
        business_earnings: businessEarnings,
        transaction_id: orderId.toString(),
        status: "pending",
        payment_method,
      });
      if (paymentError) {
        // If duplicate key error, fetch the existing one
        if (paymentError.code === "23505") {
          console.log("Duplicate payment prevented — using existing record");
        } else {
          console.error("Failed to create payment record:", paymentError);
        }
      }
    }
```

- [ ] **Step 4: Deploy the edge function**

Run: `supabase functions deploy paymob-init`
Expected: Function deployed successfully.

- [ ] **Step 5: Commit**

```bash
git add lib/supabase/migrations/20260330_unique_pending_payment.sql lib/supabase/functions/paymob-init/index.ts
git commit -m "fix: prevent duplicate payments with partial unique index"
```

---

### Task 7: Basic refund flow (server-side cancellation)

Create an edge function for cancellations that enforces the 24-hour policy and handles refunds.

**Files:**
- Create: `lib/supabase/migrations/20260330_refund_support.sql`
- Create: `lib/supabase/functions/process-cancellation/index.ts`
- Modify: `lib/services/booking_service.dart`
- Modify: `lib/screens/user/bookings_screen.dart`

- [ ] **Step 1: Write the refund support migration**

Create file `lib/supabase/migrations/20260330_refund_support.sql`:

```sql
-- Add refund tracking to payments
ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS refund_status TEXT NOT NULL DEFAULT 'none'
    CHECK (refund_status IN ('none', 'requested', 'processed'));

-- Debit wallet function (reverse of credit_wallet)
CREATE OR REPLACE FUNCTION debit_wallet(
  p_business_id UUID,
  p_amount DECIMAL(12,2),
  p_booking_id TEXT,
  p_description TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_balance DECIMAL(12,2);
BEGIN
  -- Lock wallet row
  SELECT balance INTO v_balance
  FROM business_wallets
  WHERE business_id = p_business_id
  FOR UPDATE;

  IF v_balance IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'wallet_not_found');
  END IF;

  IF v_balance < p_amount THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'insufficient_balance');
  END IF;

  -- Debit the wallet
  UPDATE business_wallets
  SET balance = balance - p_amount,
      total_withdrawn = total_withdrawn + p_amount,
      updated_at = NOW()
  WHERE business_id = p_business_id;

  -- Record the transaction
  INSERT INTO wallet_transactions (business_id, type, amount, reference_id, description)
  VALUES (p_business_id, 'refund_deduction', p_amount, p_booking_id, p_description);

  RETURN jsonb_build_object('ok', true, 'new_balance', v_balance - p_amount);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

- [ ] **Step 2: Run migration in Supabase SQL editor**

Expected: Column added, function created.

- [ ] **Step 3: Create the `process-cancellation` edge function**

Create file `lib/supabase/functions/process-cancellation/index.ts`:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Authenticate caller
    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(jwt);
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const { booking_id } = await req.json();
    if (!booking_id) {
      return new Response(
        JSON.stringify({ error: "booking_id is required" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // Fetch booking — must belong to the authenticated user
    const { data: booking, error: bookingError } = await supabase
      .from("bookings")
      .select("*")
      .eq("id", booking_id)
      .eq("user_id", user.id)
      .single();

    if (bookingError || !booking) {
      return new Response(
        JSON.stringify({ error: "Booking not found" }),
        { status: 404, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    if (booking.status === "cancelled" || booking.status === "completed") {
      return new Response(
        JSON.stringify({ error: `Booking is already ${booking.status}` }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // Check 24-hour cancellation policy
    const activityDate = new Date(booking.date_time);
    const now = new Date();
    const hoursUntil = (activityDate.getTime() - now.getTime()) / (1000 * 60 * 60);
    const isRefundEligible = hoursUntil >= 24;

    // Cancel the booking
    const { error: cancelError } = await supabase
      .from("bookings")
      .update({ status: "cancelled" })
      .eq("id", booking_id);

    if (cancelError) {
      return new Response(
        JSON.stringify({ error: "Failed to cancel booking" }),
        { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // Release the spot
    const { error: releaseError } = await supabase.rpc("release_spot", {
      p_activity_id: booking.activity_id,
    });
    if (releaseError) {
      console.error("Failed to release spot:", releaseError);
    }

    // Handle refund if eligible
    let refundStatus = "none";
    if (isRefundEligible) {
      // Find the completed payment for this booking
      const { data: payment } = await supabase
        .from("payments")
        .select("id, business_earnings, activity_id, status")
        .eq("booking_id", booking_id)
        .eq("status", "completed")
        .maybeSingle();

      if (payment) {
        // Mark payment for refund (admin processes actual Paymob refund manually)
        await supabase
          .from("payments")
          .update({ status: "refunded", refund_status: "requested" })
          .eq("id", payment.id);

        // Debit business wallet
        const { data: activity } = await supabase
          .from("activities")
          .select("business_id")
          .eq("id", payment.activity_id)
          .single();

        if (activity) {
          const { error: debitError } = await supabase.rpc("debit_wallet", {
            p_business_id: activity.business_id,
            p_amount: payment.business_earnings,
            p_booking_id: booking_id,
            p_description: `Refund deduction for cancelled booking`,
          });
          if (debitError) {
            console.error("Failed to debit wallet:", debitError);
          }
        }

        refundStatus = "requested";
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        refund_eligible: isRefundEligible,
        refund_status: refundStatus,
        message: isRefundEligible
          ? "Booking cancelled. Refund has been requested and will be processed."
          : "Booking cancelled. No refund — cancellation was less than 24 hours before the activity.",
      }),
      { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Cancellation error:", error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : "Unknown error" }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }
});
```

- [ ] **Step 4: Add `cancelBookingServerSide` to BookingService**

In `lib/services/booking_service.dart`, add:

```dart
  /// Cancel a booking via the server-side edge function.
  /// Enforces 24-hour cancellation policy and handles refunds.
  Future<Map<String, dynamic>> cancelBookingServerSide(String bookingId) async {
    try {
      final response = await http.post(
        Uri.parse('${SupabaseConfig.supabaseUrl}/functions/v1/process-cancellation'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${SupabaseConfig.auth.currentSession?.accessToken ?? SupabaseConfig.anonKey}',
          'apikey': SupabaseConfig.anonKey,
        },
        body: jsonEncode({'booking_id': bookingId}),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        // Reload bookings to reflect the change
        final userId = SupabaseConfig.auth.currentUser?.id;
        if (userId != null) {
          await loadUserBookings(userId, force: true);
        }
        return data;
      } else {
        return {'success': false, 'error': data['error'] ?? 'Cancellation failed'};
      }
    } catch (e) {
      debugPrint('Failed to cancel booking: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
```

Also add the import at the top of the file:

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
```

- [ ] **Step 5: Update bookings_screen.dart to use server-side cancellation**

In `lib/screens/user/bookings_screen.dart`, replace the cancellation handler in `_showCancelDialog` (the block starting at `if (confirmed == true && context.mounted)`):

```dart
    if (confirmed == true && context.mounted) {
      try {
        final bookingService = context.read<BookingService>();
        final activityService = context.read<ActivityService>();

        final result = await bookingService.cancelBookingServerSide(booking.id);

        await activityService.refreshActivities();

        if (context.mounted) {
          final message = result['message'] as String? ?? 'Booking cancelled';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to cancel: $e')),
          );
        }
      }
    }
```

- [ ] **Step 6: Deploy the edge function**

Run: `supabase functions deploy process-cancellation`
Expected: Function deployed successfully.

- [ ] **Step 7: Verify compilation**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 8: Commit**

```bash
git add lib/supabase/migrations/20260330_refund_support.sql lib/supabase/functions/process-cancellation/index.ts lib/services/booking_service.dart lib/screens/user/bookings_screen.dart
git commit -m "feat: server-side cancellation with 24h refund policy enforcement"
```

---

### Task 8: RLS policy fix for users table

Fix the overly permissive INSERT policy.

**Files:**
- Create: `lib/supabase/migrations/20260330_fix_users_insert_rls.sql`

- [ ] **Step 1: Write the migration**

Create file `lib/supabase/migrations/20260330_fix_users_insert_rls.sql`:

```sql
-- Fix: users INSERT policy was WITH CHECK (true) — any authenticated user
-- could create a profile for any user_id. Restrict to own ID only.
DROP POLICY IF EXISTS "Users can insert their own profile" ON users;

CREATE POLICY "Users can insert their own profile"
  ON users FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

-- Also tighten UPDATE's WITH CHECK to match USING
DROP POLICY IF EXISTS "Users can update their own profile" ON users;

CREATE POLICY "Users can update their own profile"
  ON users FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);
```

- [ ] **Step 2: Run migration in Supabase SQL editor**

Expected: Policies recreated.

- [ ] **Step 3: Commit**

```bash
git add lib/supabase/migrations/20260330_fix_users_insert_rls.sql
git commit -m "fix: tighten users INSERT/UPDATE RLS to auth.uid() = id"
```

---

### Task 9: Remove dummy Paymob fallbacks

Stop sending fake email/phone to Paymob — require real data.

**Files:**
- Modify: `lib/supabase/functions/paymob-init/index.ts`
- Modify: `lib/screens/user/booking_confirm_screen.dart`

- [ ] **Step 1: Update paymob-init to reject missing email/phone**

In `lib/supabase/functions/paymob-init/index.ts`, replace the billing_data section (around line 105-120):

```typescript
    // ── Step 3: Payment Key ─────────────────────────────────────────────────
    const nameParts = (user_name || "User").split(" ");
    const firstName = nameParts[0] || "User";
    const lastName = nameParts.slice(1).join(" ") || "User";

    // Require real user data — no dummy fallbacks
    const billingEmail = user_email || callerUser.email;
    if (!billingEmail) {
      return new Response(
        JSON.stringify({ error: "User email is required for payment" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const billingPhone = user_phone || "+201000000000"; // Phone is optional for card payments
    if (payment_method === "wallet" && (!wallet_phone || wallet_phone.length < 10)) {
      return new Response(
        JSON.stringify({ error: "Valid wallet phone number is required" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }
```

And update the billing_data to use `billingEmail` and `billingPhone`:

```typescript
        billing_data: {
          apartment: "NA",
          email: billingEmail,
          floor: "NA",
          first_name: firstName,
          street: "NA",
          building: "NA",
          phone_number: billingPhone,
          shipping_method: "NA",
          postal_code: "NA",
          city: "Cairo",
          country: "EG",
          last_name: lastName,
          state: "NA",
        },
```

- [ ] **Step 2: Remove hardcoded phone fallback in booking_confirm_screen.dart**

In `lib/screens/user/booking_confirm_screen.dart`, the `_confirmAndPay` method already passes `user.phone ?? ''` (from Task 2). Verify this is the case. If it still has `'+201000000000'`, change it to `''`.

- [ ] **Step 3: Deploy**

Run: `supabase functions deploy paymob-init`

- [ ] **Step 4: Commit**

```bash
git add lib/supabase/functions/paymob-init/index.ts lib/screens/user/booking_confirm_screen.dart
git commit -m "fix: require real email for Paymob, remove dummy fallbacks"
```

---

### Task 10: Payment model — add `refundStatus` field

Update the Dart model to handle the new `refund_status` column.

**Files:**
- Modify: `lib/models/payment_model.dart`

- [ ] **Step 1: Add `refundStatus` to PaymentModel**

In `lib/models/payment_model.dart`, add the field and enum:

After the `PaymentMethod` enum, add:

```dart
enum RefundStatus {
  none,
  requested,
  processed
}
```

Then add `refundStatus` to the `PaymentModel` class:

```dart
class PaymentModel {
  final String id;
  final String bookingId;
  final String userId;
  final String activityId;
  final double amount;
  final double platformFee;
  final double businessEarnings;
  final String transactionId;
  final PaymentStatus status;
  final PaymentMethod paymentMethod;
  final RefundStatus refundStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentModel({
    required this.id,
    required this.bookingId,
    required this.userId,
    required this.activityId,
    required this.amount,
    required this.platformFee,
    required this.businessEarnings,
    required this.transactionId,
    required this.status,
    required this.paymentMethod,
    this.refundStatus = RefundStatus.none,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) => PaymentModel(
    id: json['id'] as String,
    bookingId: json['booking_id'] as String,
    userId: json['user_id'] as String,
    activityId: json['activity_id'] as String,
    amount: (json['amount'] as num).toDouble(),
    platformFee: (json['platform_fee'] as num).toDouble(),
    businessEarnings: (json['business_earnings'] as num).toDouble(),
    transactionId: json['transaction_id'] as String? ?? '',
    status: PaymentStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => PaymentStatus.pending,
    ),
    paymentMethod: PaymentMethod.values.firstWhere(
      (e) => e.name == json['payment_method'],
      orElse: () => PaymentMethod.card,
    ),
    refundStatus: RefundStatus.values.firstWhere(
      (e) => e.name == (json['refund_status'] as String? ?? 'none'),
      orElse: () => RefundStatus.none,
    ),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'booking_id': bookingId,
    'user_id': userId,
    'activity_id': activityId,
    'amount': amount,
    'platform_fee': platformFee,
    'business_earnings': businessEarnings,
    'transaction_id': transactionId,
    'status': status.name,
    'payment_method': paymentMethod.name,
    'refund_status': refundStatus.name,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  PaymentModel copyWith({
    String? id,
    String? bookingId,
    String? userId,
    String? activityId,
    double? amount,
    double? platformFee,
    double? businessEarnings,
    String? transactionId,
    PaymentStatus? status,
    PaymentMethod? paymentMethod,
    RefundStatus? refundStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PaymentModel(
    id: id ?? this.id,
    bookingId: bookingId ?? this.bookingId,
    userId: userId ?? this.userId,
    activityId: activityId ?? this.activityId,
    amount: amount ?? this.amount,
    platformFee: platformFee ?? this.platformFee,
    businessEarnings: businessEarnings ?? this.businessEarnings,
    transactionId: transactionId ?? this.transactionId,
    status: status ?? this.status,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    refundStatus: refundStatus ?? this.refundStatus,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  static double calculateBusinessEarnings(double amount) => amount * 0.9;
  static double calculatePlatformFee(double amount) => amount * 0.1;
}
```

- [ ] **Step 2: Verify compilation**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/models/payment_model.dart
git commit -m "feat: add refundStatus field to PaymentModel"
```

---

## Dependency Graph

```
Task 1 (booking expiry + cleanup cron) ─── no deps
Task 2 (atomic booking RPC) ──────────── depends on Task 1 (uses payment_expires_at)
Task 3 (payment polling) ─────────────── depends on Task 2 (uses fetchBookingStatus)
Task 4 (webhook hardening) ───────────── no deps
Task 5 (capacity reduction fix) ──────── no deps
Task 6 (duplicate payment prevention) ── no deps
Task 7 (refund flow) ─────────────────── depends on Task 4 (webhook must be solid first)
Task 8 (RLS policy fix) ──────────────── no deps
Task 9 (remove Paymob fallbacks) ─────── depends on Task 2 (booking_confirm changes)
Task 10 (payment model refundStatus) ─── depends on Task 7 (refund migration)
```

**Parallelizable groups:**
- Group A: Tasks 1 → 2 → 3 → 9 (booking/payment flow)
- Group B: Tasks 4 → 7 → 10 (webhook/refund)
- Group C: Tasks 5, 6, 8 (independent fixes)
