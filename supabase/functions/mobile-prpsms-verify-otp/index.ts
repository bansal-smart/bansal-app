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

function toE164(phone: string): string {
  const digits = phone.replace(/\D/g, "");
  if (digits.length === 10) return `+91${digits}`;
  if (digits.length === 12 && digits.startsWith("91")) return `+${digits}`;
  if (digits.length === 11 && digits.startsWith("0")) return `+91${digits.slice(1)}`;
  throw new Error("Invalid Indian phone number");
}

async function sha256Hex(input: string): Promise<string> {
  const bytes = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

const REGISTRATION_TOKEN_TTL_MS = 30 * 60_000;

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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { error: "Method not allowed" });

  try {
    const body = await req.json().catch(() => ({}));
    const phone = typeof body.phone === "string" ? body.phone : "";
    const otp = typeof body.otp === "string" ? body.otp : "";
    if (!phone || !/^\d{6}$/.test(otp)) {
      return json(400, { error: "Invalid input. Required: phone and 6-digit OTP" });
    }

    let e164: string;
    try {
      e164 = toE164(phone);
    } catch (error) {
      return json(400, { error: (error as Error).message });
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { autoRefreshToken: false, persistSession: false } },
    );

    const { data: records, error: otpQueryError } = await admin
      .from("phone_otps")
      .select("*")
      .eq("phone", e164)
      .in("purpose", ["login", "signup"])
      .is("verified_at", null)
      .order("created_at", { ascending: false })
      .limit(10);
    if (otpQueryError) throw otpQueryError;

    if (!records?.length) return json(400, { error: "No OTP requested" });

    const unexpired = records.filter(
      (candidate) => new Date(candidate.expires_at).getTime() >= Date.now(),
    );
    if (!unexpired.length) {
      return json(400, { error: "OTP expired" });
    }

    const eligible = unexpired.filter((candidate) => (candidate.attempts ?? 0) < 5);
    if (!eligible.length) {
      return json(429, { error: "Too many attempts" });
    }

    let matchedRecord: (typeof eligible)[number] | undefined;
    for (const candidate of eligible) {
      const hash = await sha256Hex(`${e164}:${candidate.purpose}:${otp}`);
      if (hash === candidate.otp_hash) {
        matchedRecord = candidate;
        break;
      }
    }

    if (!matchedRecord) {
      await Promise.all(
        eligible.map((candidate) =>
          admin
            .from("phone_otps")
            .update({ attempts: (candidate.attempts ?? 0) + 1 })
            .eq("id", candidate.id)
        ),
      );
      return json(400, { error: "Incorrect OTP" });
    }

    // A successful login consumes every outstanding code for this phone so
    // an older delayed SMS cannot be replayed later.
    await admin
      .from("phone_otps")
      .update({ verified_at: new Date().toISOString() })
      .eq("phone", e164)
      .in("purpose", ["login", "signup"])
      .is("verified_at", null);

    const bare = e164.replace(/^\+91/, "");
    const { data: profiles, error: profileQueryError } = await admin
      .from("profiles")
      .select("user_id, full_name, roll_number, centre_id, phone, parent_phone")
      .or(`phone_e164.eq.${e164},phone.eq.${bare},phone.eq.${e164},parent_phone.eq.${bare},parent_phone.eq.${e164},parent_phone_e164.eq.${e164}`)
      .limit(10);
    if (profileQueryError) throw profileQueryError;

    let userId: string | undefined;
    let userEmail: string | undefined;
    // Prefer a real student record over an incomplete account left behind by
    // the old phone-OTP flow. This also lets a parent use their recorded
    // number without creating a duplicate, blank profile.
    const rankedProfiles = [...(profiles ?? [])].sort((a, b) => {
      const score = (p: typeof a) =>
        (p.full_name?.trim() ? 4 : 0) + (p.roll_number?.trim() ? 2 : 0) + (p.centre_id ? 1 : 0);
      return score(b) - score(a);
    });
    for (const profile of rankedProfiles) {
      const { data: candidate } = await admin.auth.admin.getUserById(profile.user_id);
      if (candidate.user) {
        userId = candidate.user.id;
        userEmail = candidate.user.email ?? undefined;
        break;
      }
    }

    if (!userId) {
      const { data: settings } = await admin
        .from("platform_settings")
        .select("open_registrations")
        .eq("id", 1)
        .maybeSingle();
      if (settings && settings.open_registrations === false) {
        return json(403, { error: "Registrations are currently closed. Please contact support." });
      }

      // OTP verification is not student creation. The old implementation
      // created a phone-only Auth/profile pair here, which leaked into the
      // Students page as “Unnamed”. The registration flow must collect the
      // required details before it creates an active student.
      // The phone is now proven, so hand the app a short-lived signed token.
      // mobile-complete-registration accepts it together with the student's
      // details and only then creates the account.
      const expiresAt = Date.now() + REGISTRATION_TOKEN_TTL_MS;
      return json(200, {
        ok: true,
        purpose: "login",
        phone: e164,
        registration_required: true,
        registration_token: await hmacSha256Hex(
          Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
          `mobile-registration:${e164}:${expiresAt}`,
        ),
        registration_expires_at: expiresAt,
      });
    }

    if (!userEmail) {
      const { data: existing } = await admin.auth.admin.getUserById(userId);
      userEmail = existing.user?.email ?? undefined;
    }
    if (!userEmail) throw new Error("The account has no sign-in email");

    const { error: profileUpdateError } = await admin
      .from("profiles")
      .upsert(
        { user_id: userId, phone_e164: e164, phone_verified: true, phone: bare },
        { onConflict: "user_id" },
      );
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

    // Exchange the generated one-time link on the server. Doing this here
    // keeps OTP validation and session creation in one transaction-like flow
    // and avoids client SDK differences around hashed magic-link tokens.
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
      purpose: "login",
      phone: e164,
      user_id: userId,
      email: userEmail,
      access_token: verified.session.access_token,
      refresh_token: verified.session.refresh_token,
    });
  } catch (error) {
    console.error("mobile-prpsms-verify-otp failed", error);
    return json(500, { error: (error as Error).message });
  }
});
