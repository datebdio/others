const API = "http://127.0.0.1:17890";
const $ = id => document.getElementById(id);
let nodes = [];
let status = null;
let settings = {enabled: false, mode: "chatgpt"};
let editingId = "";
const latencies = new Map();

async function api(path, options = {}, timeout = 4000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeout);
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

function post(path, body, timeout) {
  return api(path, {method: "POST", headers: {"Content-Type": "application/json"}, body: JSON.stringify(body)}, timeout);
}

function toast(text = "", kind = "") {
  const el = $("toast");
  el.textContent = text;
  el.className = "toast" + (kind ? " " + kind : "");
}

function editorMessage(text = "", kind = "") {
  const el = $("editorMsg");
  el.textContent = text;
  el.className = "toast" + (kind ? " " + kind : "");
}

function closeMenus(except = null) {
  document.querySelectorAll(".node-menu.open").forEach(m => { if (m !== except) m.classList.remove("open"); });
}

function renderStatus() {
  const dot = $("dot");
  const master = $("master");
  master.checked = settings.enabled;
  if (!status) {
    dot.className = "dot bad";
    $("statusText").textContent = "本地程序未运行";
    $("statusDetail").textContent = "请运行程序目录中的 install.cmd";
    master.disabled = true;
    return;
  }
  master.disabled = false;
  if (!settings.enabled) {
    dot.className = "dot";
    $("statusText").textContent = status.selectedName ? `已关闭 · ${status.selectedName}` : "代理已关闭";
    $("statusDetail").textContent = status.nodeCount ? "打开右侧开关即可连接" : "请先添加一个节点";
  } else if (status.running) {
    dot.className = "dot ok";
    $("statusText").textContent = status.selectedName || "已连接";
    $("statusDetail").textContent = `Xray 已在后台运行 · SOCKS5 ${status.socks}`;
  } else {
    dot.className = "dot warn";
    $("statusText").textContent = "代理已启用，但 Xray 未运行";
    $("statusDetail").textContent = status.lastLog ? status.lastLog.trim().split("\n").slice(-1)[0] : "请关闭后重新启用代理";
  }
  $("footer").textContent = `本地程序 ${status.version} · ${status.nodeCount} 个节点`;
}

function renderNodes() {
  const list = $("nodeList");
  list.innerHTML = "";
  if (!nodes.length) {
    list.innerHTML = '<div class="empty">还没有节点，点击右上角“添加节点”</div>';
    return;
  }
  for (const node of nodes) {
    const row = document.createElement("div");
    row.className = "node-row" + (node.selected ? " selected" : "");
    row.dataset.id = node.id;
    const latency = latencies.has(node.id) ? `${latencies.get(node.id)} ms` : "";
    row.innerHTML = `
      <span class="radio"></span>
      <div class="node-main"><div class="node-name"></div><div class="node-meta"></div></div>
      <div class="latency">${latency}</div>
      <button class="more" title="节点操作">⋯</button>
      <div class="node-menu">
        <button data-action="use">${node.selected ? "当前节点" : "使用"}</button>
        <button data-action="ping">测速</button>
        <button data-action="edit">编辑</button>
        <button data-action="delete" class="danger">删除</button>
      </div>`;
    row.querySelector(".node-name").textContent = node.name;
    row.querySelector(".node-meta").textContent = node.type;
    const menu = row.querySelector(".node-menu");
    row.querySelector(".more").addEventListener("click", e => {
      e.stopPropagation();
      const willOpen = !menu.classList.contains("open");
      closeMenus();
      if (willOpen) menu.classList.add("open");
    });
    menu.addEventListener("click", async e => {
      e.stopPropagation();
      const action = e.target?.dataset?.action;
      if (!action) return;
      closeMenus();
      if (action === "use") await selectNode(node.id);
      if (action === "ping") await pingNode(node.id);
      if (action === "edit") openEditor(node);
      if (action === "delete") await deleteNode(node);
    });
    row.addEventListener("click", () => selectNode(node.id));
    list.appendChild(row);
  }
}

async function refreshData() {
  try {
    const [s, n] = await Promise.all([api("/status"), api("/nodes")]);
    status = s;
    nodes = n.nodes || [];
  } catch (e) {
    status = null;
    nodes = [];
  }
  renderStatus();
  renderNodes();
}

async function loadSettings() {
  const r = await chrome.runtime.sendMessage({type: "GET_SETTINGS"});
  if (r?.ok) settings = {enabled: Boolean(r.enabled), mode: r.mode || "chatgpt"};
  $("mode").value = settings.mode;
}

async function syncNow() {
  const r = await chrome.runtime.sendMessage({type: "SYNC_NOW"});
  if (!r?.ok && settings.enabled) toast(r?.error || "代理同步失败", "err");
}

async function selectNode(id) {
  const node = nodes.find(n => n.id === id);
  if (!node || node.selected) return;
  toast("正在切换节点…");
  try {
    await post("/nodes/select", {id}, 6000);
    toast(`已切换到 ${node.name}`, "ok");
  } catch (e) {
    toast(e.message || String(e), "err");
  }
  await refreshData();
}

async function pingNode(id) {
  const node = nodes.find(n => n.id === id);
  if (!node) return;
  toast(`正在测试 ${node.name}…`);
  try {
    const r = await post("/nodes/ping", {id}, 5000);
    latencies.set(id, r.latencyMs);
    toast(`${node.name}：TCP ${r.latencyMs} ms`, "ok");
  } catch (e) {
    latencies.delete(id);
    toast(`${node.name}：${e.message || String(e)}`, "err");
  }
  renderNodes();
}

async function deleteNode(node) {
  if (!confirm(`删除节点“${node.name}”？`)) return;
  toast("正在删除…");
  try {
    const r = await post("/nodes/delete", {id: node.id}, 6000);
    latencies.delete(node.id);
    if (r.enabled === false && settings.enabled) {
      const x = await chrome.runtime.sendMessage({type: "SET_ENABLED", enabled: false});
      if (x?.ok) settings.enabled = false;
    }
    toast("节点已删除", "ok");
  } catch (e) {
    toast(e.message || String(e), "err");
  }
  await refreshData();
}

function openEditor(node = null) {
  editingId = node?.id || "";
  $("editorTitle").textContent = node ? "编辑节点" : "添加节点";
  $("nodeName").value = node?.name || "";
  $("nodeSource").value = node?.source || "";
  editorMessage();
  $("editorOverlay").classList.add("open");
  setTimeout(() => node ? $("nodeName").focus() : $("nodeSource").focus(), 30);
}

function closeEditor() {
  $("editorOverlay").classList.remove("open");
  editingId = "";
  editorMessage();
}

async function saveEditor() {
  const source = $("nodeSource").value.trim();
  const name = $("nodeName").value.trim();
  if (!source) {
    editorMessage("请粘贴节点链接或 Xray JSON", "err");
    return;
  }
  $("saveNode").disabled = true;
  editorMessage("正在验证并保存…");
  try {
    const r = await post("/nodes/save", {id: editingId, name, source}, 7000);
    closeEditor();
    toast(`已保存：${r.node.name}`, "ok");
    await refreshData();
  } catch (e) {
    editorMessage(e.message || String(e), "err");
  } finally {
    $("saveNode").disabled = false;
  }
}

$("master").addEventListener("change", async e => {
  const desired = e.target.checked;
  e.target.disabled = true;
  toast(desired ? "正在启动代理…" : "正在停止代理…");
  try {
    const r = await chrome.runtime.sendMessage({type: "SET_ENABLED", enabled: desired});
    if (!r?.ok) throw new Error(r?.error || "操作失败");
    settings.enabled = desired;
    toast(desired ? "代理已启用" : "代理已关闭", "ok");
  } catch (err) {
    settings.enabled = !desired;
    e.target.checked = settings.enabled;
    toast(err.message || String(err), "err");
  } finally {
    e.target.disabled = false;
  }
  await refreshData();
});

$("mode").addEventListener("change", async e => {
  const old = settings.mode;
  const mode = e.target.value;
  try {
    const r = await chrome.runtime.sendMessage({type: "SET_MODE", mode});
    if (!r?.ok) throw new Error(r?.error || "设置失败");
    settings.mode = mode;
    toast("分流模式已更新", "ok");
  } catch (err) {
    e.target.value = old;
    toast(err.message || String(err), "err");
  }
});

$("addNode").addEventListener("click", () => openEditor());
$("cancelEdit").addEventListener("click", closeEditor);
$("saveNode").addEventListener("click", saveEditor);
$("editorOverlay").addEventListener("click", e => { if (e.target === $("editorOverlay")) closeEditor(); });
document.addEventListener("click", () => closeMenus());
document.addEventListener("keydown", e => { if (e.key === "Escape") { closeMenus(); closeEditor(); } });

(async function init() {
  await loadSettings();
  await syncNow();
  await refreshData();
})();
