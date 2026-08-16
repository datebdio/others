const API = "http://127.0.0.1:17890";
const SOCKS = "SOCKS5 127.0.0.1:10808";

const OPENAI_DOMAINS = [
  "chatgpt.com", "chat.openai.com", "openai.com", "auth.openai.com", "auth0.openai.com",
  "oaistatic.com", "oaiusercontent.com", "oaistatsig.com", "openaimerge.com", "ws.chatgpt.com",
  "setup.auth.openai.com", "setup.workos.com", "cdn.workos.com", "forwarder.workos.com",
  "images.workoscdn.com", "workos.imgix.net", "challenges.cloudflare.com",
  "intercom.io", "intercomcdn.com", "js.intercomcdn.com", "js.stripe.com",
  "browser-intake-datadoghq.com", "ingest.sentry.io",
  "accounts.google.com", "gstatic.com", "googleusercontent.com",
  "login.microsoftonline.com", "login.live.com", "appleid.apple.com"
];

const AI_EXTRA_DOMAINS = [
  "claude.ai", "anthropic.com", "perplexity.ai", "grok.com", "x.ai",
  "gemini.google.com", "generativelanguage.googleapis.com", "aistudio.google.com",
  "googleapis.com", "copilot.microsoft.com"
];

async function api(path, options = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 3500);
  try {
    const res = await fetch(API + path, {...options, signal: controller.signal});
    const text = await res.text();
    let data = {};
    try { data = JSON.parse(text); } catch { data = {error: text}; }
    if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);
    return data;
  } finally {
    clearTimeout(timer);
  }
}

function pacFor(domains, globalMode) {
  const list = JSON.stringify(domains);
  return `
function FindProxyForURL(url, host) {
  host = host.toLowerCase();
  if (isPlainHostName(host) || host === "localhost" || host === "127.0.0.1" || host === "::1") return "DIRECT";
  if (shExpMatch(host, "10.*") || shExpMatch(host, "192.168.*") ||
      shExpMatch(host, "172.16.*") || shExpMatch(host, "172.17.*") ||
      shExpMatch(host, "172.18.*") || shExpMatch(host, "172.19.*") ||
      shExpMatch(host, "172.2?.*") || shExpMatch(host, "172.3[01].*")) return "DIRECT";
  var domains = ${list};
  for (var i = 0; i < domains.length; i++) {
    var d = domains[i];
    if (host === d || dnsDomainIs(host, "." + d)) return "${SOCKS}";
  }
  return ${globalMode ? `"${SOCKS}"` : '"DIRECT"'};
}`;
}

async function applyProxy(mode) {
  const domains = mode === "ai" ? [...OPENAI_DOMAINS, ...AI_EXTRA_DOMAINS] : OPENAI_DOMAINS;
  const data = pacFor(domains, mode === "global");
  await chrome.proxy.settings.set({
    value: {mode: "pac_script", pacScript: {data}},
    scope: "regular"
  });
}

async function clearProxy() {
  await chrome.proxy.settings.clear({scope: "regular"});
}

async function updateBadge(enabled, mode) {
  const labels = {chatgpt: "GPT", ai: "AI", global: "ALL"};
  await chrome.action.setBadgeText({text: enabled ? (labels[mode] || "ON") : ""});
}

async function getSettings() {
  const saved = await chrome.storage.local.get(["enabled", "mode"]);
  return {enabled: saved.enabled === true, mode: saved.mode || "chatgpt"};
}

async function setEnabled(enabled) {
  const settings = await getSettings();
  if (enabled) {
    await api("/proxy", {method: "POST", headers: {"Content-Type": "application/json"}, body: JSON.stringify({enabled: true})});
    await applyProxy(settings.mode);
  } else {
    await clearProxy();
    try {
      await api("/proxy", {method: "POST", headers: {"Content-Type": "application/json"}, body: JSON.stringify({enabled: false})});
    } catch (_) {}
  }
  await chrome.storage.local.set({enabled});
  await updateBadge(enabled, settings.mode);
  return {enabled, mode: settings.mode};
}

async function setMode(mode) {
  if (!["chatgpt", "ai", "global"].includes(mode)) throw new Error("invalid mode");
  const settings = await getSettings();
  await chrome.storage.local.set({mode});
  if (settings.enabled) await applyProxy(mode);
  await updateBadge(settings.enabled, mode);
  return {enabled: settings.enabled, mode};
}

async function syncNow() {
  const settings = await getSettings();
  if (!settings.enabled) {
    await clearProxy();
    try {
      await api("/proxy", {method: "POST", headers: {"Content-Type": "application/json"}, body: JSON.stringify({enabled: false})});
    } catch (_) {}
    await updateBadge(false, settings.mode);
    return settings;
  }
  try {
    await api("/proxy", {method: "POST", headers: {"Content-Type": "application/json"}, body: JSON.stringify({enabled: true})});
    await applyProxy(settings.mode);
    await updateBadge(true, settings.mode);
    return settings;
  } catch (e) {
    await clearProxy();
    await updateBadge(false, settings.mode);
    throw e;
  }
}

chrome.runtime.onInstalled.addListener(async () => {
  const saved = await chrome.storage.local.get(["enabled", "mode"]);
  if (saved.mode === undefined) await chrome.storage.local.set({mode: "chatgpt"});
  if (saved.enabled === undefined) await chrome.storage.local.set({enabled: false});
  try { await syncNow(); } catch (_) {}
});

chrome.runtime.onStartup.addListener(async () => {
  try { await syncNow(); } catch (_) {}
});

chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  const run = async () => {
    if (msg?.type === "GET_SETTINGS") return {ok: true, ...(await getSettings())};
    if (msg?.type === "SET_ENABLED") return {ok: true, ...(await setEnabled(Boolean(msg.enabled)))};
    if (msg?.type === "SET_MODE") return {ok: true, ...(await setMode(msg.mode))};
    if (msg?.type === "SYNC_NOW") return {ok: true, ...(await syncNow())};
    return {ok: false, error: "unknown message"};
  };
  run().then(sendResponse).catch(e => sendResponse({ok: false, error: e?.message || String(e)}));
  return true;
});
