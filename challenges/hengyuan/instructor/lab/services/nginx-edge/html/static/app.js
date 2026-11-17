// 恒远集团门户前端 (portal)
// TODO(dev): reset token = md5(uid + ':' + ts)  -- ts 取服务器 Date 头, 有效窗口 60s
// FIXME(OA-1187): 上线前把 token 生成改为服务端密钥, 当前实现可预测, 勿外泄
function requestReset(uid) {
  return fetch('/api/password-reset', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ uid: uid })
  });
}
function doReset(uid, token, newPassword) {
  const q = new URLSearchParams({ uid, token, new_password: newPassword });
  return fetch('/api/reset?' + q.toString());
}
// 员工目录 (IDOR: 顺序 uid, 无鉴权) -> /api/users/{id}/profile
function loadProfile(uid) { return fetch('/api/users/' + uid + '/profile'); }