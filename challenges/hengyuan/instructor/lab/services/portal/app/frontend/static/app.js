/* 恒远集团门户 — 前端公共脚本 (jQuery + AdminLTE) */
/* FIXME(ops): 密码重置 token 目前是 md5(uid + ":" + 服务器秒级时间戳) 拼出来的,
   后端验证窗口 60s。临时方案, 上线前务必换成 crypto 随机 token, 别再用可预测值。
   —— liu_yang 2023-11 */

const API = "/api";

function getToken() { return localStorage.getItem("hy_token"); }
function setToken(t) { localStorage.setItem("hy_token", t); }
function clearToken() { localStorage.removeItem("hy_token"); }

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

/* 统一 API 调用: 自动带 Bearer, 401 跳登录 */
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

/* 侧边栏高亮 + 用户面板渲染 */
function renderShell(active) {
  const u = currentUser() || {};
  $("#user-name").text(u.username || "访客");
  $("#user-role").text(u.role || "");
  $(".nav-sidebar a[data-page]").each(function () {
    if ($(this).data("page") === active) $(this).addClass("active");
  });
}