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
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Authenticate caller
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
    const { booking_id } = body;
    if (!booking_id) {
      return new Response(
        JSON.stringify({ error: "booking_id is required" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const cancelledBy: string = body.cancelled_by || "user";

    let booking: any;
    if (cancelledBy === "business") {
      // Business cancelling: verify caller owns the activity
      const { data, error } = await supabase
        .from("bookings")
        .select("*, activities!inner(business_id)")
        .eq("id", booking_id)
        .eq("activities.business_id", user.id)
        .single();
      if (error || !data) {
        return new Response(
          JSON.stringify({ success: false, error: "Booking not found or not your activity" }),
          { status: 404, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
      }
      booking = data;
    } else {
      // User cancelling: must belong to the authenticated user
      const { data, error } = await supabase
        .from("bookings")
        .select("*")
        .eq("id", booking_id)
        .eq("user_id", user.id)
        .single();
      if (error || !data) {
        return new Response(
          JSON.stringify({ error: "Booking not found" }),
          { status: 404, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
      }
      booking = data;
    }

    if (booking.status === "cancelled" || booking.status === "completed") {
      return new Response(
        JSON.stringify({ error: `Booking is already ${booking.status}` }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // Fetch activity to read per-activity cancellation policy
    const { data: activity } = await supabase
      .from("activities")
      .select("cancellation_hours")
      .eq("id", booking.activity_id)
      .single();

    const cancellationHours = activity?.cancellation_hours ?? 24;

    // Businesses can cancel at any time; users are subject to the cancellation window
    let isRefundEligible: boolean;
    if (cancelledBy === "business") {
      // Business-initiated cancellation always triggers a refund to the user
      isRefundEligible = true;
    } else {
      // Check cancellation window using per-activity policy
      const activityDate = new Date(booking.date_time);
      const now = new Date();
      const hoursUntil = (activityDate.getTime() - now.getTime()) / (1000 * 60 * 60);
      isRefundEligible = hoursUntil >= cancellationHours;
    }

    // Cancel the booking
    const { error: cancelError } = await supabase
      .from("bookings")
      .update({ status: "cancelled" })
      .eq("id", booking_id);

    if (cancelError) {
      return new Response(
        JSON.stringify({ error: "Failed to cancel booking" }),
        { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // Release the spot
    const { error: releaseError } = await supabase.rpc("release_spot", {
      p_activity_id: booking.activity_id,
    });
    if (releaseError) {
      console.error("Failed to release spot:", releaseError);
    }

    // Handle refund if eligible
    let refundStatus = "none";
    if (isRefundEligible) {
      // Find the completed payment for this booking
      const { data: payment } = await supabase
        .from("payments")
        .select("id, business_earnings, activity_id, status")
        .eq("booking_id", booking_id)
        .eq("status", "completed")
        .maybeSingle();

      if (payment) {
        // Mark payment for refund (admin processes actual Paymob refund manually)
        await supabase
          .from("payments")
          .update({ status: "refunded", refund_status: "requested" })
          .eq("id", payment.id);

        // Debit business wallet
        const { data: activity } = await supabase
          .from("activities")
          .select("business_id")
          .eq("id", payment.activity_id)
          .single();

        if (activity) {
          const { error: debitError } = await supabase.rpc("debit_wallet", {
            p_business_id: activity.business_id,
            p_amount: payment.business_earnings,
            p_booking_id: booking_id,
            p_description: "Refund deduction for cancelled booking",
          });
          if (debitError) {
            console.error("Failed to debit wallet:", debitError);
          }
        }

        refundStatus = "requested";
      }
    }

    // Notify the booker of cancellation (fire-and-forget)
    // For business-initiated cancellations the booker is booking.user_id, not the caller
    const notifyUserId = cancelledBy === "business" ? booking.user_id : user.id;
    fetch(`${supabaseUrl}/functions/v1/send-notification`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${supabaseServiceKey}`,
      },
      body: JSON.stringify({
        user_ids: [notifyUserId],
        title: "Booking Cancelled",
        body: cancelledBy === "business"
          ? "Your booking has been cancelled by the host."
          : "Your booking has been cancelled.",
        type: "booking_cancelled",
      }),
    }).catch((e) => console.error("Failed to send cancellation notification:", e));

    return new Response(
      JSON.stringify({
        success: true,
        refund_eligible: isRefundEligible,
        refund_status: refundStatus,
        message: isRefundEligible
          ? "Booking cancelled. Refund has been requested and will be processed."
          : `Booking cancelled. No refund — cancellation was less than ${cancellationHours} hours before the activity.`,
      }),
      { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Cancellation error:", error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : "Unknown error" }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }
});
