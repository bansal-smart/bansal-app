import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

const cleanText = (value: unknown) => typeof value === "string" ? value.trim() : "";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { error: "Method not allowed" });

  try {
    const authorization = req.headers.get("Authorization");
    const accessToken = authorization?.replace(/^Bearer\s+/i, "").trim();
    if (!accessToken) return json(401, { error: "Authentication required." });

    const body = await req.json().catch(() => ({}));
    const fullName = cleanText(body.full_name);
    const classLevel = cleanText(body.class_level);
    const targetExam = cleanText(body.target_exam);
    const dob = cleanText(body.dob);
    const centreId = cleanText(body.centre_id);
    const phone = cleanText(body.phone);

    if (fullName.length < 2 || !classLevel || !targetExam || !dob || !centreId) {
      return json(400, { error: "Please provide your name, date of birth, class, target exam and preferred centre." });
    }

    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      serviceKey,
      { auth: { autoRefreshToken: false, persistSession: false } },
    );

    const { data: authData, error: authError } = await admin.auth.getUser(accessToken);
    if (authError || !authData.user) return json(401, { error: "Your session expired. Please verify your number again." });

    const { data: centre, error: centreError } = await admin
      .from("centres")
      .select("id")
      .eq("id", centreId)
      .eq("is_published", true)
      .eq("is_suspended", false)
      .maybeSingle();
    if (centreError) throw centreError;
    if (!centre) return json(400, { error: "This centre is not available. Please select another centre." });

    const profileUpdate: Record<string, unknown> = {
      full_name: fullName,
      class_level: classLevel,
      target_exam: targetExam,
      dob,
      centre_id: centre.id,
      onboarding_completed: false,
      updated_at: new Date().toISOString(),
    };
    if (phone) profileUpdate.phone = phone;

    const { error: profileError } = await admin
      .from("profiles")
      .update(profileUpdate)
      .eq("user_id", authData.user.id);
    if (profileError) throw profileError;

    return json(200, { ok: true, user_id: authData.user.id });
  } catch (error) {
    console.error("mobile-complete-profile failed", error);
    return json(500, { error: (error as Error).message });
  }
});
