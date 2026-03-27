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
    const PAYMOB_API_KEY = Deno.env.get("PAYMOB_API_KEY");
    const PAYMOB_IFRAME_ID = Deno.env.get("PAYMOB_IFRAME_ID");
    const PAYMOB_INTEGRATION_ID = Deno.env.get("PAYMOB_INTEGRATION_ID");
    // Wallet integration ID — add this secret when received from Paymob dashboard
    const PAYMOB_WALLET_INTEGRATION_ID = Deno.env.get("PAYMOB_WALLET_INTEGRATION_ID");

    if (!PAYMOB_API_KEY || !PAYMOB_INTEGRATION_ID) {
      throw new Error("Missing Paymob configuration");
    }

    const body = await req.json();
    const {
      booking_id,
      user_id,
      activity_id,
      amount,
      activity_title,
      user_email,
      user_name,
      user_phone,
      payment_method = "card", // "card" | "wallet"
      wallet_phone,
    } = body;

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
    const orderResponse = await fetch("https://accept.paymob.com/api/ecommerce/orders", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        auth_token: authToken,
        delivery_needed: false,
        amount_cents: amountCents,
        currency: "EGP",
        merchant_order_id: booking_id,
        items: [
          {
            name: activity_title,
            amount_cents: amountCents,
            quantity: 1,
          },
        ],
      }),
    });
    const orderData = await orderResponse.json();
    const orderId = orderData.id;
    if (!orderId) throw new Error(`Order registration failed: ${JSON.stringify(orderData)}`);

    // ── Step 3: Payment Key ─────────────────────────────────────────────────
    const nameParts = (user_name || "User").split(" ");
    const firstName = nameParts[0] || "User";
    const lastName = nameParts.slice(1).join(" ") || "User";

    // Use wallet integration ID for wallet payments, card integration ID for cards
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
          email: user_email || "user@example.com",
          floor: "NA",
          first_name: firstName,
          street: "NA",
          building: "NA",
          phone_number: user_phone || "+201000000000",
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

    // ── Step 4b: Wallet — call Paymob pay endpoint ──────────────────────────
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

    // ── Save / update payment record in DB ──────────────────────────────────
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    const platformFee = amount * 0.1;
    const businessEarnings = amount * 0.9;

    // Avoid duplicate records on retry
    const { data: existingPayment } = await supabase
      .from("payments")
      .select("id")
      .eq("booking_id", booking_id)
      .eq("status", "pending")
      .maybeSingle();

    if (existingPayment) {
      const { error: updateError } = await supabase
        .from("payments")
        .update({
          transaction_id: orderId.toString(),
          payment_method,
        })
        .eq("id", existingPayment.id);
      if (updateError) console.error("Failed to update payment record:", updateError);
    } else {
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
      if (paymentError) console.error("Failed to create payment record:", paymentError);
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
