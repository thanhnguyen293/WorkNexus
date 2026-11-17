// TBChat: read-only access to the desktop app's local ObjectBox database.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { ObjectBoxReader, loadModel } from './objectbox.js';

// Bundled so the single-file build needs no data folder; TBCHAT_MODEL points at a newer copy.
import bundledModel from '../data/tbchat-objectbox-model.json' with { type: 'json' };

const CONVERSATION_TYPES = { 0: 'single', 1: 'group', 2: 'channel', 3: 'strangers', 4: 'subscribe', 5: 'service', 6: 'payment' };
const MESSAGE_TYPES = {
  0: 'unknown', 1: 'text', 2: 'singleSystem', 3: 'voice', 4: 'video', 5: 'file', 6: 'image', 7: 'geo', 8: 'custom',
  9: 'link', 10: 'card', 11: 'forward', 12: 'quote', 13: 'groupSystem', 14: 'avChat', 15: 'black', 16: 'recall',
  17: 'redPacket', 18: 'transfer', 19: 'avChatGroup', 20: 'mediaFiles', 22: 'redPacketSystem', 23: 'transferReceived',
  24: 'share', 25: 'systemMessage', 26: 'groupVote', 1000: 'channel', 1001: 'channelPrivate', 1002: 'groupAnnouncement',
};

const exists = (p) => { try { fs.accessSync(p); return true; } catch { return false; } };
const subdirs = (p) => { try { return fs.readdirSync(p, { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => path.join(p, d.name)); } catch { return []; } };

/** Directories that may contain the app's `user_data` (or legacy hidden `.user_data`) root, per OS. */
function candidateRoots() {
  const home = os.homedir();
  const appDirs = []; // app-specific folders (name contains "tbchat")
  const bases = [];
  if (process.platform === 'darwin') {
    bases.push(path.join(home, 'Library', 'Containers'), path.join(home, 'Library', 'Application Support'));
  } else if (process.platform === 'win32') {
    if (process.env.APPDATA) bases.push(process.env.APPDATA);
    if (process.env.LOCALAPPDATA) bases.push(process.env.LOCALAPPDATA);
  } else {
    bases.push(process.env.XDG_DATA_HOME || path.join(home, '.local', 'share'), path.join(home, '.config'));
  }
  for (const b of bases) for (const d of subdirs(b)) if (/tbchat/i.test(path.basename(d))) appDirs.push(d);

  const roots = [];
  for (const d of appDirs) {
    // Covers: <app>/user_data (mac container root), <company>/<product>/user_data (Windows path_provider),
    // sandboxed <container>/Data/Library/Application Support/<id>/user_data and Data/Documents (legacy).
    roots.push(d, ...subdirs(d));
    const sandbox = path.join(d, 'Data', 'Library', 'Application Support');
    roots.push(...subdirs(sandbox), path.join(d, 'Data', 'Documents'));
  }
  roots.push(path.join(home, 'Documents'));
  return roots;
}

/** Finds every logged-in TBChat account database on this machine. */
export function discoverAccounts() {
  const dbs = new Set();
  if (process.env.TBCHAT_DB) dbs.add(path.resolve(process.env.TBCHAT_DB));
  const userDataDirs = process.env.TBCHAT_USER_DATA
    ? [process.env.TBCHAT_USER_DATA]
    : candidateRoots().flatMap((r) => [path.join(r, 'user_data'), path.join(r, '.user_data')]);
  for (const ud of userDataDirs) {
    for (const acc of subdirs(path.join(ud, 'accounts'))) {
      const db = path.join(acc, 'db', 'data.mdb');
      if (exists(db)) dbs.add(db);
    }
  }
  return [...dbs].map((db) => ({ account: path.basename(path.dirname(path.dirname(db))), dbPath: db }));
}

let model;
function readAll(dbPath) {
  model ??= loadModel(process.env.TBCHAT_MODEL || bundledModel);
  // A concurrent write by the running app can, rarely, recycle a page mid-read; one retry covers it.
  for (let attempt = 0; ; attempt++) {
    const r = new ObjectBoxReader(dbPath, model);
    try {
      return {
        messages: r.all('Message'),
        conversations: r.all('Conversation'),
        senders: r.all('SenderMemberInfo'),
        users: r.all('User'),
      };
    } catch (e) {
      if (attempt >= 1) throw e;
    } finally {
      r.close();
    }
  }
}

const iso = (ms) => (ms ? new Date(ms).toISOString() : null);
const safeJson = (s) => { try { return JSON.parse(s); } catch { return null; } };

// Group-event payloads carry member nicknames base64-encoded; plain names pass through unchanged.
function decodeNick(nick) {
  if (!nick || !/^[A-Za-z0-9+/]+={0,2}$/.test(nick) || nick.length % 4) return nick ?? '';
  const s = Buffer.from(nick, 'base64').toString('utf8');
  return s.includes('�') ? nick : s;
}

/** Human-readable text for a stored message, by type. */
export function messageText(m) {
  const c = safeJson(m.content);
  const kind = MESSAGE_TYPES[m.type] ?? `type${m.type}`;
  if (!c) return m.content || `[${kind}]`;
  switch (m.type) {
    case 1: return c.text ?? '';
    case 12: return `${c.text ?? ''}\n> (reply to ${c.nick ?? '?'}: ${String(c.quoteContent ?? '').slice(0, 200)})`;
    case 5: return `[file] ${c.fileName ?? ''} (${c.fileSize ?? '?'} bytes)`;
    case 6: return `[image] ${c.imageInfoArray?.[0]?.fileName ?? ''}`;
    case 4: return `[video] ${c.fileName ?? ''} ${c.videoSecond ? `${c.videoSecond}s` : ''}`.trim();
    case 3: return '[voice]';
    case 20: return `[media x${c.newList?.length ?? '?'}] ${c.remark ?? ''}`.trim();
    case 10: return `[contact card] ${c.nick ?? ''}`;
    case 24: return `[share ${c.kind ?? ''}] ${c.contact?.nick ?? ''}`.trim();
    case 11: return `[forwarded ${c.data?.length ?? 0} messages]\n` + (c.data ?? []).map((d) => `  ${d.nic}: ${String(d.msgContent ?? '').slice(0, 200)}`).join('\n');
    case 16: return '[message recalled]';
    case 13: return `[group event] ${c.groupOperationTypes ?? ''} ${decodeNick(c.operationMember?.nickName)}`.trim();
    case 1000: case 1001: return `[channel] ${c.Title ?? ''}${c.SubTitle ? ` — ${c.SubTitle}` : ''}`;
    default: return `[${kind}]`;
  }
}

class TbChatAccount {
  constructor({ account, dbPath }) {
    const d = readAll(dbPath);
    this.account = account;
    this.me = d.users[0];
    this.senders = new Map(d.senders.map((s) => [s.id, s]));
    this.conversations = d.conversations;
    this.convBySession = new Map(d.conversations.map((c) => [c.sessionId, c]));
    this.messages = d.messages.sort((a, b) => a.createTime - b.createTime);
  }

  view(m) {
    const s = this.senders.get(m.senderId);
    const fromMe = !!(s && this.me && s.nodeId === this.me.nodeId);
    return {
      id: m.msgId,
      conversation: this.convBySession.get(m.sessionId)?.name ?? m.sessionId,
      sessionId: m.sessionId,
      time: iso(m.createTime),
      from: fromMe ? `${this.me.name} (me)` : s?.nickname || s?.nodeId || 'system',
      type: MESSAGE_TYPES[m.type] ?? `type${m.type}`,
      text: messageText(m),
      ...(m.isEdited ? { edited: true } : {}),
    };
  }
}

/** Opens one account (or the only one); throws a helpful error otherwise. */
function openAccount(account) {
  const all = discoverAccounts();
  if (!all.length) throw new Error('No TBChat data found. Set TBCHAT_USER_DATA (the folder containing "accounts") or TBCHAT_DB (path to data.mdb).');
  const pick = account ? all.find((a) => a.account === String(account)) : all[0];
  if (!pick) throw new Error(`TBChat account "${account}" not found. Available: ${all.map((a) => a.account).join(', ')}`);
  return new TbChatAccount(pick);
}

function resolveConversation(acc, conversation) {
  const q = String(conversation).toLowerCase();
  const c = acc.convBySession.get(conversation)
    ?? acc.conversations.find((x) => (x.name ?? '').toLowerCase() === q)
    ?? acc.conversations.find((x) => (x.name ?? '').toLowerCase().includes(q));
  if (!c) throw new Error(`TBChat conversation "${conversation}" not found. Use list_conversations to see names / sessionIds.`);
  return c;
}

export function listConversations({ account, limit = 50 } = {}) {
  const acc = openAccount(account);
  const last = new Map();
  for (const m of acc.messages) last.set(m.sessionId, m);
  return {
    account: acc.account,
    me: acc.me?.name,
    conversations: acc.conversations
      .filter((c) => !c.hideState)
      .sort((a, b) => b.lastTime - a.lastTime)
      .slice(0, limit)
      .map((c) => {
        const lm = last.get(c.sessionId);
        return {
          name: c.name,
          sessionId: c.sessionId,
          type: CONVERSATION_TYPES[c.type] ?? String(c.type),
          lastTime: iso(c.lastTime),
          lastMessage: lm ? acc.view(lm).text.slice(0, 120) : null,
        };
      }),
  };
}

export function readMessages({ account, conversation, limit = 50, before } = {}) {
  const acc = openAccount(account);
  const c = resolveConversation(acc, conversation);
  const beforeMs = before ? Date.parse(before) : Infinity;
  const msgs = acc.messages.filter((m) => m.sessionId === c.sessionId && m.createTime < beforeMs);
  return {
    conversation: c.name,
    sessionId: c.sessionId,
    total: msgs.length,
    messages: msgs.slice(-limit).map((m) => acc.view(m)),
  };
}

export function searchMessages({ account, query, conversation, limit = 50 } = {}) {
  const acc = openAccount(account);
  const sessionId = conversation ? resolveConversation(acc, conversation).sessionId : null;
  const q = query.toLowerCase();
  const hits = acc.messages
    .filter((m) => !sessionId || m.sessionId === sessionId)
    .map((m) => acc.view(m))
    .filter((v) => v.text.toLowerCase().includes(q) || v.from.toLowerCase().includes(q));
  return { query, total: hits.length, messages: hits.slice(-limit).reverse() };
}
