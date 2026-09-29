import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

// Second half of mobile phone sign-up. mobile-prpsms-verify-otp proves the
// phone and returns a signed registration token; this function accepts that
// token together with the student's details and creates a complete account,
// so no nameless "Unnamed" students are ever created.

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

function toE164(phone: string): string {
  const digits = phone.replace(/\D/g, "");
  if (digits.length === 10) return `+91${digits}`;
  if (digits.length === 12 && digits.startsWith("91")) return `+${digits}`;
  if (digits.length === 11 && digits.startsWith("0")) return `+91${digits.slice(1)}`;
  throw new Error("Invalid Indian phone number");
}

async function hmacSha256Hex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
  return Array.from(new Uint8Array(signature))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { error: "Method not allowed" });

  try {
    const body = await req.json().catch(() => ({}));
    const phone = cleanText(body.phone);
    const token = cleanText(body.registration_token);
    const expiresAt = Number(body.registration_expires_at);
    const fullName = cleanText(body.full_name);
    const classLevel = cleanText(body.class_level);
    const targetExam = cleanText(body.target_exam);

    if (!phone || !token || !Number.isFinite(expiresAt)) {
      return json(400, { error: "Invalid input. Required: phone and registration token" });
    }
    if (fullName.length < 2 || !classLevel || !targetExam) {
      return json(400, { error: "Please provide your name, class and target exam." });
    }

    let e164: string;
    try {
      e164 = toE164(phone);
    } catch (error) {
      return json(400, { error: (error as Error).message });
    }

    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const expected = await hmacSha256Hex(serviceKey, `mobile-registration:${e164}:${expiresAt}`);
    if (!timingSafeEqual(expected, token)) {
      return json(401, { error: "Registration session is invalid. Please verify your number again." });
    }
    if (expiresAt < Date.now()) {
      return json(401, { error: "Registration session expired. Please verify your number again." });
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      serviceKey,
      { auth: { autoRefreshToken: false, persistSession: false } },
    );

    const { data: settings } = await admin
      .from("platform_settings")
      .select("open_registrations")
      .eq("id", 1)
      .maybeSingle();
    if (settings && settings.open_registrations === false) {
      return json(403, { error: "Registrations are currently closed. Please contact support." });
    }

    const bare = e164.replace(/^\+91/, "");

    // The number may have been registered (e.g. on the web, or by a retried
    // request) after the OTP was verified. Sign into that account instead of
    // creating a duplicate.
    const { data: profiles, error: profileQueryError } = await admin
      .from("profiles")
      .select("user_id, full_name")
      .or(`phone_e164.eq.${e164},phone.eq.${bare},phone.eq.${e164}`)
      .limit(10);
    if (profileQueryError) throw profileQueryError;

    let userId: string | undefined;
    let userEmail: string | undefined;
    let alreadyRegistered = false;
    for (const profile of profiles ?? []) {
      const { data: candidate } = await admin.auth.admin.getUserById(profile.user_id);
      if (candidate.user) {
        userId = candidate.user.id;
        userEmail = candidate.user.email ?? undefined;
        alreadyRegistered = !!profile.full_name?.trim();
        break;
      }
    }

    if (!userId) {
      const placeholderEmail = `phone-${bare}@phone.bansalkota.local`;
      const { data: created, error: createError } = await admin.auth.admin.createUser({
        email: placeholderEmail,
        email_confirm: true,
        user_metadata: { full_name: fullName, phone: e164, signup_method: "phone_otp" },
      });
      if (createError) {
        if (!createError.message.toLowerCase().includes("already been registered")) {
          throw createError;
        }

        // Recover an Auth user left behind by the old phone-OTP flow. The
        // Admin API has no get-by-email method, so page through users until
        // the deterministic placeholder address is found.
        for (let page = 1; page <= 100 && !userId; page++) {
          const { data: pageData, error: listError } = await admin.auth.admin
            .listUsers({ page, perPage: 1000 });
          if (listError) throw listError;
          const existing = pageData.users.find(
            (candidate) => candidate.email?.toLowerCase() === placeholderEmail,
          );
          if (existing) {
            userId = existing.id;
            break;
          }
          if (pageData.users.length < 1000) break;
        }
        if (!userId) throw createError;
      } else {
        userId = created.user!.id;
      }
      userEmail = placeholderEmail;
    }

    if (!userEmail) {
      const { data: existing } = await admin.auth.admin.getUserById(userId);
      userEmail = existing.user?.email ?? undefined;
    }
    if (!userEmail) throw new Error("The account has no sign-in email");

    // Never overwrite the details of a student who is already registered.
    const profileUpdate = alreadyRegistered
      ? { user_id: userId, phone_e164: e164, phone_verified: true }
      : {
        user_id: userId,
        full_name: fullName,
        class_level: classLevel,
        target_exam: targetExam,
        phone: bare,
        phone_e164: e164,
        phone_verified: true,
        onboarding_completed: true,
        updated_at: new Date().toISOString(),
      };
    const { error: profileUpdateError } = await admin
      .from("profiles")
      .upsert(profileUpdate, { onConflict: "user_id" });
    if (profileUpdateError) throw profileUpdateError;

    const { data: suspended, error: suspensionError } = await admin.rpc(
      "is_centre_suspended_for_user",
      { _user_id: userId },
    );
    if (suspensionError) throw suspensionError;
    if (suspended) {
      return json(403, { error: "This centre is currently suspended. Please contact Bansal HQ." });
    }

    const { data: link, error: linkError } = await admin.auth.admin.generateLink({
      type: "magiclink",
      email: userEmail,
    });
    if (linkError) throw linkError;
    const tokenHash = link.properties?.hashed_token;
    if (!tokenHash) throw new Error("Could not create a login session");

    const authClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { auth: { autoRefreshToken: false, persistSession: false } },
    );
    const { data: verified, error: verificationError } = await authClient.auth
      .verifyOtp({ token_hash: tokenHash, type: "magiclink" });
    if (verificationError) throw verificationError;
    if (!verified.session) throw new Error("Could not create a login session");

    return json(200, {
      ok: true,
      phone: e164,
      user_id: userId,
      already_registered: alreadyRegistered,
      access_token: verified.session.access_token,
      refresh_token: verified.session.refresh_token,
    });
  } catch (error) {
    console.error("mobile-complete-registration failed", error);
    return json(500, { error: (error as Error).message });
  }
});
