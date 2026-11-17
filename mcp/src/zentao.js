// ZenTao chat (Xuanxuan / xxd server): headless client speaking the desktop client's WebSocket protocol.
// Protocol notes (from client 9.x): POST <server>/serverInfo -> { token, chatPort, enableClientAES, ... };
// then WebSocket wss://host:chatPort/ws, binary frames of JSON, optionally AES-256-CBC (key = token, iv = token[0..16]).
import crypto from 'node:crypto';
import http from 'node:http';
import https from 'node:https';
import WebSocket from 'ws';

const CLIENT_VERSION = '9.2.2';
const DEVICE = 'desktop';
const REQUEST_TIMEOUT_MS = 20000;
const PING_EVERY_MS = 30000;

const md5 = (s) => crypto.createHash('md5').update(s, 'utf8').digest('hex');
const iso = (sec) => (sec ? new Date(sec * 1000).toISOString() : null);

function config() {
  const server = process.env.ZENTAO_SERVER;
  const account = process.env.ZENTAO_ACCOUNT;
  const password = process.env.ZENTAO_PASSWORD;
  if (!server || !account || !password) {
    throw new Error('ZenTao is not configured. Set ZENTAO_SERVER (e.g. https://zentao.example.com:11443), ZENTAO_ACCOUNT and ZENTAO_PASSWORD in the MCP server env.');
  }
  const url = new URL(/^[a-z]+:\/\//i.test(server) ? server : `https://${server}`);
  if (!url.port) url.port = '11443';
  const serverName = decodeURIComponent(url.username) || url.pathname.replace(/^\/+|\/+$/g, '');
  url.username = '';
  url.password = '';
  return {
    url,
    serverName,
    account,
    // The client sends md5(password); a 32-char value is assumed to be that hash already.
    passwordKey: /^[a-f0-9]{32}$/i.test(password) ? password.toLowerCase() : md5(password),
    insecureTls: /^(1|true|yes)$/i.test(process.env.ZENTAO_INSECURE_TLS ?? ''),
  };
}

function postForm(url, body, insecureTls) {
  const mod = url.protocol === 'https:' ? https : http;
  return new Promise((resolve, reject) => {
    const req = mod.request(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8', 'Content-Length': Buffer.byteLength(body) },
      rejectUnauthorized: !insecureTls,
      timeout: REQUEST_TIMEOUT_MS,
    }, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => resolve({ status: res.statusCode, text: Buffer.concat(chunks).toString('utf8') }));
    });
    req.on('timeout', () => req.destroy(new Error('serverInfo request timed out')));
    req.on('error', reject);
    req.end(body);
  });
}

function tlsHint(e) {
  const msg = String(e?.message ?? e);
  return /certificate|self.signed|CERT_/i.test(msg)
    ? `${msg} — the server uses an untrusted TLS certificate; set ZENTAO_INSECURE_TLS=1 if you trust it.`
    : msg;
}

async function fetchServerInfo(cfg) {
  const body = 'data=' + JSON.stringify({
    method: 'sysgetserverinfo',
    params: [cfg.serverName, cfg.account, cfg.passwordKey, ''],
    version: CLIENT_VERSION,
    device: DEVICE,
    lang: 'en',
  });
  const root = cfg.url.pathname.replace(/\/+$/, '');
  const candidates = [new URL(`${root}/serverInfo`, cfg.url)];
  const other = new URL(candidates[0]);
  other.protocol = cfg.url.protocol === 'https:' ? 'http:' : 'https:';
  candidates.push(other);

  let lastErr;
  for (const u of candidates) {
    try {
      const res = await postForm(u, body, cfg.insecureTls);
      const json = JSON.parse(res.text);
      const info = json.data ?? json;
      if (!info?.token) throw new Error(json.message || `serverInfo returned no token (HTTP ${res.status}) — wrong account/password?`);
      return { ...info, infoUrl: u };
    } catch (e) {
      lastErr = e;
    }
  }
  throw new Error(`ZenTao serverInfo failed: ${tlsHint(lastErr)}`);
}

class XuanClient {
  constructor(cfg) {
    this.cfg = cfg;
    this.pending = new Map(); // rid -> { method, resolve, reject, timer }
    this.users = new Map();
    this.chats = null;
  }

  async connect() {
    const cfg = this.cfg;
    const info = await fetchServerInfo(cfg);
    if (Array.isArray(info.apiScheme) || (info.apiScheme && typeof info.apiScheme === 'object')) {
      // The compact "apiScheme" array encoding is not implemented; plain JSON works on servers that don't send one.
      this.schemeWarning = 'Server advertised apiScheme encoding; this client speaks plain JSON only.';
    }
    this.token = info.token;
    this.aes = !!info.enableClientAES;
    this.serverTimeOffset = info.serverTime ? (info.serverTime < 1e10 ? info.serverTime * 1000 : info.serverTime) - Date.now() : 0;

    let wsUrl = info.socketUrl;
    if (!wsUrl) {
      const u = new URL(info.infoUrl);
      u.protocol = u.protocol === 'https:' ? 'wss:' : 'ws:';
      u.pathname = '/ws';
      if (info.chatPort) u.port = String(info.chatPort);
      wsUrl = u.toString();
    }

    const ws = new WebSocket(wsUrl, { rejectUnauthorized: !cfg.insecureTls });
    ws.binaryType = 'nodebuffer';
    this.ws = ws;
    await new Promise((resolve, reject) => {
      ws.once('open', resolve);
      ws.once('error', (e) => reject(new Error(`ZenTao socket ${wsUrl}: ${tlsHint(e)}`)));
    });
    ws.on('message', (data) => this.onData(data));
    ws.on('close', () => this.onClose(new Error('ZenTao socket closed')));
    ws.on('error', () => {});
    this.lastReceived = Date.now();
    this.pingTimer = setInterval(() => {
      if (Date.now() - this.lastReceived >= 60000) this.send({ method: 'ping' });
    }, PING_EVERY_MS);
    this.pingTimer.unref();

    // Prefer the password key; fall back to the server-issued auth token key (same derivation as the client).
    const keys = [cfg.passwordKey];
    if (info.authToken) keys.push(this.tokenKey(info.authToken, info.authTokenAuthWindow || 20));
    let lastErr;
    for (const key of keys) {
      try {
        const user = await this.request('userLogin', [cfg.serverName, cfg.account, key, { status: 'online', simple: false }], `login_${DEVICE}_${cfg.account}`);
        this.me = user;
        if (user?.id) this.users.set(Number(user.id), user);
        return;
      } catch (e) {
        lastErr = e;
      }
    }
    this.close();
    throw new Error(`ZenTao login failed: ${lastErr?.message ?? lastErr}`);
  }

  tokenKey(authToken, window) {
    let k = authToken;
    if (k.length === 64) k = md5(`${this.cfg.account}${k}${Math.round((Date.now() + this.serverTimeOffset) / 1000 / window)}`);
    else if (k.length >= 32) k = k.substring(0, 32);
    return `${k}${md5(k)}`;
  }

  encode(obj) {
    const json = JSON.stringify(obj);
    if (!this.aes) return Buffer.from(json, 'utf8');
    const c = crypto.createCipheriv('aes-256-cbc', Buffer.from(this.token, 'utf8'), Buffer.from(this.token.substring(0, 16), 'utf8'));
    return Buffer.concat([c.update(json, 'utf8'), c.final()]);
  }

  decode(buf) {
    try {
      return JSON.parse(buf.toString('utf8'));
    } catch {
      const d = crypto.createDecipheriv('aes-256-cbc', Buffer.from(this.token, 'utf8'), Buffer.from(this.token.substring(0, 16), 'utf8'));
      return JSON.parse(Buffer.concat([d.update(buf), d.final()]).toString('utf8'));
    }
  }

  send(msg) {
    const env = { version: CLIENT_VERSION, device: DEVICE, lang: 'en', ...msg, method: msg.method.toLowerCase() };
    if (this.me?.id) env.userID = this.me.id;
    this.ws.send(this.encode(env), { binary: true });
  }

  request(method, params, rid = crypto.randomUUID()) {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(rid);
        reject(new Error(`ZenTao ${method} timed out`));
      }, REQUEST_TIMEOUT_MS);
      this.pending.set(rid, { method: method.toLowerCase(), resolve, reject, timer });
      try {
        this.send(params === undefined ? { method, rid } : { method, params, rid });
      } catch (e) {
        clearTimeout(timer);
        this.pending.delete(rid);
        reject(e);
      }
    });
  }

  onData(raw) {
    this.lastReceived = Date.now();
    let msg;
    try {
      msg = this.decode(raw);
    } catch {
      return;
    }
    for (const m of Array.isArray(msg) && typeof msg[0] === 'object' ? msg : [msg]) this.dispatch(m);
  }

  dispatch(m) {
    if (!m || typeof m !== 'object' || Array.isArray(m)) return;
    const method = String(m.method ?? '').toLowerCase();
    if (method === 'usergetlist' && m.data) for (const u of Object.values(m.data)) if (u?.id) this.users.set(Number(u.id), u);
    if (method === 'userkickoff') this.onClose(new Error(`ZenTao kicked this session off: ${m.message ?? m.reason ?? ''}`));

    // Match by rid; if the server omits it, settle the oldest pending request of the same method.
    let rid = m.rid && this.pending.has(m.rid) ? m.rid : null;
    if (!rid) for (const [k, p] of this.pending) if (p.method === method) { rid = k; break; }
    if (!rid) return;
    const p = this.pending.get(rid);
    this.pending.delete(rid);
    clearTimeout(p.timer);
    if (m.result && m.result !== 'success') p.reject(new Error(`ZenTao ${method}: ${m.message || m.result}`));
    else p.resolve(m.data);
  }

  onClose(err) {
    clearInterval(this.pingTimer);
    for (const p of this.pending.values()) {
      clearTimeout(p.timer);
      p.reject(err);
    }
    this.pending.clear();
    this.closed = true;
    try { this.ws?.terminate(); } catch {}
  }

  close() {
    this.onClose(new Error('closed'));
  }
}

let clientPromise;
async function client() {
  if (clientPromise) {
    const c = await clientPromise.catch(() => null);
    if (c && !c.closed) return c;
  }
  clientPromise = (async () => {
    const c = new XuanClient(config());
    await c.connect();
    return c;
  })();
  return clientPromise;
}

async function loadUsers(c, ids) {
  const missing = [...new Set(ids.map(Number))].filter((id) => id && !c.users.has(id));
  if (!missing.length) return;
  const data = await c.request('userGetList', [missing]).catch(() => null);
  if (data) for (const u of Object.values(data)) if (u?.id) c.users.set(Number(u.id), u);
}

const userName = (c, id) => {
  const u = c.users.get(Number(id));
  return u ? u.realname || u.account : `user#${id}`;
};

async function loadChats(c, refresh = false) {
  if (!c.chats || refresh) {
    const data = await c.request('chatGetList');
    c.chats = Object.values(data ?? {});
    await loadUsers(c, c.chats.flatMap((ch) => (Array.isArray(ch.members) ? ch.members : [])));
  }
  return c.chats;
}

function chatName(c, ch) {
  if (ch.name) return ch.name;
  if (ch.type === 'one2one') {
    const other = String(ch.gid).split('&').find((id) => Number(id) !== Number(c.me?.id));
    return userName(c, other ?? c.me?.id);
  }
  return ch.gid;
}

async function resolveChat(c, conversation) {
  const chats = await loadChats(c);
  const q = String(conversation).toLowerCase();
  const ch = chats.find((x) => String(x.gid) === conversation)
    ?? chats.find((x) => chatName(c, x).toLowerCase() === q)
    ?? chats.find((x) => chatName(c, x).toLowerCase().includes(q));
  if (!ch) throw new Error(`ZenTao chat "${conversation}" not found. Use list_conversations to see names / gids.`);
  return ch;
}

export function messageText(m) {
  const parse = () => { try { return JSON.parse(m.content); } catch { return {}; } };
  switch (m.contentType) {
    case 'image': return `[image] ${parse().name ?? ''}`.trim();
    case 'file': { const f = parse(); return `[file] ${f.name ?? ''} ${f.size ? `(${f.size} bytes)` : ''}`.trim(); }
    case 'emotion': return '[emoji]';
    case 'object': { const o = parse(); return o.url ? `[link] ${o.url}` : `[object ${o.type ?? ''}]`; }
    case 'code': { const o = parse(); return `[code ${o.language ?? o.name ?? ''}]\n${o.code ?? ''}`; }
    // Mentions are stored as `[@Name](@#userId)`.
    default: return (m.content ?? '').replace(/\[@([^\]]+)\]\(@#\d+\)/g, '@$1');
  }
}

function view(c, m, chats) {
  const ch = chats?.find((x) => x.gid === m.cgid);
  return {
    id: m.id,
    conversation: ch ? chatName(c, ch) : m.cgid,
    gid: m.cgid,
    time: iso(Number(m.date)),
    from: Number(m.user) === Number(c.me?.id) ? `${userName(c, m.user)} (me)` : userName(c, m.user),
    type: m.contentType,
    text: messageText(m),
    ...(m.deleted ? { deleted: true } : {}),
  };
}

/** Newest-first pages of a chat's history, `pageSize` messages per server round trip. */
async function* historyPages(c, cgid, pageSize = 50) {
  const info = await c.request('chatGetMessageInfo', [cgid]);
  let from = Number(info?.lastMessage);
  while (from > 0) {
    const ids = (await c.request('messageSync', [cgid, from, true, pageSize, true])) ?? [];
    const list = (Array.isArray(ids) ? ids : Object.values(ids)).map(Number).filter(Boolean);
    if (!list.length) return;
    const msgs = Object.values((await c.request('messageGetList', [cgid, list])) ?? {});
    msgs.sort((a, b) => Number(b.id) - Number(a.id));
    yield msgs;
    const next = Math.min(...list) - 1;
    // Stop on a short page, or if the server ignored fromId (avoids looping on the same page).
    if (list.length < pageSize || next >= from) return;
    from = next;
  }
}

async function fetchMessages(c, cgid, { limit, beforeSec = Infinity, filter = () => true, maxScan = 2000 }) {
  const out = [];
  let scanned = 0;
  for await (const page of historyPages(c, cgid)) {
    for (const m of page) {
      if (Number(m.date) < beforeSec && filter(m)) out.push(m);
      if (out.length >= limit) return out;
    }
    scanned += page.length;
    if (scanned >= maxScan) break;
  }
  return out;
}

export async function listConversations({ limit = 50 } = {}) {
  const c = await client();
  const chats = await loadChats(c, true);
  const rows = chats
    .filter((ch) => !ch.hide && !ch.dismissDate)
    .sort((a, b) => Number(b.lastActiveTime ?? 0) - Number(a.lastActiveTime ?? 0))
    .slice(0, limit);
  await loadUsers(c, rows.map((ch) => ch.lastMessageInfo?.user).filter(Boolean));
  return {
    me: c.me?.realname || c.me?.account,
    ...(c.schemeWarning ? { warning: c.schemeWarning } : {}),
    conversations: rows.map((ch) => ({
      name: chatName(c, ch),
      gid: ch.gid,
      type: ch.type,
      lastTime: iso(Number(ch.lastActiveTime)),
      lastMessage: ch.lastMessageInfo ? `${userName(c, ch.lastMessageInfo.user)}: ${messageText(ch.lastMessageInfo).slice(0, 120)}` : null,
    })),
  };
}

export async function readMessages({ conversation, limit = 50, before } = {}) {
  const c = await client();
  const ch = await resolveChat(c, conversation);
  const beforeSec = before ? Date.parse(before) / 1000 : Infinity;
  const msgs = await fetchMessages(c, ch.gid, { limit, beforeSec });
  await loadUsers(c, msgs.map((m) => m.user));
  return { conversation: chatName(c, ch), gid: ch.gid, messages: msgs.reverse().map((m) => view(c, m, c.chats)) };
}

// The server has no message search API (the desktop client searches its local cache),
// so this downloads recent history and filters it here.
export async function searchMessages({ query, conversation, limit = 50, chatsToScan = 20, perChatScan = 500 } = {}) {
  const c = await client();
  const chats = conversation
    ? [await resolveChat(c, conversation)]
    : (await loadChats(c)).filter((ch) => !ch.hide).sort((a, b) => Number(b.lastActiveTime ?? 0) - Number(a.lastActiveTime ?? 0)).slice(0, chatsToScan);
  const q = query.toLowerCase();
  const hits = [];
  for (const ch of chats) {
    const msgs = await fetchMessages(c, ch.gid, {
      limit,
      maxScan: perChatScan,
      filter: (m) => messageText(m).toLowerCase().includes(q) || userName(c, m.user).toLowerCase().includes(q),
    });
    hits.push(...msgs);
  }
  hits.sort((a, b) => Number(b.date) - Number(a.date));
  const top = hits.slice(0, limit);
  await loadUsers(c, top.map((m) => m.user));
  return {
    query,
    scanned: { chats: chats.length, perChatMessages: perChatScan },
    total: hits.length,
    messages: top.map((m) => view(c, m, c.chats)),
  };
}

export async function sendMessage({ conversation, text }) {
  const c = await client();
  const ch = await resolveChat(c, conversation);
  const msg = {
    gid: crypto.randomUUID(),
    cgid: ch.gid,
    type: 'normal',
    contentType: 'text',
    content: text,
    user: c.me.id,
    data: '',
    deleted: false,
  };
  const data = await c.request('messageSend', [[msg]]);
  const sent = Object.values(data ?? {}).find((m) => m?.gid === msg.gid);
  return { sent: !!sent, conversation: chatName(c, ch), gid: ch.gid, message: sent ? view(c, sent, c.chats) : null };
}
