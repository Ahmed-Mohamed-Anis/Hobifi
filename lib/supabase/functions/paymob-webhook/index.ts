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

// Verify HMAC signature from Paymob
async function verifyHmac(data: any, receivedHmac: string, hmacSecret: string): Promise<boolean> {
  if (!hmacSecret || !receivedHmac) {
    console.error("HMAC verification skipped: missing secret or received HMAC");
    return false;
  }

  try {
    // Paymob HMAC: concatenate specific fields in alphabetical order of keys
    const obj = data.obj || data;
    const hmacFields = [
      obj.amount_cents,
      obj.created_at,
      obj.currency,
      obj.error_occured,
      obj.has_parent_transaction,
      obj.id,
      obj.integration_id,
      obj.is_3d_secure,
      obj.is_auth,
      obj.is_capture,
      obj.is_refunded,
      obj.is_standalone_payment,
      obj.is_voided,
      obj.order?.id,
      obj.owner,
      obj.pending,
      obj.source_data?.pan,
      obj.source_data?.sub_type,
      obj.source_data?.type,
      obj.success,
    ];

    const hmacString = hmacFields.join("");
    const encoder = new TextEncoder();
    const keyData = encoder.encode(hmacSecret);
    const messageData = encoder.encode(hmacString);

    const key = await crypto.subtle.importKey(
      "raw",
      keyData,
      { name: "HMAC", hash: "SHA-512" },
      false,
      ["sign"]
    );

    const signature = await crypto.subtle.sign("HMAC", key, messageData);
    const calculatedHmac = new TextDecoder().decode(hexEncode(new Uint8Array(signature)));

    return calculatedHmac === receivedHmac;
  } catch (e) {
    console.error("HMAC verification error:", e);
    return false;
  }
}

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
      .select("id, booking_id, activity_id, business_earnings, status, user_id")
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

    // Notify user of booking confirmation (fire-and-forget)
    if (isSuccess && paymentData.user_id) {
      fetch(`${supabaseUrl}/functions/v1/send-notification`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${supabaseKey}`,
        },
        body: JSON.stringify({
          user_ids: [paymentData.user_id],
          title: "Booking Confirmed!",
          body: "Your booking has been confirmed. See you there!",
          type: "booking_confirmed",
        }),
      }).catch((e) => console.error("Failed to send booking confirmation notification:", e));
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

      // Notify user of payment failure (fire-and-forget)
      if (paymentData.user_id) {
        fetch(`${supabaseUrl}/functions/v1/send-notification`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${supabaseKey}`,
          },
          body: JSON.stringify({
            user_ids: [paymentData.user_id],
            title: "Payment Failed",
            body: "Your payment could not be processed. Please try again.",
            type: "payment_failed",
          }),
        }).catch((e) => console.error("Failed to send payment failure notification:", e));
      }
    }

    // Save card token on success (if Paymob returned one)
    if (isSuccess && obj.card_token && paymentData.user_id) {
      const maskedPan = obj.masked_pan || obj.source_data?.pan || null;
      const cardType = obj.source_data?.type || null;
      const { error: cardError } = await supabase
        .from("user_payment_methods")
        .upsert(
          { user_id: paymentData.user_id, card_token: obj.card_token, masked_pan: maskedPan, card_type: cardType },
          { onConflict: "user_id,card_token" }
        );
      if (cardError) console.error("Failed to save card token:", cardError);
      else console.log("Card token saved for user:", paymentData.user_id);
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
