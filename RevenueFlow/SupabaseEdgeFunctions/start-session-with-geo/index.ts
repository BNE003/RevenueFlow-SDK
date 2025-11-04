import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.1";

type SessionPayload = {
  device_id?: string;
  app_id?: string;
};

const supabaseUrl =
  Deno.env.get("SUPABASE_URL") ?? Deno.env.get("SERVICE_SUPABASE_URL");
const serviceRoleKey =
  Deno.env.get("SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SERVICE_ROLE_JWT");

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error(
    "Environment variables SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set"
  );
}

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false },
});

const getClientIp = (headers: Headers): string | null => {
  const forwarded = headers.get("x-forwarded-for");
  if (forwarded) {
    return forwarded.split(",")[0]?.trim() ?? null;
  }

  const realIp = headers.get("x-real-ip") ?? headers.get("cf-connecting-ip");
  return realIp?.trim() ?? null;
};

const fetchGeoInfo = async (ip: string | null) => {
  if (!ip) {
    return { countryCode: null as string | null, region: null as string | null };
  }

  try {
    const response = await fetch(`https://ipwho.is/${ip}`);
    if (!response.ok) {
      console.warn("ipwho.is lookup failed", await response.text());
      return { countryCode: null, region: null };
    }

    const data = await response.json();
    if (data.success === false) {
      console.warn("ipwho.is lookup unsuccessful", data);
      return { countryCode: null, region: null };
    }

    return {
      countryCode: data.country_code ?? null,
      region: data.region ?? data.city ?? null,
    };
  } catch (error) {
    console.warn("ipwho.is lookup threw", error);
    return { countryCode: null, region: null };
  }
};

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  try {
    const payload: SessionPayload = await req.json();

    if (!payload.device_id || !payload.app_id) {
      return new Response(
        JSON.stringify({ error: "device_id and app_id are required" }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    const clientIp = getClientIp(req.headers);
    const geo = await fetchGeoInfo(clientIp);
    const now = new Date().toISOString();

    const { data, error } = await supabase
      .from("active_sessions")
      .upsert(
        {
          device_id: payload.device_id,
          app_id: payload.app_id,
          last_heartbeat: now,
          session_started_at: now,
          country_code: geo.countryCode,
          region: geo.region,
        },
        { onConflict: "device_id,app_id" }
      )
      .select("id")
      .single();

    if (error) {
      console.error("Failed to upsert session", error);
      return new Response(
        JSON.stringify({ error: "Failed to upsert session" }),
        {
          status: 500,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    return new Response(
      JSON.stringify({
        session_id: data.id,
        country_code: geo.countryCode,
        region: geo.region,
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Unexpected error starting session", error);
    return new Response(JSON.stringify({ error: "Unexpected error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
