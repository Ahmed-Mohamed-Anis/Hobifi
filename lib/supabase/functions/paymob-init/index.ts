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
    const PAYMOB_WALLET_INTEGRATION_ID = Deno.env.get("PAYMOB_WALLET_INTEGRATION_ID");

    if (!PAYMOB_API_KEY || !PAYMOB_INTEGRATION_ID) {
      throw new Error("Missing Paymob configuration");
    }

    // ── Authenticate the caller via JWT ─────────────────────────────────────
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

    // ── Rate limiting: max 5 payment init calls per user per minute ──────────
    const oneMinuteAgo = new Date(Date.now() - 60_000).toISOString();
    const { count } = await supabase
      .from("payment_rate_limits")
      .select("id", { count: "exact", head: true })
      .eq("user_id", authenticatedUserId)
      .gte("created_at", oneMinuteAgo);

    if ((count ?? 0) >= 5) {
      return new Response(
        JSON.stringify({ error: "Too many requests. Please wait before trying again." }),
        { status: 429, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    await supabase.from("payment_rate_limits").insert({ user_id: authenticatedUserId });

    if (Math.random() < 0.1) {
      await supabase.rpc("cleanup_payment_rate_limits");
    }

    const body = await req.json();
    const {
      booking_id,
      activity_id,
      activity_title,
      user_email,
      user_name,
      user_phone,
      payment_method = "card",
      wallet_phone,
      card_token,
      save_card = false,
    } = body;

    // ── Verify the booking belongs to the authenticated user and is payable ──
    const { data: bookingRow, error: bookingError } = await supabase
      .from("bookings")
      .select("user_id, status")
      .eq("id", booking_id)
      .single();

    if (bookingError || !bookingRow) {
      return new Response(
        JSON.stringify({ error: "Booking not found" }),
        { status: 404, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }
    if (bookingRow.user_id !== authenticatedUserId) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: booking does not belong to you" }),
        { status: 403, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }
    if (bookingRow.status !== "pending") {
      return new Response(
        JSON.stringify({ error: "Booking is not in a payable state", status: bookingRow.status }),
        { status: 409, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // ── Look up the real price from the database — never trust the client ────
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
    const user_id = authenticatedUserId;

    if (payment_method === "saved_card" && !card_token) {
      return new Response(
        JSON.stringify({ error: "card_token is required for saved card payment" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    if (payment_method === "wallet") {
      if (!PAYMOB_WALLET_INTEGRATION_ID) {
        throw new Error("Wallet payments are not configured yet. Please use card payment.");
      }
      if (!wallet_phone) {
        throw new Error("Wallet phone number is required.");
      }
    }

    // ── Step 1: Authentication ───────────────────────────────────────────────
    const authResponse = await fetch("https://accept.paymob.com/api/auth/tokens", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ api_key: PAYMOB_API_KEY }),
    });
    const authData = await authResponse.json();
    const authToken = authData.token;
    if (!authToken) throw new Error(`Paymob auth failed: ${JSON.stringify(authData)}`);

    // ── Step 2: Order Registration ───────────────────────────────────────────
    const amountCents = Math.round(amount * 100);

    const { data: existingPmt } = await supabase
      .from("payments")
      .select("paymob_order_id")
      .eq("booking_id", booking_id)
      .not("paymob_order_id", "is", null)
      .maybeSingle();

    let orderId: number | null = existingPmt?.paymob_order_id
      ? parseInt(existingPmt.paymob_order_id)
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
          items: [{ name: activity_title, amount_cents: amountCents, quantity: 1 }],
        }),
      });
      const orderData = await orderResponse.json();
      orderId = orderData.id ?? null;
      if (!orderId) throw new Error(`Order registration failed: ${JSON.stringify(orderData)}`);

      const platformFee = Math.round(amount * 10) / 100;
      const businessEarnings = Math.round((amount - platformFee) * 100) / 100;
      await supabase.from("payments").upsert({
        booking_id,
        user_id,
        activity_id,
        amount,
        platform_fee: platformFee,
        business_earnings: businessEarnings,
        paymob_order_id: orderId.toString(),
        status: "pending",
        payment_method,
      }, { onConflict: "booking_id" });
    }

    // ── Step 3: Payment Key ──────────────────────────────────────────────────
    const nameParts = (user_name || "User").split(" ");
    const firstName = nameParts[0] || "User";
    const lastName = nameParts.slice(1).join(" ") || "User";

    const billingEmail = user_email || callerUser.email;
    if (!billingEmail) {
      return new Response(
        JSON.stringify({ error: "User email is required for payment" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const billingPhone = user_phone || "+201000000000";
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
        expiration: 900, // 15 minutes — matches our booking hold window
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
        save_card: save_card === true,
      }),
    });
    const paymentKeyData = await paymentKeyResponse.json();
    const paymentToken = paymentKeyData.token;
    if (!paymentToken) throw new Error(`Payment key failed: ${JSON.stringify(paymentKeyData)}`);

    // ── Step 4a: Card — build iframe URL ─────────────────────────────────────
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

    // ── Step 4b: Saved card — pay with token ─────────────────────────────────
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

    // ── Step 4c: Wallet ───────────────────────────────────────────────────────
    } else {
      const walletResponse = await fetch("https://accept.paymob.com/api/acceptance/payments/pay", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          source: { identifier: wallet_phone, subtype: "WALLET" },
          payment_token: paymentToken,
        }),
      });
      const walletData = await walletResponse.json();

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
