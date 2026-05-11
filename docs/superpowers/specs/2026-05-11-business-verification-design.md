# Business Verification — Design Spec

**Date:** 2026-05-11
**Status:** Draft — saved for future implementation
**Scope:** Phase 1 only (email-based approval). Admin dashboard deferred to post-launch.

---

## Problem

Any user can sign up as a business and immediately post activities. There is no human review gate to verify legitimacy before a business goes live on the platform.

## Solution

A lightweight email-based approval flow. When a business registers, they fill a short profile form and are placed in a pending state. The CTO and CEO receive an email with one-click approve/reject links. The business is notified of the decision by email and the app unlocks or shows a rejection screen accordingly.

---

## What Was Deliberately Left Out

- Document uploads (national ID, commercial registration, venue photos) — deferred to a later phase when application volume justifies it
- Admin web dashboard — deferred to post-launch
- Manual rejection reason input — admin sends reason manually via email

---

## Database Changes

Add to existing `users` table:

| Column | Type | Default | Notes |
|--------|------|---------|-------|
| `verification_status` | text | `'approved'` | Explorers auto-approved. Businesses set to `'pending'` on form submit. Values: `pending`, `approved`, `rejected` |
| `phone` | text | null | Collected in business application form |
| `city` | text | null | Collected in business application form |
| `category` | text | null | Business category (e.g. Fitness, Cooking, Art) |

No new tables required.

---

## Flutter App Changes

### New screens

**`BusinessApplicationScreen`**
- Shown immediately after business signup, before any dashboard access
- Fields: business name (pre-filled from signup), category (dropdown), phone, city
- Submit button calls `notify-business-application` Edge Function and sets `verification_status = 'pending'`
- Cannot be skipped

**`PendingReviewScreen`**
- Shown on every app open when `verification_status == 'pending'`
- Message: "Your application is under review. We'll notify you by email."
- No other app access until approved

**`RejectedScreen`**
- Shown when `verification_status == 'rejected'`
- Message: "Your application was not approved. Please check your email for details."
- "Resubmit" button resets status to `pending` and navigates back to `BusinessApplicationScreen`

### Flow

```
Business signup
      ↓
BusinessApplicationScreen (name, category, phone, city)
      ↓
Submit → status = 'pending' → notify-business-application fires
      ↓
PendingReviewScreen  ←──── shown on every app open while pending
      ↓
   approved?                        rejected?
      ↓                                  ↓
Business dashboard               RejectedScreen
                                  → resubmit option
```

### Existing users

All existing business accounts receive `verification_status = 'approved'` via migration. No disruption.

Explorers: `verification_status = 'approved'` by default. The field is never checked for explorer-role users.

---

## Edge Functions

### `notify-business-application`

**Trigger:** Called by Flutter app after business submits application form.

**What it does:**
1. Writes `verification_status = 'pending'` + form data to `users` table
2. Generates two HMAC-signed URLs:
   - `approve`: `https://[project].supabase.co/functions/v1/handle-business-decision?user_id=X&action=approve&sig=HMAC`
   - `reject`: same with `action=reject`
3. Sends email to both admin addresses (CTO + CEO) via Resend:

```
Subject: New Business Application — Cairo Yoga Studio

Business: Cairo Yoga Studio
Category: Fitness
City: Cairo
Phone: 0501234567

[✓ Approve]   [✗ Reject]

This link is one-time use and expires in 7 days.
```

**Security:** Links are signed with HMAC-SHA256 using the Supabase service role key. Unsigned or tampered requests are rejected with 401.

---

### `handle-business-decision`

**Trigger:** Admin clicks Approve or Reject link in email.

**What it does:**
1. Verifies HMAC signature — rejects with 401 if invalid
2. Checks the decision hasn't already been made (idempotent — replays do nothing)
3. Updates `verification_status` to `approved` or `rejected`
4. Sends confirmation email to the business via Resend:
   - Approved: "You're approved! Open the Hobifi app to get started."
   - Rejected: "Your application was not approved at this time. Please check your email for next steps." (CTO/CEO send reason manually)
5. Returns a simple HTML response page: "Decision recorded. Cairo Yoga Studio has been approved."

---

## Security Considerations

- HMAC links expire after 7 days
- Replayed links are idempotent (no double-processing)
- Edge Functions use service role key server-side only — never exposed to Flutter client
- `business-docs` Supabase Storage bucket is NOT needed in this phase

---

## Out of Scope (Future Phases)

- **Document uploads** — National ID, commercial registration, venue photos. Add when volume requires it.
- **Admin web dashboard** — Next.js + shadcn/ui at `admin.hobifi.com`. Planned for post-launch. Will include: business approval queue, user management, revenue metrics, operations monitoring.
- **Automated rejection reason** — Currently admin emails reason manually. Future: rejection reason input field in dashboard.
- **Resubmission limit** — No cap on resubmissions in Phase 1. Add after launch if needed.
