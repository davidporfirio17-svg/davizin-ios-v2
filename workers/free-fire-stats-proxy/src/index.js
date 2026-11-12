const FREE_FIRE_API = "https://developers.freefirecommunity.com/api/v1";
const FREE_FIRE_USER_AGENT = "NyxelExternal/1.5 (+https://nyxel-freefire-stats.davidporfirio17.workers.dev)";
const NYXEL_CHECK_URL = "https://dz.davidporfirio17.workers.dev/check";
const SUPPORTED_REGIONS = new Set(["sg", "ind", "br"]);
const CACHE_TTL_SECONDS = 300;
const ASSET_CACHE_TTL_SECONDS = 86400;

function json(data, status = 200, headers = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      ...headers,
    },
  });
}

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, X-DZ-Session, X-DZ-Build, X-DZ-Installation, Cache-Control",
    "Access-Control-Max-Age": "86400",
  };
}

function withCors(response) {
  const headers = new Headers(response.headers);
  for (const [name, value] of Object.entries(corsHeaders())) headers.set(name, value);
  return new Response(response.body, { status: response.status, statusText: response.statusText, headers });
}

async function parseJson(response) {
  try {
    return await response.json();
  } catch {
    return null;
  }
}

async function validateNyxelKey(payload, request, env) {
  const key = String(payload.key || "").trim().toUpperCase();
  const hwid = String(payload.hwid || "").trim();
  const appBuild = String(payload.app_build || request.headers.get("X-DZ-Build") || "").trim();
  const installation = String(payload.installation_id || request.headers.get("X-DZ-Installation") || "").trim();

  if (!key || !hwid || !appBuild || !installation) {
    return { ok: false, status: 401, message: "Inicia sesión en Nyxel para consultar estadísticas." };
  }

  const checkBody = {
    key,
    username: key,
    hwid,
    model: String(payload.model || ""),
    ios: String(payload.ios || ""),
    app_version: String(payload.app_version || ""),
    app_build: appBuild,
    installation_id: installation,
  };

  try {
    const headers = { "Content-Type": "application/json" };
    for (const name of ["X-DZ-Session", "X-DZ-Build", "X-DZ-Installation"]) {
      const value = request.headers.get(name);
      if (value) headers[name] = value;
    }
    const checkRequest = new Request(NYXEL_CHECK_URL, {
      method: "POST",
      headers,
      body: JSON.stringify(checkBody),
      signal: AbortSignal.timeout(10000),
    });
    const response = env.DZ_WORKER
      ? await env.DZ_WORKER.fetch(checkRequest)
      : await fetch(checkRequest);
    const result = await parseJson(response);
    if (!result || typeof result !== "object" || Array.isArray(result)) {
      const contentType = response.headers.get("content-type") || "sin Content-Type";
      return {
        ok: false,
        status: 502,
        message: `No se pudo leer la respuesta de dz/check (HTTP ${response.status}; ${contentType}).`,
      };
    }
    if (!response.ok || result?.success !== true) {
      return {
        ok: false,
        status: 401,
        message: String(result.message || `dz/check rechazó la validación (HTTP ${response.status}).`),
      };
    }
    return { ok: true };
  } catch {
    return { ok: false, status: 503, message: "No se pudo validar la sesión de Nyxel." };
  }
}

async function fetchFreeFire(endpoint, uid, region, apiKey) {
  try {
    const url = new URL(`${FREE_FIRE_API}/${endpoint}`);
    url.searchParams.set("uid", uid);
    url.searchParams.set("region", region);
    const response = await fetch(url, {
      method: "GET",
      headers: {
        "x-api-key": apiKey,
        "User-Agent": FREE_FIRE_USER_AGENT,
        Accept: "application/json",
      },
      signal: AbortSignal.timeout(12000),
    });
    const rawBody = await response.text();
    let body = null;
    try {
      body = rawBody ? JSON.parse(rawBody) : null;
    } catch {
      body = null;
    }
    const retryAfter = response.headers.get("retry-after");
    if (!response.ok || body?.status === "error") {
      const status = response.status >= 400 ? response.status : 502;
      const rawMessage = rawBody.replaceAll(apiKey, "[redacted]").trim().slice(0, 180);
      let message = String(body?.message || body?.error || rawMessage || `Error ${status} del proveedor.`)
        .replaceAll(apiKey, "[redacted]");
      if (status === 429) {
        const retryHint = retryAfter
          ? (/^\d+$/.test(retryAfter) ? ` Inténtalo en ${retryAfter} segundos.` : ` Reintenta después de ${retryAfter}.`)
          : " Espera antes de volver a intentarlo.";
        message = `El proveedor limitó las consultas.${retryHint}`;
      }
      return { ok: false, status, message };
    }
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      return { ok: false, status: 502, message: "El proveedor devolvió una respuesta no JSON o vacía." };
    }
    return { ok: true, data: body?.data ?? body };
  } catch {
    return { ok: false, status: 502, message: "No hubo respuesta del proveedor de Free Fire." };
  }
}

async function fetchFreeFireAsset(itemID, apiKey) {
  try {
    const url = new URL(`${FREE_FIRE_API}/image`);
    url.searchParams.set("itemID", itemID);
    const response = await fetch(url, {
      method: "GET",
      headers: {
        "x-api-key": apiKey,
        "User-Agent": FREE_FIRE_USER_AGENT,
        Accept: "image/png,image/jpeg",
      },
      signal: AbortSignal.timeout(12000),
    });
    if (!response.ok) {
      const rawMessage = (await response.text()).replaceAll(apiKey, "[redacted]").trim();
      let message = "No se encontró la imagen del asset.";
      try {
        const body = JSON.parse(rawMessage);
        message = String(body.message || body.error || message).replaceAll(apiKey, "[redacted]");
      } catch {
        if (rawMessage) message = rawMessage.slice(0, 160);
      }
      return { ok: false, status: response.status, message };
    }
    const contentType = (response.headers.get("content-type") || "").split(";")[0].trim().toLowerCase();
    if (contentType !== "image/png" && contentType !== "image/jpeg") {
      return { ok: false, status: 502, message: "El proveedor no devolvió una imagen PNG o JPEG." };
    }
    const bytes = await response.arrayBuffer();
    if (!bytes.byteLength) return { ok: false, status: 502, message: "El proveedor devolvió una imagen vacía." };
    return { ok: true, bytes, contentType };
  } catch {
    return { ok: false, status: 502, message: "No se pudo descargar la imagen del proveedor." };
  }
}

async function handleAssetRequest(payload, request, env, ctx) {
  const itemID = String(payload.item_id || payload.itemID || "").trim();
  if (!/^\d{5,15}$/.test(itemID)) {
    return json({ success: false, code: "INVALID_ASSET_ID", message: "El identificador de imagen no es válido." }, 400, corsHeaders());
  }

  const auth = await validateNyxelKey(payload, request, env);
  if (!auth.ok) return json({ success: false, code: "NYXEL_AUTH", message: auth.message }, auth.status, corsHeaders());

  const cacheKey = new Request(`https://ff-assets-cache.invalid/image?itemID=${encodeURIComponent(itemID)}`);
  let cache = null;
  try {
    cache = caches.default;
    const cached = await cache.match(cacheKey);
    if (cached) return withCors(new Response(cached.body, { status: cached.status, headers: cached.headers }));
  } catch {
    cache = null;
  }

  const asset = await fetchFreeFireAsset(itemID, env.FREE_FIRE_API_KEY);
  if (!asset.ok) {
    return json({ success: false, code: "ASSET_ERROR", message: asset.message }, asset.status >= 400 && asset.status < 600 ? asset.status : 502, corsHeaders());
  }

  const cacheResponse = new Response(asset.bytes, {
    headers: {
      "Content-Type": asset.contentType,
      "Cache-Control": `public, max-age=${ASSET_CACHE_TTL_SECONDS}`,
      "X-Content-Type-Options": "nosniff",
    },
  });
  if (cache) ctx.waitUntil(cache.put(cacheKey, cacheResponse.clone()).catch(() => {}));
  const response = new Response(asset.bytes, {
    headers: {
      "Content-Type": asset.contentType,
      "Cache-Control": `private, max-age=${ASSET_CACHE_TTL_SECONDS}`,
      "X-Content-Type-Options": "nosniff",
    },
  });
  return withCors(response);
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }
    if (request.method === "GET" && url.pathname === "/health") {
      return json({ ok: true, apiKeyConfigured: Boolean(env.FREE_FIRE_API_KEY) });
    }
    if (request.method !== "POST" || !["/lookup", "/asset"].includes(url.pathname)) {
      return json({ success: false, message: "Ruta no encontrada." }, 404);
    }
    if (!env.FREE_FIRE_API_KEY) {
      return json({ success: false, code: "NOT_CONFIGURED", message: "El servicio de Free Fire todavía no está configurado." }, 503, corsHeaders());
    }

    let payload;
    try {
      payload = await request.json();
    } catch {
      return json({ success: false, message: "Solicitud JSON inválida." }, 400, corsHeaders());
    }

    if (url.pathname === "/asset") {
      return handleAssetRequest(payload, request, env, ctx);
    }

    const uid = String(payload.uid || "").trim();
    const region = String(payload.region || "").trim().toLowerCase();
    if (!/^\d{5,15}$/.test(uid)) {
      return json({ success: false, message: "El UID debe tener entre 5 y 15 dígitos." }, 400, corsHeaders());
    }
    if (!SUPPORTED_REGIONS.has(region)) {
      return json({ success: false, message: "La documentación de esta API solo declara sg, ind y br." }, 400, corsHeaders());
    }

    const auth = await validateNyxelKey(payload, request, env);
    if (!auth.ok) {
      return json({ success: false, code: "NYXEL_AUTH", message: auth.message }, auth.status, corsHeaders());
    }

    const cacheKey = new Request(`https://ff-stats-cache.invalid/lookup?region=${encodeURIComponent(region)}&uid=${encodeURIComponent(uid)}`);
    let cache;
    let cached;
    try {
      cache = caches.default;
      cached = await cache.match(cacheKey);
    } catch {
      cache = null;
      cached = null;
    }
    if (cached) {
      const data = await parseJson(cached);
      return json({ success: true, data, cached: true }, 200, corsHeaders());
    }

    const [profile, stats] = await Promise.all([
      fetchFreeFire("info", uid, region, env.FREE_FIRE_API_KEY),
      fetchFreeFire("stats", uid, region, env.FREE_FIRE_API_KEY),
    ]);
    if (!profile.ok && !stats.ok) {
      const providerStatus = profile.status || stats.status || 502;
      return json({ success: false, code: "PROVIDER_ERROR", message: profile.message || stats.message || "No se pudieron obtener los datos." }, providerStatus >= 400 && providerStatus < 600 ? providerStatus : 502, corsHeaders());
    }

    const data = {
      profile: profile.ok ? profile.data : null,
      stats: stats.ok ? stats.data : null,
      warnings: [!profile.ok ? `Perfil: ${profile.message}` : null, !stats.ok ? `Estadísticas: ${stats.message}` : null].filter(Boolean),
    };
    const cacheResponse = new Response(JSON.stringify(data), {
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": `public, max-age=${CACHE_TTL_SECONDS}`,
      },
    });
    if (cache) ctx.waitUntil(cache.put(cacheKey, cacheResponse).catch(() => {}));
    return json({ success: true, data, cached: false }, 200, corsHeaders());
  },
};
