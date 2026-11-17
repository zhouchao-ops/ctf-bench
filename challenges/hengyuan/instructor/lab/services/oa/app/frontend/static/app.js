/* 恒远集团 OA — 前端公共脚本 (jQuery + AdminLTE) */
const API = "/api";

function getToken() { return localStorage.getItem("oa_token"); }
function setToken(t) { localStorage.setItem("oa_token", t); }
function clearToken() { localStorage.removeItem("oa_token"); }

function jwtPayload(t) {
  try {
    const p = t.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    return JSON.parse(decodeURIComponent(escape(atob(p))));
  } catch (e) { return null; }
}

function currentUser() {
  const t = getToken();
  return t ? jwtPayload(t) : null;
}

function requireAuth() {
  if (!getToken()) { location.href = "/index.html"; }
}

function logout() { clearToken(); location.href = "/index.html"; }

async function api(path, opts = {}) {
  const headers = Object.assign({ "Content-Type": "application/json" }, opts.headers || {});
  const t = getToken();
  if (t) headers["Authorization"] = "Bearer " + t;
  const resp = await fetch(API + path, Object.assign({}, opts, { headers }));
  if (resp.status === 401) { clearToken(); location.href = "/index.html"; throw new Error("未登录"); }
  const data = await resp.json().catch(() => ({}));
  if (!resp.ok) throw new Error(data.detail || ("请求失败 " + resp.status));
  return data;
}

function esc(s) {
  return String(s == null ? "" : s).replace(/[&<>"']/g, c =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
}

const STEP_LABEL = { dept_manager: "部门经理", finance_clerk: "财务专员", finance_director: "财务总监" };
const STATUS_LABEL = { pending: "审批中", approved: "已通过", withdrawn: "已撤回" };

function statusBadge(s) {
  const map = { pending: "warning", approved: "success", withdrawn: "secondary" };
  return '<span class="badge badge-' + (map[s] || "info") + '">' + esc(STATUS_LABEL[s] || s) + '</span>';
}

function renderShell(active) {
  const u = currentUser() || {};
  $("#user-name").text(u.username || "访客");
  $("#user-role").text((u.dept || "") + (u.role ? " · " + u.role : ""));
  $(".nav-sidebar a[data-page]").each(function () {
    if ($(this).data("page") === active) $(this).addClass("active");
  });
}