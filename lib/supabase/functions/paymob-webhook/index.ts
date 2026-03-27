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
    console.warn("HMAC verification skipped: missing secret or received HMAC");
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

// Credit the business wallet after a successful payment
async function creditBusinessWallet(
  supabase: any,
  activityId: string,
  businessEarnings: number,
  bookingId: string,
  activityTitle: string
) {
  try {
    // Get the business_id from the activity
    const { data: activity, error: activityError } = await supabase
      .from("activities")
      .select("business_id, title")
      .eq("id", activityId)
      .single();

    if (activityError || !activity) {
      console.error("Could not find activity for wallet credit:", activityError);
      return;
    }

    const businessId = activity.business_id;
    const title = activity.title || activityTitle;

    // Upsert wallet — create if doesn't exist, otherwise update balance
    const { data: existingWallet } = await supabase
      .from("business_wallets")
      .select("id, balance, total_earned")
      .eq("business_id", businessId)
      .single();

    if (existingWallet) {
      // Update existing wallet
      await supabase
        .from("business_wallets")
        .update({
          balance: existingWallet.balance + businessEarnings,
          total_earned: existingWallet.total_earned + businessEarnings,
        })
        .eq("business_id", businessId);
    } else {
      // Create new wallet
      await supabase
        .from("business_wallets")
        .insert({
          business_id: businessId,
          balance: businessEarnings,
          total_earned: businessEarnings,
          total_withdrawn: 0,
        });
    }

    // Record the transaction in the ledger
    await supabase.from("wallet_transactions").insert({
      business_id: businessId,
      type: "earning",
      amount: businessEarnings,
      reference_id: bookingId,
      description: `Earning from booking: ${title}`,
    });

    console.log(`Credited ${businessEarnings} to business ${businessId} wallet`);
  } catch (e) {
    console.error("Failed to credit business wallet:", e);
  }
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const hmacSecret = Deno.env.get("PAYMOB_HMAC_SECRET") || "";
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Parse the callback data
    let callbackData: any;
    let receivedHmac: string = "";

    if (req.method === "GET") {
      // Handle redirect callback (GET with query params)
      const url = new URL(req.url);
      const params = Object.fromEntries(url.searchParams);
      receivedHmac = params.hmac || "";
      callbackData = {
        obj: {
          id: params.id,
          pending: params.pending === "true",
          success: params.success === "true",
          amount_cents: params.amount_cents,
          order: {
            id: params.order,
            merchant_order_id: params.merchant_order_id
          },
          source_data: { type: params.source_data_type },
        },
      };
    } else {
      // Handle webhook callback (POST with JSON body)
      callbackData = await req.json();
      receivedHmac = callbackData.hmac || "";
    }

    // Verify HMAC signature
    if (hmacSecret) {
      const isValid = await verifyHmac(callbackData, receivedHmac, hmacSecret);
      if (!isValid) {
        console.error("HMAC verification failed");
        return new Response(
          JSON.stringify({ error: "Invalid HMAC signature" }),
          { status: 401, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
      }
    }

    const { obj } = callbackData;
    const transactionId = obj.id?.toString() || "";
    const orderId = obj.order?.merchant_order_id || obj.order?.id?.toString();
    const isSuccess = obj.success === true;
    const isPending = obj.pending === true;
    const paymentMethod = obj.source_data?.type || "card";

    console.log("Paymob callback received:", {
      transactionId,
      orderId,
      isSuccess,
      isPending,
      paymentMethod,
    });

    // Determine payment status
    let status = "failed";
    if (isSuccess) {
      status = "completed";
    } else if (isPending) {
      status = "processing";
    }

    // Find payment by booking_id (merchant_order_id)
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

    // Prevent processing the same successful payment twice
    if (paymentData.status === "completed") {
      console.log("Payment already completed, skipping:", paymentData.id);
      return new Response(
        JSON.stringify({ success: true, status: "already_completed", booking_id: paymentData.booking_id }),
        { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // Update payment status
    const normalizedMethod = paymentMethod === "wallet" ? "wallet" : paymentMethod === "applepay" ? "applePay" : "card";
    const { error: updatePaymentError } = await supabase
      .from("payments")
      .update({
        status,
        transaction_id: transactionId,
        payment_method: normalizedMethod,
      })
      .eq("id", paymentData.id);

    if (updatePaymentError) {
      console.error("Failed to update payment:", updatePaymentError);
    }

    // Update booking status
    const bookingStatus = isSuccess ? "confirmed" : isPending ? "pending" : "cancelled";
    const { error: updateBookingError } = await supabase
      .from("bookings")
      .update({ status: bookingStatus })
      .eq("id", paymentData.booking_id);

    if (updateBookingError) {
      console.error("Failed to update booking:", updateBookingError);
    }

    // Credit business wallet on successful payment
    if (isSuccess && paymentData.business_earnings > 0) {
      await creditBusinessWallet(
        supabase,
        paymentData.activity_id,
        paymentData.business_earnings,
        paymentData.booking_id,
        "" // title will be fetched from activity
      );
    }

    console.log("Payment processed successfully:", {
      paymentId: paymentData.id,
      status,
      bookingStatus,
      walletCredited: isSuccess,
    });

    return new Response(
      JSON.stringify({
        success: true,
        status,
        booking_id: paymentData.booking_id
      }),
      {
        status: 200,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Paymob webhook error:", error);
    const errorMessage = error instanceof Error ? error.message : "Unknown error";
    return new Response(
      JSON.stringify({ error: errorMessage }),
      {
        status: 500,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      }
    );
  }
});
