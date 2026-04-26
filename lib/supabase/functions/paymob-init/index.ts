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
    const PAYMOB_API_KEY = Deno.env.get("PAYMOB_SECRET_KEY");
    const PAYMOB_IFRAME_ID = Deno.env.get("PAYMOB_IFRAME_ID");
    const PAYMOB_INTEGRATION_ID = Deno.env.get("PAYMOB_CARD_INTEGRATION_ID");
    // Wallet integration ID — add this secret when received from Paymob dashboard
    const PAYMOB_WALLET_INTEGRATION_ID = Deno.env.get("PAYMOB_WALLET_INTEGRATION_ID");

    if (!PAYMOB_API_KEY || !PAYMOB_INTEGRATION_ID) {
      throw new Error("Missing Paymob configuration");
    }

    // ── Step 0: Authenticate the caller via JWT ─────────────────────────────
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace("Bearer ", "");
    const { data: { user: callerUser }, error: authError } = await supabase.auth.getUser(jwt);
    if (authError || !callerUser) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: invalid or missing token" }),
        { status: 401, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }
    const authenticatedUserId = callerUser.id;

    const body = await req.json();
    const {
      booking_id,
      activity_id,
      activity_title,
      user_email,
      user_name,
      user_phone,
      payment_method = "card", // "card" | "wallet" | "saved_card"
      wallet_phone,
      card_token, // saved card token for returning users
    } = body;

    // ── Look up the real price from the database — never trust the client ──
    const { data: activityRow, error: activityError } = await supabase
      .from("activities")
      .select("price")
      .eq("id", activity_id)
      .single();

    if (activityError || !activityRow) {
      return new Response(
        JSON.stringify({ error: "Activity not found" }),
        { status: 404, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }
    const amount = activityRow.price as number;
    // Use the authenticated user's ID, not the client-supplied one
    const user_id = authenticatedUserId;

    // Validate saved card request
    if (payment_method === "saved_card" && !card_token) {
      return new Response(
        JSON.stringify({ error: "card_token is required for saved card payment" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // Validate wallet request
    if (payment_method === "wallet") {
      if (!PAYMOB_WALLET_INTEGRATION_ID) {
        throw new Error("Wallet payments are not configured yet. Please use card payment.");
      }
      if (!wallet_phone) {
        throw new Error("Wallet phone number is required.");
      }
    }

    // ── Step 1: Authentication ──────────────────────────────────────────────
    const authResponse = await fetch("https://accept.paymob.com/api/auth/tokens", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ api_key: PAYMOB_API_KEY }),
    });
    const authData = await authResponse.json();
    const authToken = authData.token;
    if (!authToken) throw new Error(`Paymob auth failed: ${JSON.stringify(authData)}`);

    // ── Step 2: Order Registration ──────────────────────────────────────────
    const amountCents = Math.round(amount * 100);

    // Reuse existing Paymob order if we already created one for this booking
    const { data: existingPmt } = await supabase
      .from("payments")
      .select("transaction_id")
      .eq("booking_id", booking_id)
      .not("transaction_id", "is", null)
      .maybeSingle();

    let orderId: number | null = existingPmt?.transaction_id
      ? parseInt(existingPmt.transaction_id)
      : null;

    if (!orderId) {
      const orderResponse = await fetch("https://accept.paymob.com/api/ecommerce/orders", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          auth_token: authToken,
          delivery_needed: false,
          amount_cents: amountCents,
          currency: "EGP",
          merchant_order_id: booking_id,
          items: [{ name: activity_title, amount_cents: amountCents, quantity: 1 }],
        }),
      });
      const orderData = await orderResponse.json();
      orderId = orderData.id ?? null;
      if (!orderId) throw new Error(`Order registration failed: ${JSON.stringify(orderData)}`);

      // Save transaction_id immediately so retries can reuse this order
      const platformFeeEarly = Math.round(amount * 10) / 100;
      const businessEarningsEarly = Math.round((amount - platformFeeEarly) * 100) / 100;
      await supabase.from("payments").upsert({
        booking_id,
        user_id,
        activity_id,
        amount,
        platform_fee: platformFeeEarly,
        business_earnings: businessEarningsEarly,
        transaction_id: orderId.toString(),
        status: "pending",
        payment_method,
      }, { onConflict: "booking_id" });
    }

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

    const billingPhone = user_phone || "+201000000000"; // Phone optional for card
    if (payment_method === "wallet" && (!wallet_phone || wallet_phone.length < 10)) {
      return new Response(
        JSON.stringify({ error: "Valid wallet phone number is required" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const integrationId = payment_method === "wallet"
      ? parseInt(PAYMOB_WALLET_INTEGRATION_ID!)
      : parseInt(PAYMOB_INTEGRATION_ID);

    const paymentKeyResponse = await fetch("https://accept.paymob.com/api/acceptance/payment_keys", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        auth_token: authToken,
        amount_cents: amountCents,
        expiration: 3600,
        order_id: orderId,
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
        currency: "EGP",
        integration_id: integrationId,
        lock_order_when_paid: true,
        save_card: true,
      }),
    });
    const paymentKeyData = await paymentKeyResponse.json();
    const paymentToken = paymentKeyData.token;
    if (!paymentToken) throw new Error(`Payment key failed: ${JSON.stringify(paymentKeyData)}`);

    // ── Step 4a: Card — build iframe URL ────────────────────────────────────
    let responsePayload: Record<string, unknown>;

    if (payment_method === "card") {
      if (!PAYMOB_IFRAME_ID) throw new Error("Iframe ID not configured");
      const iframeUrl = `https://accept.paymob.com/api/acceptance/iframes/${PAYMOB_IFRAME_ID}?payment_token=${paymentToken}`;
      responsePayload = {
        iframe_url: iframeUrl,
        payment_token: paymentToken,
        order_id: orderId,
        booking_id,
      };

    // ── Step 4b: Saved card — pay with token ────────────────────────────────
    } else if (payment_method === "saved_card") {
      const tokenPayResponse = await fetch("https://accept.paymob.com/api/acceptance/payments/pay", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          source: { identifier: card_token, subtype: "TOKEN" },
          payment_token: paymentToken,
        }),
      });
      const tokenPayData = await tokenPayResponse.json();

      // If 3DS is required Paymob returns redirect_url; otherwise success inline
      const redirectUrl = tokenPayData.redirect_url;
      const isSuccess = tokenPayData.success === true;

      if (!isSuccess && !redirectUrl) {
        throw new Error(`Token payment failed: ${JSON.stringify(tokenPayData)}`);
      }

      responsePayload = {
        redirect_url: redirectUrl ?? null,
        success: isSuccess,
        payment_token: paymentToken,
        order_id: orderId,
        booking_id,
      };

    // ── Step 4c: Wallet — call Paymob pay endpoint ──────────────────────────
    } else {
      const walletResponse = await fetch("https://accept.paymob.com/api/acceptance/payments/pay", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          source: {
            identifier: wallet_phone, // e.g. "01xxxxxxxxx"
            subtype: "WALLET",
          },
          payment_token: paymentToken,
        }),
      });
      const walletData = await walletResponse.json();

      // Paymob returns a redirect_url — user opens it to confirm in their wallet app
      const redirectUrl = walletData.redirect_url;
      if (!redirectUrl) {
        throw new Error(`Wallet payment initiation failed: ${JSON.stringify(walletData)}`);
      }

      responsePayload = {
        redirect_url: redirectUrl,
        payment_token: paymentToken,
        order_id: orderId,
        booking_id,
      };
    }

    // ── Update payment_method if it changed (e.g. switching from card to saved_card) ─
    await supabase
      .from("payments")
      .update({ payment_method })
      .eq("booking_id", booking_id)
      .in("status", ["pending", "processing"]);

    return new Response(JSON.stringify(responsePayload), {
      status: 200,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });

  } catch (error) {
    console.error("Paymob init error:", error);
    const errorMessage = error instanceof Error ? error.message : "Unknown error";
    return new Response(JSON.stringify({ error: errorMessage }), {
      status: 500,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }
});
