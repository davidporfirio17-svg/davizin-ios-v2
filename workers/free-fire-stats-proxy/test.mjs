import assert from "node:assert/strict";
import worker from "./src/index.js";

const cacheEntries = new Map();
let upstreamCalls = [];
let authSuccess = true;
let providerMode = "normal";

globalThis.caches = {
  default: {
    async match(request) {
      return cacheEntries.get(request.url)?.clone() ?? null;
    },
    async put(request, response) {
      cacheEntries.set(request.url, response.clone());
    },
  },
};

globalThis.fetch = async (input, init = {}) => {
  const target = input instanceof URL ? input.toString() : (typeof input === "string" ? input : input.url);
  const url = new URL(target);
  if (url.hostname === "dz.davidporfirio17.workers.dev") {
    assert.equal(init.method, "POST");
    const body = JSON.parse(init.body);
    assert.equal(body.key, "TEST-NYXEL-KEY");
    assert.equal(body.hwid, "TEST-HWID");
    assert.equal(body.app_build, "5");
    assert.equal(init.headers["X-DZ-Installation"], "install-test");
    return Response.json({ success: authSuccess, message: authSuccess ? "ok" : "invalid" });
  }

  const headers = new Headers(init.headers);
  const userAgent = headers.get("user-agent");
  assert.equal(userAgent, "NyxelExternal/1.5 (+https://nyxel-freefire-stats.davidporfirio17.workers.dev)");
  assert.ok(userAgent.length >= 10);
  assert.ok(!/python|requests|aiohttp|httpx|urllib|node-fetch|axios|got|undici|okhttp|java|curl|wget|bot|crawl|spider|scrapy|puppeteer|playwright|selenium|postman|insomnia|httpie/i.test(userAgent));
  upstreamCalls.push({ path: url.pathname, apiKey: headers.get("x-api-key") });
  if (providerMode === "non-json") return new Response("not-json", { status: 200 });
  if (providerMode === "rate-limit") {
    return new Response(JSON.stringify({ status: "error" }), { status: 429, headers: { "Retry-After": "60" } });
  }
  if (providerMode === "secret-leak") {
    return Response.json({ error: "reflected local-test-secret" }, { status: 500 });
  }
  if (providerMode === "stats-fails" && url.pathname.endsWith("/stats")) {
    return Response.json({ error: "Failed to get JWT token" }, { status: 500 });
  }
  if (url.pathname.endsWith("/info")) {
    return Response.json({ status: "success", data: { uid: "665951869", name: "TestPlayer", level: 65, rank: "Heroic" } });
  }
  if (url.pathname.endsWith("/stats")) {
    return Response.json({ status: "success", data: { uid: "665951869", solo: { kd: 6.97 }, duo: { kd: 7.78 }, squad: { kd: 7.02 } } });
  }
  throw new Error(`Unexpected fetch: ${url}`);
};

function makeRequest(overrides = {}) {
  const payload = {
    uid: "665951869",
    region: "ind",
    key: "test-nyxel-key",
    hwid: "TEST-HWID",
    app_build: "5",
    app_version: "1.5",
    installation_id: "install-test",
    ...overrides,
  };
  return new Request("https://nyxel-freefire-stats.davidporfirio17.workers.dev/lookup", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-DZ-Build": "5",
      "X-DZ-Installation": "install-test",
      "X-DZ-Session": "session-test",
    },
    body: JSON.stringify(payload),
  });
}

const env = { FREE_FIRE_API_KEY: "local-test-secret" };
const ctx = { waitUntil(promise) { promise.catch(() => {}); } };

const first = await worker.fetch(makeRequest(), env, ctx);
assert.equal(first.status, 200);
const result = await first.json();
assert.equal(result.success, true);
assert.equal(result.data.profile.name, "TestPlayer");
assert.equal(result.data.stats.solo.kd, 6.97);
assert.equal(upstreamCalls.length, 2);
assert.ok(upstreamCalls.every((call) => call.apiKey === "local-test-secret"));
assert.ok(!JSON.stringify(result).includes("local-test-secret"));

const cached = await worker.fetch(makeRequest(), env, ctx);
assert.equal(cached.status, 200);
assert.equal((await cached.json()).cached, true);
assert.equal(upstreamCalls.length, 2, "the cached lookup must not call the provider again");

for (const uid of ["64466722", "12345", "123456789012345"]) {
  const response = await worker.fetch(makeRequest({ uid }), env, ctx);
  assert.equal(response.status, 200, `UID ${uid.length} digits should be accepted`);
  assert.equal((await response.json()).success, true);
}
assert.equal(upstreamCalls.length, 8, "the 8-digit UID and documented 5/15-digit boundaries should be queried once");

for (const uid of ["1234", "1234567890123456"]) {
  const response = await worker.fetch(makeRequest({ uid }), env, ctx);
  assert.equal(response.status, 400, `UID ${uid.length} digits should be rejected`);
}
assert.equal(upstreamCalls.length, 8, "invalid-length UIDs must not call the provider");

const badRegion = await worker.fetch(makeRequest({ region: "mx" }), env, ctx);
assert.equal(badRegion.status, 400);

const callsBeforeUnauthorized = upstreamCalls.length;
authSuccess = false;
const unauthorized = await worker.fetch(makeRequest({ uid: "123456789" }), env, ctx);
assert.equal(unauthorized.status, 401);
assert.equal(upstreamCalls.length, callsBeforeUnauthorized);

authSuccess = true;
const unconfigured = await worker.fetch(makeRequest({ uid: "123456789" }), {}, ctx);
assert.equal(unconfigured.status, 503);

providerMode = "secret-leak";
const secretLeak = await worker.fetch(makeRequest({ uid: "66666666" }), env, ctx);
assert.equal(secretLeak.status, 500);
assert.ok(!JSON.stringify(await secretLeak.json()).includes("local-test-secret"));

providerMode = "stats-fails";
const partial = await worker.fetch(makeRequest({ uid: "77777777" }), env, ctx);
assert.equal(partial.status, 200);
const partialResult = await partial.json();
assert.equal(partialResult.success, true);
assert.ok(partialResult.data.profile);
assert.equal(partialResult.data.stats, null);
assert.ok(partialResult.data.warnings.includes("Estadísticas: Failed to get JWT token"));

providerMode = "non-json";
const beforeNonJson = upstreamCalls.length;
const nonJson = await worker.fetch(makeRequest({ uid: "99999999" }), env, ctx);
assert.equal(nonJson.status, 502);
assert.match((await nonJson.json()).message, /no JSON/i);
assert.equal(upstreamCalls.length, beforeNonJson + 2);

providerMode = "rate-limit";
const beforeRateLimit = upstreamCalls.length;
const limited = await worker.fetch(makeRequest({ uid: "88888888" }), env, ctx);
assert.equal(limited.status, 429);
assert.match((await limited.json()).message, /60 segundos/);
assert.equal(upstreamCalls.length, beforeRateLimit + 2);

console.log("Worker proxy tests passed.");
