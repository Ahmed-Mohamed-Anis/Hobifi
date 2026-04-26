# Native Paymob Payment Integration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the WebView/iframe Paymob flow with a native SDK-backed checkout using the Paymob Intention API, so payments render as a native UI instead of an external browser.

**Architecture:** `paymob-init` edge function is rewritten to call `POST /v1/intention/` (single step, returns `client_secret`). Flutter calls a thin in-app method channel plugin (`lib/paymob/`) that bridges to the native Paymob Android SDK (JitPack) and iOS SDK (CocoaPods). The native SDK renders a full checkout sheet. Status is returned via a Dart callback — no polling needed. The existing `paymob-webhook` edge function is kept for server-side confirmation with minor field-name updates.

**Tech Stack:** Supabase Edge Functions (Deno/TypeScript), Flutter method channels, Kotlin (Android), Swift (iOS), Paymob Intention API (`accept.paymob.com/v1/intention/`), Paymob native Android + iOS SDKs

---

## ⚠️ Prerequisites Before Any Task

> The Paymob account was replaced on 2026-04-22. Before testing anything, update ALL Supabase secrets:
> - `PAYMOB_SECRET_KEY` — Settings tab → Secret Key
> - `PAYMOB_PUBLIC_KEY` — Settings tab → Public Key
> - `PAYMOB_HMAC_SECRET` — Developers → Webhooks
> - `PAYMOB_CARD_INTEGRATION_ID` — Developers → Payment Integrations (card)
> - `PAYMOB_WALLET_INTEGRATION_ID` — Developers → Payment Integrations (wallet, when available)
>
> After all tasks: configure Paymob dashboard webhook URL →
> `https://cetytjbfjtpltdcfkilg.supabase.co/functions/v1/paymob-webhook`

---

## File Map

| File | Action |
|---|---|
| `lib/supabase/functions/paymob-init/index.ts` | Full rewrite — Intention API |
| `lib/supabase/functions/paymob-webhook/index.ts` | Update — `special_reference` mapping |
| `lib/paymob/paymob_payment.dart` | New — Dart method channel API |
| `android/app/src/main/kotlin/com/hobifi/app/PaymobPaymentPlugin.kt` | New — Android native bridge |
| `android/app/src/main/kotlin/com/hobifi/app/MainActivity.kt` | Modify — register plugin |
| `android/app/build.gradle` | Modify — JitPack dep + dataBinding |
| `android/settings.gradle` | Modify — JitPack maven repo |
| `ios/Runner/PaymobPaymentPlugin.swift` | New — iOS native bridge |
| `ios/Runner/AppDelegate.swift` | Modify — register plugin |
| `ios/Podfile` | Modify — Paymob pod + min platform |
| `lib/services/payment_service.dart` | Modify — client_secret flow, remove iframe/poll |
| `lib/screens/user/payment_screen.dart` | Full rewrite — SDK callback, no polling |
| `lib/screens/user/booking_confirm_screen.dart` | Modify — pass client_secret, not iframe_url |
| `pubspec.yaml` | Modify — remove webview_flutter + url_launcher |

---

## Task 1: Discover Native SDK Dependency Names

**Files:**
- Read: `https://pub.dev/packages/paymob_sdk` (already done — references JitPack + CocoaPods)
- Read: Paymob dashboard → Developers → Mobile SDK (if accessible)

The Paymob native SDK artifact names are not on a public registry page. Use the open-source `paymob_sdk` Flutter package as the authoritative source for the correct strings.

- [ ] **Step 1: Clone `paymob_sdk` locally to read its native config**

```bash
cd /tmp && git clone https://github.com/ahmedsaleh210/paymob_sdk.git paymob_sdk_ref
```

- [ ] **Step 2: Read Android build.gradle from the cloned package**

```bash
cat /tmp/paymob_sdk_ref/android/build.gradle
```

Record the exact JitPack URL and `implementation` artifact string (e.g. `com.github.X:Y:Z`).

- [ ] **Step 3: Read iOS podspec from the cloned package**

```bash
cat /tmp/paymob_sdk_ref/ios/paymob_sdk.podspec
```

Record the exact `s.dependency` pod name and version.

- [ ] **Step 4: Read the Android Kotlin implementation to understand SDK call signature**

```bash
cat /tmp/paymob_sdk_ref/android/src/main/kotlin/com/example/paymob_sdk/PaymobSdkPlugin.kt
```

Record the exact class name, method name, and parameter types used to start payment.

- [ ] **Step 5: Read the iOS Swift implementation**

```bash
cat /tmp/paymob_sdk_ref/ios/Classes/PaymobSdkPlugin.swift
```

Record the exact class/method used to start payment on iOS.

- [ ] **Step 6: Commit reference notes**

Create `docs/paymob_sdk_reference.md` with the exact strings found above — this file is used by all subsequent native tasks. Do NOT proceed to Task 2 without it.

```bash
git add docs/paymob_sdk_reference.md
git commit -m "chore: record native Paymob SDK dependency strings for plugin implementation"
```

---

## Task 2: Rewrite `paymob-init` Edge Function

**Files:**
- Modify: `lib/supabase/functions/paymob-init/index.ts`

Replaces the 3-step legacy Accept API flow (auth token → order → payment key → iframe URL) with a single Intention API call that returns a `client_secret`.

**Intention API reference:**
- `POST https://accept.paymob.com/v1/intention/`
- Header: `Authorization: Token <PAYMOB_SECRET_KEY>`
- Body fields: `amount` (integer cents), `currency` ("EGP"), `payment_methods` (array of integration ID integers), `items` (array), `special_reference` (our booking_id — used for webhook lookup), `notification_url` (webhook URL), `expiration` (seconds, 900 = 15 min)
- Response `201`: `{ client_secret: string, intention_order_id: number, id: string, ... }`

- [ ] **Step 1: Write the new `paymob-init/index.ts`**

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
    const PAYMOB_SECRET_KEY = Deno.env.get("PAYMOB_SECRET_KEY");
    const PAYMOB_CARD_INTEGRATION_ID = Deno.env.get("PAYMOB_CARD_INTEGRATION_ID");
    const PAYMOB_WALLET_INTEGRATION_ID = Deno.env.get("PAYMOB_WALLET_INTEGRATION_ID");
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    if (!PAYMOB_SECRET_KEY || !PAYMOB_CARD_INTEGRATION_ID) {
      throw new Error("Missing Paymob configuration — set PAYMOB_SECRET_KEY and PAYMOB_CARD_INTEGRATION_ID");
    }

    // ── Authenticate caller via JWT ────────────────────────────────────────
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(jwt);
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const body = await req.json();
    const { booking_id, activity_id, activity_title, user_email, user_name, user_phone } = body;

    if (!booking_id || !activity_id) {
      return new Response(
        JSON.stringify({ error: "booking_id and activity_id are required" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // ── Look up price from DB — never trust client ─────────────────────────
    const { data: activity, error: activityError } = await supabase
      .from("activities")
      .select("price, title")
      .eq("id", activity_id)
      .single();

    if (activityError || !activity) {
      return new Response(
        JSON.stringify({ error: "Activity not found" }),
        { status: 404, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const amountCents = Math.round(activity.price * 100);
    const billingEmail = user_email || user.email;
    const activityName = activity_title || activity.title;

    if (!billingEmail) {
      return new Response(
        JSON.stringify({ error: "User email is required for payment" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // ── Build integration IDs list ─────────────────────────────────────────
    const paymentMethods: number[] = [parseInt(PAYMOB_CARD_INTEGRATION_ID)];
    if (PAYMOB_WALLET_INTEGRATION_ID) {
      paymentMethods.push(parseInt(PAYMOB_WALLET_INTEGRATION_ID));
    }

    // ── Call Intention API ─────────────────────────────────────────────────
    const webhookUrl = `${SUPABASE_URL}/functions/v1/paymob-webhook`;
    const intentionResponse = await fetch("https://accept.paymob.com/v1/intention/", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Token ${PAYMOB_SECRET_KEY}`,
      },
      body: JSON.stringify({
        amount: amountCents,
        currency: "EGP",
        expiration: 900, // 15 minutes
        payment_methods: paymentMethods,
        items: [{ name: activityName, amount: amountCents, quantity: 1 }],
        special_reference: booking_id,
        notification_url: webhookUrl,
        billing_data: {
          email: billingEmail,
          first_name: (user_name || "User").split(" ")[0] || "User",
          last_name: (user_name || "User").split(" ").slice(1).join(" ") || "User",
          phone_number: user_phone || "+201000000000",
        },
      }),
    });

    if (!intentionResponse.ok) {
      const errBody = await intentionResponse.text();
      throw new Error(`Intention API error ${intentionResponse.status}: ${errBody}`);
    }

    const intention = await intentionResponse.json();
    const clientSecret: string = intention.client_secret;

    if (!clientSecret) {
      throw new Error(`No client_secret in Intention API response: ${JSON.stringify(intention)}`);
    }

    // ── Upsert payment record ──────────────────────────────────────────────
    const platformFee = Math.round(activity.price * 10) / 100;
    const businessEarnings = Math.round((activity.price - platformFee) * 100) / 100;

    const { data: existing } = await supabase
      .from("payments")
      .select("id")
      .eq("booking_id", booking_id)
      .in("status", ["pending", "processing"])
      .maybeSingle();

    if (existing) {
      await supabase
        .from("payments")
        .update({ transaction_id: intention.id })
        .eq("id", existing.id);
    } else {
      const { error: insertErr } = await supabase.from("payments").insert({
        booking_id,
        user_id: user.id,
        activity_id,
        amount: activity.price,
        platform_fee: platformFee,
        business_earnings: businessEarnings,
        transaction_id: intention.id,
        status: "pending",
        payment_method: "card",
      });
      if (insertErr && insertErr.code !== "23505") {
        console.error("Failed to insert payment record:", insertErr);
      }
    }

    return new Response(
      JSON.stringify({ client_secret: clientSecret, booking_id }),
      { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("paymob-init error:", error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : "Unknown error" }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }
});
```

- [ ] **Step 2: Update `paymob-webhook` to use `special_reference` for booking lookup**

In `lib/supabase/functions/paymob-webhook/index.ts`, find the line that extracts `orderId`:

```typescript
// OLD (line ~119):
const orderId = obj.order?.merchant_order_id || obj.order?.id?.toString();
```

Replace with:

```typescript
// NEW — Intention API uses special_reference; fall back to merchant_order_id for legacy
const orderId = obj.order?.merchant_order_id
  || obj.special_reference
  || obj.order?.id?.toString();
```

- [ ] **Step 3: Deploy both edge functions**

```bash
cd /Users/anis/Developer/Hobifi
supabase functions deploy paymob-init --no-verify-jwt
supabase functions deploy paymob-webhook --no-verify-jwt
```

Expected output: `Deployed Function paymob-init` and `Deployed Function paymob-webhook` with no errors.

- [ ] **Step 4: Update Supabase secrets for new account**

```bash
supabase secrets set PAYMOB_SECRET_KEY="<from dashboard Settings → Secret Key>"
supabase secrets set PAYMOB_CARD_INTEGRATION_ID="<from Developers → Payment Integrations>"
supabase secrets set PAYMOB_HMAC_SECRET="<from Developers → Webhooks>"
# If wallet integration available:
# supabase secrets set PAYMOB_WALLET_INTEGRATION_ID="<from dashboard>"
```

- [ ] **Step 5: Smoke-test the edge function with curl**

```bash
# Get a valid JWT first (from Supabase Auth)
curl -X POST https://cetytjbfjtpltdcfkilg.supabase.co/functions/v1/paymob-init \
  -H "Authorization: Bearer <USER_JWT>" \
  -H "Content-Type: application/json" \
  -d '{"booking_id":"test-123","activity_id":"<real-activity-id>","activity_title":"Test","user_email":"test@test.com","user_name":"Test User","user_phone":"+201000000000"}'
```

Expected: `{"client_secret":"...", "booking_id":"test-123"}` with HTTP 200.

- [ ] **Step 6: Commit**

```bash
git add lib/supabase/functions/paymob-init/index.ts lib/supabase/functions/paymob-webhook/index.ts
git commit -m "feat(payment): rewrite paymob-init to use Intention API, update webhook special_reference"
```

---

## Task 3: Android Native Bridge

**Files:**
- Modify: `android/settings.gradle` — add JitPack maven repo
- Modify: `android/app/build.gradle` — add Paymob SDK dependency + enable dataBinding
- Create: `android/app/src/main/kotlin/com/hobifi/app/PaymobPaymentPlugin.kt`
- Modify: `android/app/src/main/kotlin/com/hobifi/app/MainActivity.kt`

> ⚠️ Use the exact JitPack URL and artifact string from `docs/paymob_sdk_reference.md` (Task 1). The placeholders below (`PAYMOB_JITPACK_URL`, `PAYMOB_ANDROID_ARTIFACT`) must be replaced with real values.

- [ ] **Step 1: Add JitPack maven repo to `android/settings.gradle`**

Find the `pluginManagement { repositories { ... } }` block and add JitPack to the `dependencyResolutionManagement` section. If there is no `dependencyResolutionManagement` block, add one after `pluginManagement`:

```gradle
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven { url 'https://jitpack.io' }  // Paymob Android SDK
    }
}
```

- [ ] **Step 2: Add Paymob SDK dependency + enable dataBinding in `android/app/build.gradle`**

In the `android { ... }` block, add:

```gradle
android {
    // ... existing config ...
    buildFeatures {
        dataBinding = true
    }
    defaultConfig {
        // ... existing config ...
        minSdk = 23  // Paymob SDK minimum
    }
}
```

In the `dependencies { ... }` block, add (replace `PAYMOB_ANDROID_ARTIFACT` with value from Task 1):

```gradle
dependencies {
    // ... existing deps ...
    implementation 'PAYMOB_ANDROID_ARTIFACT'  // from docs/paymob_sdk_reference.md
}
```

- [ ] **Step 3: Create `PaymobPaymentPlugin.kt`**

> ⚠️ Replace `PaymobSdk`, `PaymobParams`, `startPayment`, and `PaymobCheckoutStatus` with the exact class/method names from `docs/paymob_sdk_reference.md` (Task 1, Step 4).

```kotlin
package com.hobifi.app

import android.app.Activity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

// Replace these imports with the actual Paymob SDK imports from docs/paymob_sdk_reference.md
// import com.paymob.sdk.PaymobSdk
// import com.paymob.sdk.PaymobParams

class PaymobPaymentPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null

    companion object {
        const val CHANNEL = "com.hobifi.app/paymob_payment"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "startPayment" -> {
                val publicKey = call.argument<String>("publicKey") ?: run {
                    result.error("MISSING_ARG", "publicKey is required", null)
                    return
                }
                val clientSecret = call.argument<String>("clientSecret") ?: run {
                    result.error("MISSING_ARG", "clientSecret is required", null)
                    return
                }
                val currentActivity = activity ?: run {
                    result.error("NO_ACTIVITY", "No activity attached", null)
                    return
                }

                // ── Replace this block with actual Paymob SDK call ────────────
                // Use exact class/method names from docs/paymob_sdk_reference.md
                //
                // Example (verify against reference):
                // PaymobSdk().startPayment(
                //     activity = currentActivity,
                //     params = PaymobParams(
                //         publicKey = publicKey,
                //         clientSecret = clientSecret,
                //     ),
                //     onCheckoutStatus = { status ->
                //         when (status) {
                //             PaymobCheckoutStatus.successful -> result.success("successful")
                //             PaymobCheckoutStatus.rejected   -> result.success("rejected")
                //             PaymobCheckoutStatus.pending    -> result.success("pending")
                //             else                            -> result.success("unknown")
                //         }
                //     }
                // )
                // ─────────────────────────────────────────────────────────────
                result.notImplemented() // Remove this line once real SDK call is in place
            }
            else -> result.notImplemented()
        }
    }
}
```

- [ ] **Step 4: Register the plugin in `MainActivity.kt`**

```kotlin
package com.hobifi.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(PaymobPaymentPlugin())
    }
}
```

- [ ] **Step 5: Verify Android builds**

```bash
cd /Users/anis/Developer/Hobifi
flutter build apk --debug 2>&1 | tail -20
```

Expected: Build succeeds. If `minSdk` conflict appears, set it to `23` in `defaultConfig`. If dataBinding error, verify Task 3 Step 2 was applied. If the Paymob artifact isn't found, double-check the JitPack URL and artifact string from Task 1.

- [ ] **Step 6: Commit**

```bash
git add android/settings.gradle android/app/build.gradle \
  android/app/src/main/kotlin/com/hobifi/app/PaymobPaymentPlugin.kt \
  android/app/src/main/kotlin/com/hobifi/app/MainActivity.kt
git commit -m "feat(android): add Paymob native payment method channel plugin"
```

---

## Task 4: iOS Native Bridge

**Files:**
- Modify: `ios/Podfile` — add Paymob pod + min iOS platform
- Create: `ios/Runner/PaymobPaymentPlugin.swift`
- Modify: `ios/Runner/AppDelegate.swift`

> ⚠️ Use the exact pod name and version from `docs/paymob_sdk_reference.md` (Task 1, Step 3).

- [ ] **Step 1: Update `ios/Podfile`**

Uncomment (or set) the platform line and add the Paymob pod. Replace `PAYMOB_POD_NAME` and `PAYMOB_POD_VERSION` with values from Task 1:

```ruby
platform :ios, '13.0'  # Paymob SDK requires iOS 13+

# ... existing content unchanged ...

target 'Runner' do
  use_frameworks!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))

  # Paymob native SDK — exact name/version from docs/paymob_sdk_reference.md
  pod 'PAYMOB_POD_NAME', 'PAYMOB_POD_VERSION'

  target 'RunnerTests' do
    inherit! :search_paths
  end
end
```

- [ ] **Step 2: Run pod install**

```bash
cd /Users/anis/Developer/Hobifi/ios && pod install
```

Expected: All pods install without errors. If the pod is not found on CocoaPods trunk, check Task 1 Step 3 output — the pod may need a custom source URL.

- [ ] **Step 3: Create `ios/Runner/PaymobPaymentPlugin.swift`**

> ⚠️ Replace `PaymobSdk`, `PaymobParams`, `startPayment`, and status enum cases with the exact names from `docs/paymob_sdk_reference.md` (Task 1, Step 5).

```swift
import Flutter
import UIKit

// Replace with actual Paymob SDK import from docs/paymob_sdk_reference.md
// import PaymobSdk

class PaymobPaymentPlugin: NSObject, FlutterPlugin {

    static let channelName = "com.hobifi.app/paymob_payment"

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        let instance = PaymobPaymentPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "startPayment" else {
            result(FlutterMethodNotImplemented)
            return
        }

        guard let args = call.arguments as? [String: Any],
              let publicKey = args["publicKey"] as? String,
              let clientSecret = args["clientSecret"] as? String else {
            result(FlutterError(code: "MISSING_ARG", message: "publicKey and clientSecret are required", details: nil))
            return
        }

        guard let viewController = UIApplication.shared.keyWindow?.rootViewController else {
            result(FlutterError(code: "NO_VC", message: "No root view controller", details: nil))
            return
        }

        // ── Replace this block with actual Paymob SDK call ────────────────
        // Use exact class/method names from docs/paymob_sdk_reference.md
        //
        // Example (verify against reference):
        // let params = PaymobParams(
        //     publicKey: publicKey,
        //     clientSecret: clientSecret
        // )
        // PaymobSdk.startPayment(
        //     viewController: viewController,
        //     params: params
        // ) { status in
        //     switch status {
        //     case .successful: result("successful")
        //     case .rejected:   result("rejected")
        //     case .pending:    result("pending")
        //     default:          result("unknown")
        //     }
        // }
        // ─────────────────────────────────────────────────────────────────
        result(FlutterMethodNotImplemented) // Remove once real SDK call is in place
    }
}
```

- [ ] **Step 4: Register plugin in `AppDelegate.swift`**

```swift
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        let controller = window?.rootViewController as! FlutterViewController
        let channel = FlutterMethodChannel(
            name: PaymobPaymentPlugin.channelName,
            binaryMessenger: controller.binaryMessenger
        )
        channel.setMethodCallHandler { [weak self] call, result in
            PaymobPaymentPlugin().handle(call, result: result)
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
```

- [ ] **Step 5: Verify iOS builds**

```bash
cd /Users/anis/Developer/Hobifi
flutter build ios --debug --no-codesign 2>&1 | tail -30
```

Expected: Build succeeds. If Swift compiler error on the Paymob import, the pod name from Task 1 is wrong — recheck. If `keyWindow` deprecation warning on iOS 16+, it's non-fatal.

- [ ] **Step 6: Commit**

```bash
git add ios/Podfile ios/Podfile.lock ios/Runner/PaymobPaymentPlugin.swift ios/Runner/AppDelegate.swift
git commit -m "feat(ios): add Paymob native payment method channel plugin"
```

---

## Task 5: Dart Method Channel API

**Files:**
- Create: `lib/paymob/paymob_payment.dart`

Single file. Defines the enum and the static `startPayment` call. No state, no streams.

- [ ] **Step 1: Create `lib/paymob/paymob_payment.dart`**

```dart
import 'package:flutter/services.dart';

enum PaymobCheckoutStatus { successful, rejected, pending, unknown }

class PaymobPayment {
  static const _channel = MethodChannel('com.hobifi.app/paymob_payment');

  static Future<PaymobCheckoutStatus> startPayment({
    required String publicKey,
    required String clientSecret,
  }) async {
    final String? status = await _channel.invokeMethod('startPayment', {
      'publicKey': publicKey,
      'clientSecret': clientSecret,
    });
    return switch (status) {
      'successful' => PaymobCheckoutStatus.successful,
      'rejected'   => PaymobCheckoutStatus.rejected,
      'pending'    => PaymobCheckoutStatus.pending,
      _            => PaymobCheckoutStatus.unknown,
    };
  }
}
```

- [ ] **Step 2: Verify the file is importable**

```bash
cd /Users/anis/Developer/Hobifi && flutter analyze lib/paymob/paymob_payment.dart
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/paymob/paymob_payment.dart
git commit -m "feat(payment): add Dart method channel for native Paymob SDK"
```

---

## Task 6: Update `payment_service.dart`

**Files:**
- Modify: `lib/services/payment_service.dart`

Replace the `initializePayment` method's return contract: it now returns `client_secret` instead of `iframe_url`. Remove `_currentPaymentUrl` and `_currentPaymentToken` — they are no longer needed.

The `loadUserPayments`, `getBusinessEarnings`, `createPayment`, `updatePaymentStatus`, `getPaymentByBookingId`, and `clearPaymentSession` methods are unchanged except `clearPaymentSession` which is removed (nothing to clear).

- [ ] **Step 1: Rewrite `payment_service.dart`**

```dart
import 'package:flutter/foundation.dart';
import 'package:hobby_haven/models/payment_model.dart';
import 'package:hobby_haven/supabase/supabase_config.dart';

class PaymentService extends ChangeNotifier {
  List<PaymentModel> _payments = [];
  bool _isLoading = false;

  List<PaymentModel> get payments => _payments;
  bool get isLoading => _isLoading;

  /// Calls paymob-init edge function; returns client_secret for the native SDK.
  Future<String> initializePayment({
    required String bookingId,
    required String activityId,
    required String activityTitle,
    required String userEmail,
    required String userName,
    required String userPhone,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      String accessToken;
      try {
        final refreshed = await SupabaseConfig.auth.refreshSession();
        accessToken = refreshed.session?.accessToken
            ?? SupabaseConfig.auth.currentSession?.accessToken
            ?? '';
      } catch (_) {
        accessToken = SupabaseConfig.auth.currentSession?.accessToken ?? '';
      }

      if (accessToken.isEmpty) throw Exception('Not authenticated');

      final response = await SupabaseConfig.client.functions.invoke(
        'paymob-init',
        headers: {'Authorization': 'Bearer $accessToken'},
        body: {
          'booking_id': bookingId,
          'activity_id': activityId,
          'activity_title': activityTitle,
          'user_email': userEmail,
          'user_name': userName,
          'user_phone': userPhone,
        },
      );

      if (response.status != 200) {
        final body = response.data is Map
            ? (response.data as Map)['error'] ?? response.data.toString()
            : response.data.toString();
        throw Exception('Payment init failed: $body');
      }

      final data = response.data as Map<String, dynamic>;
      final clientSecret = data['client_secret'] as String?;
      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception('No client_secret returned from payment init');
      }
      return clientSecret;

    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUserPayments(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await SupabaseConfig.client
          .from('payments')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      _payments = (data as List).map((j) => PaymentModel.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Failed to load payments: $e');
      _payments = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<double> getBusinessEarnings(String businessId) async {
    try {
      final activities = await SupabaseConfig.client
          .from('activities')
          .select('id')
          .eq('business_id', businessId);
      final ids = (activities as List).map((a) => a['id'] as String).toList();
      if (ids.isEmpty) return 0.0;
      final rows = await SupabaseConfig.client
          .from('payments')
          .select('business_earnings')
          .inFilter('activity_id', ids)
          .eq('status', 'completed');
      return (rows as List).fold(
        0.0,
        (sum, r) => sum + ((r['business_earnings'] as num?)?.toDouble() ?? 0.0),
      );
    } catch (e) {
      debugPrint('Failed to get business earnings: $e');
      return 0.0;
    }
  }

  Future<void> updatePaymentStatus(
    String paymentId,
    PaymentStatus status, {
    String? transactionId,
  }) async {
    final updates = <String, dynamic>{'status': status.name};
    if (transactionId != null) updates['transaction_id'] = transactionId;
    await SupabaseConfig.client
        .from('payments')
        .update(updates)
        .eq('id', paymentId);
    notifyListeners();
  }

  PaymentModel? getPaymentByBookingId(String bookingId) {
    try {
      return _payments.firstWhere((p) => p.bookingId == bookingId);
    } catch (_) {
      return null;
    }
  }
}
```

- [ ] **Step 2: Verify no analysis errors**

```bash
flutter analyze lib/services/payment_service.dart
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/services/payment_service.dart
git commit -m "feat(payment): update PaymentService to return client_secret, remove iframe/poll logic"
```

---

## Task 7: Rewrite `payment_screen.dart`

**Files:**
- Modify: `lib/screens/user/payment_screen.dart`

Full rewrite. Remove `WidgetsBindingObserver`, `Timer`, `url_launcher`, all polling. The screen receives `clientSecret` (not `paymentUrl`). Tapping "Pay" calls the native SDK via `PaymobPayment.startPayment()`. The SDK callback drives navigation immediately — no polling.

- [ ] **Step 1: Rewrite `payment_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:hobby_haven/paymob/paymob_payment.dart';
import 'package:hobby_haven/services/auth_service.dart';
import 'package:hobby_haven/services/booking_service.dart';
import 'package:hobby_haven/theme.dart';
import 'package:hobby_haven/widgets/app_back_button.dart';

// PAYMOB_PUBLIC_KEY: non-sensitive, safe to embed.
// Copy from Paymob dashboard → Settings → Public Key.
const _paymobPublicKey = 'YOUR_PAYMOB_PUBLIC_KEY';

class PaymentScreen extends StatefulWidget {
  final String bookingId;
  final String activityId;
  final String clientSecret;
  final String activityTitle;
  final double amount;

  const PaymentScreen({
    super.key,
    required this.bookingId,
    required this.activityId,
    required this.clientSecret,
    required this.activityTitle,
    required this.amount,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isPaying = false;
  String? _errorMessage;

  Future<void> _pay() async {
    if (_isPaying) return;
    setState(() { _isPaying = true; _errorMessage = null; });

    try {
      final status = await PaymobPayment.startPayment(
        publicKey: _paymobPublicKey,
        clientSecret: widget.clientSecret,
      );

      if (!mounted) return;

      switch (status) {
        case PaymobCheckoutStatus.successful:
          // Refresh bookings in background, then navigate to ticket
          final userId = context.read<AuthService>().currentUser?.id ?? '';
          context.read<BookingService>().loadUserBookings(userId, force: true);
          context.go('/ticket/${widget.bookingId}');

        case PaymobCheckoutStatus.pending:
          // Payment is pending (e.g. wallet OTP confirmation)
          context.go('/ticket/${widget.bookingId}');

        case PaymobCheckoutStatus.rejected:
          setState(() => _errorMessage = 'Payment was declined. Please try a different card or contact your bank.');

        case PaymobCheckoutStatus.unknown:
          setState(() => _errorMessage = 'Payment status unknown. Check your bookings — if debited, contact support.');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Payment failed: $e');
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: AppBackButton(onPressed: () => context.pop()),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment',
                style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold)),
            if (widget.activityTitle.isNotEmpty)
              Text(widget.activityTitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.6)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
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
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  _OrderSummaryCard(
                    activityTitle: widget.activityTitle,
                    bookingId: widget.bookingId,
                    amount: widget.amount,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Payment info row
                  Container(
                    padding: AppSpacing.paddingLg,
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          offset: const Offset(0, 2),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.credit_card_rounded,
                              color: cs.primary, size: 22),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Secure Native Checkout',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text('Card, Wallet, Apple Pay, Google Pay',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: cs.onSurface.withValues(alpha: 0.6))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_rounded, size: 16,
                          color: cs.onSurface.withValues(alpha: 0.4)),
                      const SizedBox(width: 6),
                      Text('Secured by Paymob',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.4))),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Pay button
          Container(
            padding: AppSpacing.paddingLg,
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isPaying ? null : _pay,
                  icon: _isPaying
                      ? SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: cs.onPrimary, strokeWidth: 2))
                      : const Icon(Icons.payment_rounded),
                  label: Text(_isPaying
                      ? 'Opening checkout…'
                      : 'Pay EGP ${widget.amount.toStringAsFixed(2)}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ),
        ],
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
    final cs = theme.colorScheme;
    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color: cs.surface,
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
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.confirmation_number_rounded,
                    color: cs.primary, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(activityTitle,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                        'Booking #${bookingId.substring(0, 8).toUpperCase()}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.5))),
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
                      color: cs.onSurface.withValues(alpha: 0.6))),
              Text('EGP ${amount.toStringAsFixed(2)}',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/screens/user/payment_screen.dart
```

Expected: No errors. If `AppBackButton` import fails, check `lib/widgets/app_back_button.dart` exists.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/user/payment_screen.dart
git commit -m "feat(payment): rewrite PaymentScreen to use native SDK callback, remove polling"
```

---

## Task 8: Update `booking_confirm_screen.dart`

**Files:**
- Modify: `lib/screens/user/booking_confirm_screen.dart`

The confirm screen now gets a `client_secret` string back from `initializePayment()` and pushes it to `PaymentScreen` as `clientSecret` instead of `paymentUrl`.

- [ ] **Step 1: Update `_confirmAndPay` in `booking_confirm_screen.dart`**

Find and replace the `initializePayment` call + `context.push` block (lines 73–94):

```dart
// OLD:
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
```

Replace with:

```dart
// NEW:
final clientSecret = await paymentService.initializePayment(
  bookingId: bookingId,
  activityId: activity.id,
  activityTitle: activity.title,
  userEmail: user.email,
  userName: user.name,
  userPhone: user.phone ?? '',
);

if (mounted) {
  context.push(
    '${AppRoutes.payment}/$bookingId',
    extra: {
      'clientSecret': clientSecret,
      'activityId': activity.id,
      'activityTitle': activity.title,
      'amount': activity.price,
    },
  );
}
```

- [ ] **Step 2: Update `PaymentScreen` route in `nav.dart` to use `clientSecret`**

Find the route for `AppRoutes.payment` in `lib/nav.dart`. Update the `extra` destructuring from `paymentUrl` to `clientSecret`:

```dart
// OLD:
GoRoute(
  path: '${AppRoutes.payment}/:bookingId',
  builder: (context, state) {
    final extra = state.extra as Map<String, dynamic>;
    return PaymentScreen(
      bookingId: state.pathParameters['bookingId']!,
      activityId: extra['activityId'] as String,
      paymentUrl: extra['paymentUrl'] as String,
      activityTitle: extra['activityTitle'] as String,
      amount: (extra['amount'] as num).toDouble(),
    );
  },
),
```

```dart
// NEW:
GoRoute(
  path: '${AppRoutes.payment}/:bookingId',
  builder: (context, state) {
    final extra = state.extra as Map<String, dynamic>;
    return PaymentScreen(
      bookingId: state.pathParameters['bookingId']!,
      activityId: extra['activityId'] as String,
      clientSecret: extra['clientSecret'] as String,
      activityTitle: extra['activityTitle'] as String,
      amount: (extra['amount'] as num).toDouble(),
    );
  },
),
```

- [ ] **Step 3: Verify full app analysis**

```bash
flutter analyze lib/
```

Expected: No errors. Common issues to fix:
- `userId` parameter removed from `initializePayment` — if any other call site passes it, remove that argument.
- `clearPaymentSession()` removed — if called anywhere, delete those call sites.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/user/booking_confirm_screen.dart lib/nav.dart
git commit -m "feat(payment): wire BookingConfirmScreen to pass client_secret to PaymentScreen"
```

---

## Task 9: Clean Up `pubspec.yaml`

**Files:**
- Modify: `pubspec.yaml`

`webview_flutter` and `url_launcher` are no longer used by the payment flow. Verify they aren't used elsewhere before removing.

- [ ] **Step 1: Check for other usages**

```bash
grep -r "webview_flutter\|url_launcher\|launchUrl\|WebViewController" /Users/anis/Developer/Hobifi/lib/ --include="*.dart"
```

If results appear outside of the now-deleted payment screen usage, keep the packages. If only in deleted/updated files, remove them.

- [ ] **Step 2: Remove unused packages from `pubspec.yaml`**

If Step 1 showed no other usages, remove from the `dependencies` block:

```yaml
# Remove these lines:
  webview_flutter: ^4.0.0
  url_launcher: ^6.0.0
```

- [ ] **Step 3: Get packages and verify build**

```bash
cd /Users/anis/Developer/Hobifi && flutter pub get && flutter analyze lib/
```

Expected: No errors. If `url_launcher` is still referenced somewhere, add it back.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: remove webview_flutter and url_launcher (replaced by native Paymob SDK)"
```

---

## Task 10: End-to-End Verification

- [ ] **Step 1: Set Paymob webhook URL in dashboard**

Log in to [accept.paymob.com](https://accept.paymob.com) → Developers → Transaction processed callback:

```
https://cetytjbfjtpltdcfkilg.supabase.co/functions/v1/paymob-webhook
```

- [ ] **Step 2: Run on Android device/emulator**

```bash
flutter run -d <android-device-id>
```

Flow to test:
1. Log in as user → browse activities → tap an activity → "Book Now"
2. Confirm booking screen appears with correct price
3. Tap "Proceed to Payment" — native Paymob checkout sheet should appear
4. Use Paymob test card: `4987654321098769`, expiry `12/25`, CVV `123`
5. After payment: app should navigate to ticket screen
6. Check Supabase `bookings` table — status should be `confirmed`
7. Check Supabase `payments` table — status should be `completed`

- [ ] **Step 3: Run on iOS device/simulator**

```bash
flutter run -d <ios-device-id>
```

Same flow as Step 2.

- [ ] **Step 4: Test failed payment path**

Use declined test card (check Paymob sandbox docs for declined card number). App should show error message on `PaymentScreen`, not crash. Booking status should remain `pending` or flip to `cancelled` via webhook.

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "feat(payment): complete native Paymob SDK integration via Intention API"
```

---

## What Was Removed

| Removed | Replaced By |
|---|---|
| 3-step Auth→Order→PaymentKey backend | Single Intention API call |
| `iframe_url` / `paymentUrl` | `client_secret` |
| `launchUrl` + external browser | Native SDK checkout sheet |
| `WidgetsBindingObserver` lifecycle polling | SDK status callback |
| `Timer.periodic` booking status polling | Immediate SDK callback |
| `webview_flutter` dependency | Native SDK |
| `url_launcher` dependency | Native SDK |
| `PAYMOB_API_KEY`, `PAYMOB_IFRAME_ID` secrets | `PAYMOB_SECRET_KEY` |
