import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { crypto } from "https://deno.land/std@0.168.0/crypto/mod.ts";
import { encode as hexEncode } from "https://deno.land/std@0.168.0/encoding/hex.ts";

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, GET, OPTIONS",
  "access-control-max-age": "86400",
};

async function hmacSha512(secret: string, message: string): Promise<string> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw", encoder.encode(secret),
    { name: "HMAC", hash: "SHA-512" }, false, ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, encoder.encode(message));
  return new TextDecoder().decode(hexEncode(new Uint8Array(sig)));
}

async function verifyHmacPost(data: any, receivedHmac: string, hmacSecret: string): Promise<boolean> {
  if (!hmacSecret || !receivedHmac) return false;
  try {
    const obj = data.obj || data;
    const fields = [
      obj.amount_cents, obj.created_at, obj.currency, obj.error_occured,
      obj.has_parent_transaction, obj.id, obj.integration_id, obj.is_3d_secure,
      obj.is_auth, obj.is_capture, obj.is_refunded, obj.is_standalone_payment,
      obj.is_voided, obj.order?.id, obj.owner, obj.pending,
      obj.source_data?.pan, obj.source_data?.sub_type, obj.source_data?.type,
      obj.success,
    ];
    const calculated = await hmacSha512(hmacSecret, fields.join(""));
    return calculated === receivedHmac;
  } catch (e) {
    console.error("HMAC (POST) error:", e);
    return false;
  }
}

// STATUS_ORDER defines forward direction; a lower rank cannot overwrite a higher rank.
const STATUS_ORDER: Record<string, number> = { pending: 0, processing: 1, failed: 1, completed: 2 };

async function confirmBooking(
  supabase: any,
  paymentData: { id: string; booking_id: string; activity_id: string; business_earnings: number; user_id: string; status: string },
  newPaymentStatus: string,
  transactionId: string,
  isSuccess: boolean,
  isPending: boolean,
  paymentMethod?: string,
  cardToken?: string,
  maskedPan?: string,
  cardType?: string,
) {
  // Never downgrade a completed payment (prevents webhook retry from overwriting success)
  const currentRank = STATUS_ORDER[paymentData.status] ?? 0;
  const newRank = STATUS_ORDER[newPaymentStatus] ?? 0;

  if (currentRank > newRank) {
    console.log(`Skipping status downgrade for payment ${paymentData.id}: ${paymentData.status} → ${newPaymentStatus}`);
    // Still attempt to save card token even if payment is already completed
    if (cardToken && paymentData.user_id) {
      await saveCardToken(supabase, paymentData.user_id, cardToken, maskedPan, cardType);
    }
    return;
  }

  const normalizedMethod = paymentMethod === "wallet" ? "wallet"
    : paymentMethod === "applepay" ? "applePay" : "card";

  await supabase.from("payments")
    .update({ status: newPaymentStatus, transaction_id: transactionId, payment_method: normalizedMethod })
    .eq("id", paymentData.id);

  const bookingStatus = isSuccess ? "confirmed" : isPending ? "pending" : "cancelled";
  await supabase.from("bookings")
    .update({ status: bookingStatus })
    .eq("id", paymentData.booking_id);

  if (!isSuccess && !isPending) {
    await supabase.rpc("release_spot", { p_activity_id: paymentData.activity_id });
    console.log("Released spot for failed payment:", paymentData.booking_id);
  }

  if (isSuccess && cardToken && paymentData.user_id) {
    await saveCardToken(supabase, paymentData.user_id, cardToken, maskedPan, cardType);
  }

  // Credit business wallet on success — errors here must not fail the webhook response
  if (isSuccess && paymentData.business_earnings > 0) {
    try {
      const { data: activity } = await supabase
        .from("activities").select("business_id, title")
        .eq("id", paymentData.activity_id).single();
      if (activity) {
        const { error: creditError } = await supabase.rpc("credit_wallet", {
          p_business_id: activity.business_id,
          p_amount: paymentData.business_earnings,
          p_booking_id: paymentData.booking_id,
          p_description: `Earning from booking: ${activity.title}`,
        });
        if (creditError) console.error("credit_wallet failed (non-fatal):", creditError);
        else console.log(`Credited ${paymentData.business_earnings} to business ${activity.business_id}`);
      }
    } catch (e) {
      console.error("Wallet credit threw (non-fatal):", e);
    }
  }

  console.log("Booking", paymentData.booking_id, "→", bookingStatus);
}

async function saveCardToken(supabase: any, userId: string, cardToken: string, maskedPan?: string, cardType?: string) {
  const { error } = await supabase.from("user_payment_methods").upsert(
    { user_id: userId, card_token: cardToken, masked_pan: maskedPan ?? null, card_type: cardType ?? null },
    { onConflict: "user_id,card_token" }
  );
  if (error) console.error("Failed to save card token:", error);
  else console.log("Card token saved for user:", userId);
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  // ── GET: Browser redirect from Paymob — show result page only ─────────────
  // DB updates are handled by the POST webhook (server-to-server), which is the
  // authoritative source. The GET redirect just closes the WebView with a message.
  if (req.method === "GET") {
    const params = new URL(req.url).searchParams;
    const success = params.get("success") === "true";
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

  // ── POST: Webhook (server-to-server from Paymob) ───────────────────────────
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const hmacSecret = Deno.env.get("PAYMOB_HMAC_SECRET") || "";
  const supabase = createClient(supabaseUrl, supabaseKey);

  try {
    if (!hmacSecret) {
      console.error("PAYMOB_HMAC_SECRET not configured");
      // Return 200 so Paymob doesn't keep retrying — this is a config issue, not a transient error
      return new Response(
        JSON.stringify({ error: "Webhook signature verification not configured" }),
        { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const postUrl = new URL(req.url);
    const callbackData = await req.json();
    // Paymob sends HMAC as a query param on the notification URL, not in the body
    const receivedHmac = postUrl.searchParams.get("hmac") || callbackData.hmac || "";
    console.log("POST webhook arrived — type:", callbackData.type, "has hmac:", !!receivedHmac,
      "obj keys:", Object.keys(callbackData.obj || {}).join(","));

    const isValid = await verifyHmacPost(callbackData, receivedHmac, hmacSecret);
    if (!isValid) {
      console.error("HMAC verification failed — rejecting webhook");
      // Return 401 for bad HMAC — this is intentional (tells Paymob to check the secret)
      return new Response(
        JSON.stringify({ error: "Invalid HMAC signature" }),
        { status: 401, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const { obj } = callbackData;
    const transactionId = obj.id?.toString() || "";
    const paymobOrderId = obj.order?.id?.toString() || "";
    const isSuccess = obj.success === true;
    const isPending = obj.pending === true;
    const paymentMethod = obj.source_data?.type || "card";
    const cardToken = obj.token || obj.card_token || null;
    const maskedPan = obj.masked_pan || obj.source_data?.pan || null;
    const cardType = obj.source_data?.type || null;

    console.log("POST webhook received:", { transactionId, paymobOrderId, isSuccess, isPending, hasCardToken: !!cardToken });

    let newStatus = "failed";
    if (isSuccess) newStatus = "completed";
    else if (isPending) newStatus = "processing";

    const { data: paymentData, error: findError } = await supabase
      .from("payments")
      .select("id, booking_id, activity_id, business_earnings, status, user_id")
      .eq("paymob_order_id", paymobOrderId)
      .single();

    if (findError || !paymentData) {
      console.error("Payment not found for paymob_order_id:", paymobOrderId, findError);
      // Return 200 so Paymob stops retrying an order we genuinely don't have
      return new Response(
        JSON.stringify({ error: "Payment not found", paymobOrderId }),
        { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    try {
      await confirmBooking(
        supabase, paymentData, newStatus, transactionId,
        isSuccess, isPending, paymentMethod, cardToken, maskedPan, cardType
      );
    } catch (e) {
      // Log but don't propagate — always acknowledge to Paymob with 200
      console.error("confirmBooking error (non-fatal):", e);
    }

    // Notify user (fire-and-forget)
    if (paymentData.user_id) {
      const notifPayload = isSuccess
        ? { title: "Booking Confirmed!", body: "Your booking has been confirmed. See you there!", type: "booking_confirmed" }
        : { title: "Payment Failed", body: "Your payment could not be processed. Please try again.", type: "payment_failed" };
      fetch(`${supabaseUrl}/functions/v1/send-notification`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "Authorization": `Bearer ${supabaseKey}` },
        body: JSON.stringify({ user_ids: [paymentData.user_id], ...notifPayload }),
      }).catch((e) => console.error("Failed to send notification:", e));
    }

    return new Response(
      JSON.stringify({ success: true, status: newStatus, booking_id: paymentData.booking_id }),
      { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Webhook error:", error);
    // Always return 200 for POST webhooks — Paymob retries on non-200, which could cause
    // double-processing of a transaction that was actually handled successfully.
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : "Unknown error" }),
      { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }
});
