# Hobifi MVP Gap Analysis & Remediation Design

**Date:** 2026-03-29
**Status:** Draft
**Context:** Activity booking app (Flutter + Supabase + Paymob), launching in Egypt (EGP), App Store + Play Store. Both Explorer (user) and Host (business) roles in MVP.

---

## Phase 1: Critical Bugs + Payment Flow Completion

The core booking loop (browse -> book -> pay -> attend) must be reliable before anything else.

### 1.1 Payment Timeout & Orphaned Booking Cleanup

**Problem:** Booking is created with `status: pending` and spot is reserved before payment. If user abandons payment, booking and spot are locked forever.

**Solution:**
- Add a `payment_expires_at` column to bookings (default: `created_at + 15 minutes`)
- Create a Supabase DB function `cleanup_expired_bookings()` that:
  - Finds bookings where `status = 'pending'` AND `payment_expires_at < now()`
  - Updates status to `cancelled`
  - Calls `release_spot()` for each
  - Updates associated payment records to `failed`
- Trigger via Supabase `pg_cron` extension (runs every 5 minutes)
- Client-side: show countdown timer on payment screen; if expired, pop back with "Payment expired" message

### 1.2 Payment Completion Detection

**Problem:** After paying in external browser, app uses `didChangeAppLifecycleState` to reload all bookings — fragile, no polling, misses webhook delays.

**Solution:**
- After returning from payment browser, poll the specific booking status every 3 seconds for up to 60 seconds
- Show a "Verifying payment..." loading state during polling
- If confirmed within window -> navigate to ticket screen
- If still pending after 60s -> show "Payment is being processed, we'll notify you" message
- If failed/cancelled -> show error with option to retry payment

### 1.3 Webhook Error Handling Hardening

**Problem:** `paymob-webhook` returns 200 even when `credit_wallet()` or `release_spot()` fails. HMAC verification doesn't hard-reject.

**Solution:**
- Hard-reject requests with missing or invalid HMAC (return 401, not warning log)
- If `credit_wallet()` fails: return 500 so Paymob retries the webhook (Paymob retries on non-2xx)
- If `release_spot()` fails on failed payment: return 500 for retry
- Add a `webhook_processing_log` table to track webhook attempts and failures for debugging
- Distinguish 4xx (bad request, missing fields) from 5xx (internal failure, retry-worthy)

### 1.4 Spot Reservation Race Condition

**Problem:** `reserve_spot()` RPC is called from `booking_confirm_screen.dart` but not from `BookingService.createBooking()`. Concurrent booking possible.

**Solution:**
- Create a single atomic DB function `create_booking_with_reservation(p_user_id, p_activity_id, ...)` that:
  - Calls `reserve_spot()` within the same transaction
  - Creates booking row
  - Returns booking ID or error
- Remove separate `reserve_spot()` call from client code
- `BookingService.createBooking()` calls this single RPC
- On payment failure, webhook calls `release_spot()` (already exists)

### 1.5 Capacity Reduction Bug

**Problem:** In `activity_manage_screen.dart`, lowering `maxGuests` can produce negative `spotsLeft`.

**Solution:**
- Calculate: `bookedCount = maxGuests - spotsLeft` (current bookings)
- New `spotsLeft = max(0, newMaxGuests - bookedCount)`
- If `newMaxGuests < bookedCount`, warn host: "You have {bookedCount} confirmed bookings. Cannot reduce below that."
- Enforce this in both client validation and a DB CHECK constraint: `spots_left >= 0`

### 1.6 Duplicate Payment Prevention

**Problem:** User can tap "Pay" multiple times. `paymob-init` checks for existing pending payment but the check-then-insert isn't atomic.

**Solution:**
- Add UNIQUE constraint on `payments(booking_id)` where `status IN ('pending', 'processing')`  (partial unique index)
- In `paymob-init`: use `INSERT ... ON CONFLICT DO NOTHING` and return existing payment URL if one exists
- Client-side: disable pay button after first tap, show loading state

### 1.7 Basic Refund Flow

**Problem:** DB schema supports refunds but no service code exists. 24-hour cancellation policy is cosmetic only.

**Solution (MVP-minimal):**
- Server-side cancellation logic in a new edge function `process-cancellation`:
  - If cancellation > 24 hours before activity: full refund eligible
  - If < 24 hours: no refund (enforce this, don't just warn)
  - Update booking status to `cancelled`
  - Call `release_spot()`
  - Update payment status to `refunded`
  - Debit business wallet via new `debit_wallet()` RPC
  - Actual Paymob refund: for MVP, flag for manual processing (admin reviews `refund_requested` payments)
- Add `refund_status` column to payments: `none | requested | processed`
- Client: `BookingService.cancelBooking()` calls edge function instead of direct status update

---

## Phase 2: Security Hardening

### 2.1 RLS Policy Fixes

**users table INSERT:**
```sql
WITH CHECK (auth.uid() = id)
```

**activities table INSERT/UPDATE:**
```sql
WITH CHECK (business_id = auth.uid())
```

**Verify all other policies** — the `20260329_fix_rls_service_role` migration fixed wallet/payment policies. Confirm no regressions.

### 2.2 Input Validation

- Activity title: 3-100 chars, strip HTML tags
- Activity description: max 2000 chars, strip HTML
- Review comments: max 500 chars, strip HTML
- User bio: already 200 char limit, add HTML stripping
- Validate all string inputs server-side (DB CHECK constraints or edge function validation)

### 2.3 Booking Verification Gate on Reviews

- Add DB constraint: rating can only be inserted if a completed booking exists for that user + activity pair
- RLS policy on ratings INSERT: `EXISTS (SELECT 1 FROM bookings WHERE user_id = auth.uid() AND activity_id = ratings.activity_id AND status = 'completed')`

### 2.4 Paymob User Data Validation

- Require phone number for wallet payments (already partially done, enforce it)
- Use real user email from auth (already done in edge function)
- Remove dummy fallbacks (`+201000000000`, `user@example.com`) — return error if data missing

### 2.5 Cancellation Policy Enforcement

- Move cancellation logic server-side (covered in 1.7)
- Remove client-side cancellation that bypasses policy
- `BookingService.cancelBooking()` must go through edge function, not direct DB update

---

## Phase 3: MVP Feature Gaps

### 3.1 Crash Reporting (Firebase Crashlytics)

- Add `firebase_crashlytics` package
- Initialize in `main.dart`
- Wrap `runApp` in `runZonedGuarded` for async error capture
- Add `FlutterError.onError` handler
- Critical for diagnosing production issues

### 3.2 Basic Push Notifications (FCM)

- Add `firebase_messaging` package
- Store FCM token in `users` table (new column `fcm_token`)
- Send notifications from webhook/edge functions for:
  - Booking confirmed (payment success)
  - Booking cancelled (by host or system)
  - Payout processed (admin action)
- MVP scope: server-triggered only, no in-app notification center

### 3.3 Host Activity Cancellation

- New flow in `activity_manage_screen.dart`: "Cancel Activity" button
- Edge function `cancel-activity`:
  - Find all confirmed/pending bookings
  - Cancel each booking
  - Trigger refund for each (flag for manual processing in MVP)
  - Release all spots
  - Mark activity as cancelled (new status or `is_public = false`)
  - Send push notification to all affected users

### 3.4 Network Error Handling

- Add a connection status provider (listen to connectivity changes)
- Show banner when offline: "No internet connection"
- Retry failed operations when connection restores
- Show proper error states on screens instead of blank/crash

### 3.5 Post-Onboarding Interest Editing

- Add edit button on profile screen interests section
- Reuse onboarding interest selection widget
- Call `AuthService.updateProfile(interests: [...])` on save

### 3.6 Review Prompt After Completion

- When auto-complete transitions booking to `completed`, show local notification: "How was {activity}? Leave a review!"
- On bookings screen, show "Rate" button next to completed bookings that have no review
- Gate: only show for bookings with `status == completed` and no existing rating

---

## Out of Scope (Post-MVP)

Explicitly deferred:
- Group bookings / multi-guest
- Activity cloning / templates
- Business team members
- Advanced search (map, filters, date range)
- Booking modification / rescheduling
- Dispute resolution interface
- Content moderation / flagging
- Revenue reports / CSV export
- Image optimization / CDN
- Offline-first data caching
- Analytics (Mixpanel, Amplitude)

---

## Implementation Order Summary

| Priority | Item | Risk if Skipped |
|----------|------|-----------------|
| P0 | 1.1 Payment timeout + cleanup | Locked spots, orphaned bookings |
| P0 | 1.2 Payment completion detection | Users don't know if payment worked |
| P0 | 1.3 Webhook error hardening | Silent money loss for hosts |
| P0 | 1.4 Spot reservation atomicity | Overbooking |
| P0 | 1.5 Capacity reduction bug | Negative spots, crashes |
| P0 | 1.6 Duplicate payment prevention | Double charges |
| P0 | 1.7 Basic refund flow | No cancellation handling |
| P1 | 2.1 RLS policy fixes | Data manipulation by malicious users |
| P1 | 2.2 Input validation | XSS, data corruption |
| P1 | 2.3 Review verification gate | Fake reviews |
| P1 | 2.4 Paymob data validation | Payment failures |
| P1 | 2.5 Cancellation enforcement | Policy bypass |
| P2 | 3.1 Crash reporting | Blind to production issues |
| P2 | 3.2 Push notifications | Users miss booking updates |
| P2 | 3.3 Host cancellation flow | Host can't cancel events |
| P2 | 3.4 Network error handling | Blank screens on bad connection |
| P2 | 3.5 Interest editing | Minor UX gap |
| P2 | 3.6 Review prompts | Low review engagement |
