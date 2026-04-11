# Phase 2: Security Hardening — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close security gaps in RLS policies, add server-side input validation, and enforce booking verification before reviews.

**Architecture:** Three SQL migrations (ratings RLS, input constraints, rating value constraint) plus client-side validation hardening in Dart. All changes are additive — no existing functionality changes.

**Tech Stack:** PostgreSQL (Supabase), Dart/Flutter

**Already completed in Phase 1:** Users INSERT RLS fix (Task 8), Paymob user data validation (Task 9), server-side cancellation enforcement (Task 7). Activities INSERT/UPDATE RLS already correct in `supabase_policies.sql`.

---

### Task 1: Ratings table RLS policies with booking verification gate

**Files:**
- Create: `lib/supabase/migrations/20260330_ratings_rls_and_booking_gate.sql`

This is the highest-priority security task. The `ratings` table currently has **no RLS policies at all**, meaning any authenticated user can insert/update/delete any rating, and there's no check that they actually attended the activity.

- [ ] **Step 1: Write the migration SQL**

```sql
-- Enable RLS on ratings table
ALTER TABLE ratings ENABLE ROW LEVEL SECURITY;

-- Anyone authenticated can read ratings
CREATE POLICY "Authenticated users can view all ratings"
  ON ratings FOR SELECT
  TO authenticated
  USING (true);

-- Users can only rate activities they have a completed booking for
CREATE POLICY "Users can rate activities they completed"
  ON ratings FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM bookings
      WHERE bookings.user_id = auth.uid()
        AND bookings.activity_id = ratings.activity_id
        AND bookings.status = 'completed'
    )
  );

-- Users can update only their own ratings
CREATE POLICY "Users can update their own ratings"
  ON ratings FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Users can delete only their own ratings
CREATE POLICY "Users can delete their own ratings"
  ON ratings FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- Enforce rating value 1-5
ALTER TABLE ratings
  ADD CONSTRAINT chk_rating_range CHECK (rating BETWEEN 1 AND 5);

-- Enforce comment max length
ALTER TABLE ratings
  ADD CONSTRAINT chk_comment_length CHECK (comment IS NULL OR length(comment) <= 500);
```

- [ ] **Step 2: Commit**

```bash
git add lib/supabase/migrations/20260330_ratings_rls_and_booking_gate.sql
git commit -m "feat: add RLS policies to ratings table with booking verification gate"
```

---

### Task 2: Input validation CHECK constraints on activities and users

**Files:**
- Create: `lib/supabase/migrations/20260330_input_validation_constraints.sql`

Add database-level length constraints to prevent oversized or malicious input from being stored, regardless of what the client sends.

- [ ] **Step 1: Write the migration SQL**

```sql
-- Activity title: 3-100 characters
ALTER TABLE activities
  ADD CONSTRAINT chk_activity_title_length
  CHECK (length(title) BETWEEN 3 AND 100);

-- Activity description: max 2000 characters
ALTER TABLE activities
  ADD CONSTRAINT chk_activity_description_length
  CHECK (description IS NULL OR length(description) <= 2000);

-- User bio: max 200 characters
ALTER TABLE users
  ADD CONSTRAINT chk_user_bio_length
  CHECK (bio IS NULL OR length(bio) <= 200);

-- User name: 1-100 characters
ALTER TABLE users
  ADD CONSTRAINT chk_user_name_length
  CHECK (length(name) BETWEEN 1 AND 100);
```

- [ ] **Step 2: Commit**

```bash
git add lib/supabase/migrations/20260330_input_validation_constraints.sql
git commit -m "feat: add CHECK constraints for input length on activities and users"
```

---

### Task 3: Client-side HTML stripping and length enforcement

**Files:**
- Create: `lib/utils/input_sanitizer.dart`
- Modify: `lib/screens/business/create_activity_screen.dart` (lines 138-157, 363-389)
- Modify: `lib/services/rating_service.dart` (lines 77-107)
- Modify: `lib/screens/business/business_profile_screen.dart` (lines 44-55, 215)

Add a lightweight HTML-stripping utility and enforce max lengths on text inputs both in the UI (maxLength on TextFields) and in the service layer before DB calls.

- [ ] **Step 1: Create the input sanitizer utility**

```dart
/// Strips HTML tags and trims whitespace from user input.
/// Used at service boundaries before sending data to the database.
class InputSanitizer {
  static final _htmlTagRegex = RegExp(r'<[^>]*>');

  /// Remove HTML tags and trim whitespace.
  static String stripHtml(String input) {
    return input.replaceAll(_htmlTagRegex, '').trim();
  }

  /// Strip HTML and enforce max length.
  static String sanitize(String input, {int? maxLength}) {
    var cleaned = stripHtml(input);
    if (maxLength != null && cleaned.length > maxLength) {
      cleaned = cleaned.substring(0, maxLength);
    }
    return cleaned;
  }
}
```

- [ ] **Step 2: Add maxLength to activity creation TextFields**

In `create_activity_screen.dart`, add `maxLength` properties:
- Title TextField: `maxLength: 100`
- Description TextField: `maxLength: 2000`

- [ ] **Step 3: Apply sanitization in rating service**

In `rating_service.dart` `addOrUpdateRating()`, sanitize the comment before sending:
```dart
final sanitizedComment = (comment != null && comment.isNotEmpty)
    ? InputSanitizer.sanitize(comment, maxLength: 500)
    : comment;
```

- [ ] **Step 4: Apply sanitization in activity creation**

In `create_activity_screen.dart` `_handleCreate()`, sanitize title and description:
```dart
title: InputSanitizer.sanitize(_titleController.text, maxLength: 100),
description: InputSanitizer.sanitize(_descriptionController.text, maxLength: 2000),
```

- [ ] **Step 5: Add maxLength to bio TextField and sanitize on save**

In `business_profile_screen.dart`:
- Add `maxLength: 200` to bio TextField
- Sanitize in `_saveBio()`: `InputSanitizer.sanitize(_bioController.text, maxLength: 200)`

- [ ] **Step 6: Commit**

```bash
git add lib/utils/input_sanitizer.dart lib/screens/business/create_activity_screen.dart lib/services/rating_service.dart lib/screens/business/business_profile_screen.dart
git commit -m "feat: add client-side HTML stripping and input length enforcement"
```

---

### Dependency Graph

```
Task 1 (ratings RLS)     — independent
Task 2 (CHECK constraints) — independent
Task 3 (client-side)      — independent
```

All three tasks are independent and can be executed in any order.
