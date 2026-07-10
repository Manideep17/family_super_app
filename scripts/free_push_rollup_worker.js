/**
 * Cloudflare Worker template (free tier) for:
 * 1) OneSignal push dispatch bridge
 * 2) Optional weekly rollup trigger endpoint
 *
 * Environment variables:
 * - WORKER_KEY
 * - ONESIGNAL_REST_API_KEY
 */

export default {
  async fetch(request, env) {
    if (request.method === "POST" && new URL(request.url).pathname === "/push") {
      return handlePush(request, env);
    }
    return new Response("ok", { status: 200 });
  },
  async scheduled(event, env, ctx) {
    // Optional weekly hook: call your rollup endpoint or Firestore-backed job.
    // Kept as a template since most projects use Firestore REST + service account.
    console.log("Scheduled trigger fired", event.scheduledTime);
  },
};

async function handlePush(request, env) {
  const workerKey = request.headers.get("x-worker-key");
  if (!workerKey || workerKey !== env.WORKER_KEY) {
    return json({ error: "unauthorized" }, 401);
  }

  let body;
  try {
    body = await request.json();
  } catch (_) {
    return json({ error: "invalid-json" }, 400);
  }

  const appId = String(body.appId || "");
  const subscriptionIds = Array.isArray(body.subscriptionIds)
    ? body.subscriptionIds.map((x) => String(x)).filter(Boolean)
    : [];
  if (!appId || subscriptionIds.length === 0) {
    return json({ error: "missing-appId-or-subscriptions" }, 400);
  }

  const payload = {
    app_id: appId,
    include_subscription_ids: subscriptionIds,
    headings: { en: String(body.title || "Family update") },
    contents: { en: String(body.body || "New activity in your family app") },
    data: body.data || {},
  };

  const res = await fetch("https://api.onesignal.com/notifications", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      Authorization: `Key ${env.ONESIGNAL_REST_API_KEY}`,
    },
    body: JSON.stringify(payload),
  });

  const text = await res.text();
  if (!res.ok) {
    return json({ ok: false, status: res.status, body: text }, 502);
  }
  return json({ ok: true, response: tryJson(text) }, 200);
}

function tryJson(text) {
  try {
    return JSON.parse(text);
  } catch (_) {
    return text;
  }
}

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "content-type": "application/json" },
  });
}
