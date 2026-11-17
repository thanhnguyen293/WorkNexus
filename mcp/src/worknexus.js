// ZenTao chat read from WorkNexus' local SQLite cache (read-only). WorkNexus syncs xxd chat into
// chat_conversations / chat_messages / chat_users; reading it needs no credentials and no extra login.
import fs from 'node:fs';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import { messageText } from './zentao.js';

const DB_FILE = 'worknexus.sqlite';
const APP_ID = 'com.worknexus.workNexus';

/** Where path_provider's getApplicationSupportDirectory() puts WorkNexus' database, per OS. */
function candidatePaths() {
  if (process.env.WORKNEXUS_DB) return [path.resolve(process.env.WORKNEXUS_DB)];
  const home = os.homedir();
  if (process.platform === 'darwin') {
    return [
      path.join(home, 'Library', 'Application Support', APP_ID, DB_FILE),
      path.join(home, 'Library', 'Containers', APP_ID, 'Data', 'Library', 'Application Support', APP_ID, DB_FILE),
    ];
  }
  if (process.platform === 'win32') {
    const appData = process.env.APPDATA || path.join(home, 'AppData', 'Roaming');
    return [path.join(appData, 'WorkNexus', 'WorkNexus', DB_FILE)];
  }
  const data = process.env.XDG_DATA_HOME || path.join(home, '.local', 'share');
  return [path.join(data, APP_ID, DB_FILE), path.join(data, 'WorkNexus', DB_FILE), path.join(data, 'work_nexus', DB_FILE)];
}

export function findDatabase() {
  return candidatePaths().find((p) => fs.existsSync(p)) ?? null;
}

// Written beside the DB by WorkNexus while "Let local AI tools send messages" is on.
const LOCAL_API_FILE = 'chat_local_api.json';

/** Port + token of WorkNexus' local chat API, or null when it is off / not installed. */
export function localApiInfo() {
  const db = findDatabase();
  if (!db) return null;
  try {
    const info = JSON.parse(fs.readFileSync(path.join(path.dirname(db), LOCAL_API_FILE), 'utf8'));
    if (!Number.isInteger(info.port) || typeof info.token !== 'string') return null;
    // A file left behind by a WorkNexus that was killed is not a running API.
    return Number.isInteger(info.pid) && !processAlive(info.pid) ? null : info;
  } catch {
    return null;
  }
}

function processAlive(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch (e) {
    return e.code === 'EPERM'; // exists, owned by someone else
  }
}

function postJson(info, urlPath, body) {
  const data = Buffer.from(JSON.stringify(body));
  return new Promise((resolve, reject) => {
    const req = http.request({
      host: '127.0.0.1',
      port: info.port,
      path: urlPath,
      method: 'POST',
      headers: { Authorization: `Bearer ${info.token}`, 'Content-Type': 'application/json', 'Content-Length': data.length },
      timeout: 30000,
    }, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => {
        let json = {};
        try { json = JSON.parse(Buffer.concat(chunks).toString('utf8')); } catch {}
        resolve({ status: res.statusCode, json });
      });
    });
    req.on('timeout', () => req.destroy(new Error('WorkNexus did not answer in time')));
    req.on('error', reject);
    req.end(data);
  });
}

let DatabaseSync;
async function open() {
  const file = findDatabase();
  if (!file) throw new Error('WorkNexus database not found. Set WORKNEXUS_DB to the path of worknexus.sqlite.');
  // Imported lazily so the "SQLite is experimental" warning only appears when WorkNexus is actually used.
  DatabaseSync ??= (await import('node:sqlite')).DatabaseSync;
  return new DatabaseSync(file, { readOnly: true, timeout: 3000 });
}

async function withDb(fn) {
  const db = await open();
  try {
    return fn(db);
  } finally {
    db.close();
  }
}

/** Same folding WorkNexus applies to chat_messages.search_text: lower case, no Vietnamese diacritics, collapsed spaces. */
export function fold(text) {
  return text
    .toLowerCase()
    .replace(/đ/g, 'd')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

const iso = (sec) => (sec ? new Date(Number(sec) * 1000).toISOString() : null);
const likeEscape = (s) => s.replace(/[\\%_]/g, (c) => `\\${c}`);

class Ctx {
  constructor(db, accountArg) {
    const accounts = db.prepare(`
      SELECT ca.account_id AS id, ca.user_id AS userId, a.handle, a.base_url AS baseUrl,
             (SELECT COUNT(*) FROM chat_conversations c WHERE c.account_id = ca.account_id) AS chats
      FROM chat_accounts ca LEFT JOIN accounts a ON a.id = ca.account_id
      ORDER BY chats DESC`).all();
    if (!accounts.length) throw new Error('WorkNexus has no ZenTao chat account yet.');
    const q = accountArg ? String(accountArg).toLowerCase() : null;
    this.account = q ? accounts.find((a) => a.id.toLowerCase() === q || (a.handle ?? '').toLowerCase() === q) : accounts[0];
    if (!this.account) throw new Error(`WorkNexus chat account "${accountArg}" not found. Available: ${accounts.map((a) => a.handle ?? a.id).join(', ')}`);
    this.db = db;
    this.users = new Map(
      db.prepare('SELECT user_id AS id, account, realname FROM chat_users WHERE account_id = ?').all(this.account.id).map((u) => [Number(u.id), u]),
    );
  }

  userName(id) {
    const u = this.users.get(Number(id));
    return u ? u.realname || u.account : `user#${id}`;
  }

  chatName(c) {
    if (c.name) return c.name;
    if (c.type === 'one2one') {
      const other = String(c.gid).split('&').find((id) => Number(id) !== Number(this.account.userId));
      return this.userName(other ?? this.account.userId);
    }
    return c.gid;
  }

  conversations() {
    return this.db.prepare(`
      SELECT gid, type, name, last_active_at AS lastActive, hidden, archived, starred
      FROM chat_conversations WHERE account_id = ? ORDER BY last_active_at DESC`).all(this.account.id);
  }

  resolve(conversation) {
    const all = this.conversations();
    const q = String(conversation).toLowerCase();
    const c = all.find((x) => x.gid === conversation)
      ?? all.find((x) => this.chatName(x).toLowerCase() === q)
      ?? all.find((x) => this.chatName(x).toLowerCase().includes(q));
    if (!c) throw new Error(`ZenTao chat "${conversation}" not found in WorkNexus. Use list_conversations to see names / gids.`);
    return c;
  }

  view(m, names) {
    const fromMe = Number(m.senderId) === Number(this.account.userId);
    return {
      id: m.serverId ?? m.gid,
      conversation: names?.get(m.cgid) ?? m.cgid,
      gid: m.cgid,
      time: iso(m.sentAt),
      from: `${this.userName(m.senderId)}${fromMe ? ' (me)' : ''}`,
      type: m.contentType,
      text: messageText({ contentType: m.contentType, content: m.content }),
      ...(m.deleted ? { deleted: true } : {}),
      ...(m.sendState !== 'sent' ? { sendState: m.sendState } : {}),
    };
  }

  meta() {
    const last = this.db.prepare('SELECT MAX(sent_at) AS t FROM chat_messages WHERE account_id = ?').get(this.account.id);
    return { source: 'worknexus', account: this.account.handle ?? this.account.id, newestMessageInCache: iso(last?.t) };
  }
}

const MSG_COLUMNS = `gid, cgid, server_id AS serverId, sender_id AS senderId, sent_at AS sentAt,
  content_type AS contentType, content, deleted, send_state AS sendState`;

export function listConversations({ account, limit = 50 } = {}) {
  return withDb((db) => {
    const ctx = new Ctx(db, account);
    const lastMsg = db.prepare(`SELECT ${MSG_COLUMNS} FROM chat_messages WHERE account_id = ? AND cgid = ? ORDER BY sent_at DESC LIMIT 1`);
    const rows = ctx.conversations().filter((c) => !c.hidden).slice(0, limit);
    return {
      ...ctx.meta(),
      conversations: rows.map((c) => {
        const m = lastMsg.get(ctx.account.id, c.gid);
        return {
          name: ctx.chatName(c),
          gid: c.gid,
          type: c.type,
          lastTime: iso(c.lastActive),
          ...(c.archived ? { archived: true } : {}),
          lastMessage: m ? `${ctx.userName(m.senderId)}: ${ctx.view(m).text.slice(0, 120)}` : null,
        };
      }),
    };
  });
}

export function readMessages({ account, conversation, limit = 50, before } = {}) {
  return withDb((db) => {
    const ctx = new Ctx(db, account);
    const c = ctx.resolve(conversation);
    const beforeSec = before ? Math.floor(Date.parse(before) / 1000) : Number.MAX_SAFE_INTEGER;
    const rows = db.prepare(`
      SELECT ${MSG_COLUMNS} FROM chat_messages
      WHERE account_id = ? AND cgid = ? AND sent_at < ?
      ORDER BY sent_at DESC, server_id DESC LIMIT ?`).all(ctx.account.id, c.gid, beforeSec, limit);
    const name = ctx.chatName(c);
    return { ...ctx.meta(), conversation: name, gid: c.gid, messages: rows.reverse().map((m) => ctx.view(m, new Map([[c.gid, name]]))) };
  });
}

export function searchMessages({ account, query, conversation, limit = 50 } = {}) {
  return withDb((db) => {
    const ctx = new Ctx(db, account);
    const folded = fold(query);
    const like = `%${likeEscape(folded)}%`;
    const rawLike = `%${likeEscape(query.toLowerCase())}%`;
    // Sender-name matches: chat_users is small, so match names here and pass ids to SQL.
    const senderIds = [...ctx.users.values()].filter((u) => fold(`${u.realname} ${u.account}`).includes(folded)).map((u) => Number(u.id));
    const cgid = conversation ? ctx.resolve(conversation).gid : null;
    const where = [
      'account_id = ?',
      ...(cgid ? ['cgid = ?'] : []),
      `(search_text LIKE ? ESCAPE '\\' OR (search_text IS NULL AND lower(content) LIKE ? ESCAPE '\\')${senderIds.length ? ` OR sender_id IN (${senderIds.map(() => '?').join(',')})` : ''})`,
    ].join(' AND ');
    const params = [ctx.account.id, ...(cgid ? [cgid] : []), like, rawLike, ...senderIds];
    const total = db.prepare(`SELECT COUNT(*) AS n FROM chat_messages WHERE ${where}`).get(...params).n;
    const rows = db.prepare(`SELECT ${MSG_COLUMNS} FROM chat_messages WHERE ${where} ORDER BY sent_at DESC LIMIT ?`).all(...params, limit);
    const names = new Map(ctx.conversations().map((c) => [c.gid, ctx.chatName(c)]));
    return { ...ctx.meta(), query, total: Number(total), messages: rows.map((m) => ctx.view(m, names)) };
  });
}

/** Sends through WorkNexus' logged-in chat session (its local API), so no ZenTao password is needed here. */
export async function sendMessage({ account, conversation, text }) {
  const info = localApiInfo();
  if (!info) {
    throw new Error('WorkNexus local chat API is off. In WorkNexus open Quick Settings › Chat › AI tools and turn on "Let local AI tools send messages" (WorkNexus must be running).');
  }
  const target = await withDb((db) => {
    const ctx = new Ctx(db, account);
    const c = ctx.resolve(conversation);
    return { accountId: ctx.account.id, gid: c.gid, name: ctx.chatName(c) };
  });
  let res;
  try {
    res = await postJson(info, '/v1/chat/send', { accountId: target.accountId, chatGid: target.gid, text });
  } catch (e) {
    throw new Error(`Could not reach WorkNexus (is it running?): ${e.message}`);
  }
  if (res.status !== 200) throw new Error(`WorkNexus refused the message (HTTP ${res.status}): ${res.json.error ?? 'unknown error'}`);
  return { sent: true, via: 'worknexus', conversation: target.name, gid: target.gid };
}
