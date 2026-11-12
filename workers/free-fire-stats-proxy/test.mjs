import assert from "node:assert/strict";
import worker from "./src/index.js";

const cacheEntries = new Map();
let upstreamCalls = [];
let authSuccess = true;

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

  upstreamCalls.push({ path: url.pathname, apiKey: new Headers(init.headers).get("x-api-key") });
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

console.log("Worker proxy tests passed.");
