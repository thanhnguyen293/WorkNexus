// Reads a throwaway SQLite file shaped like WorkNexus' chat tables.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import http from 'node:http';
import * as wn from '../src/worknexus.js';

const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'wn-test-'));
const file = path.join(dir, 'worknexus.sqlite');

before(() => {
  const db = new DatabaseSync(file);
  db.exec(`
    CREATE TABLE accounts (id TEXT PRIMARY KEY, workspace_id TEXT, provider_type TEXT, handle TEXT, base_url TEXT, credentials_ref TEXT);
    CREATE TABLE chat_accounts (account_id TEXT PRIMARY KEY, server_url TEXT, pinned_fingerprint TEXT, user_id INTEGER);
    CREATE TABLE chat_conversations (account_id TEXT, gid TEXT, type TEXT, name TEXT, last_active_at INTEGER,
      hidden INTEGER DEFAULT 0, archived INTEGER DEFAULT 0, starred INTEGER DEFAULT 0, PRIMARY KEY (account_id, gid));
    CREATE TABLE chat_users (account_id TEXT, user_id INTEGER, account TEXT, realname TEXT, PRIMARY KEY (account_id, user_id));
    CREATE TABLE chat_messages (account_id TEXT, gid TEXT, cgid TEXT, server_id INTEGER, sender_id INTEGER, sent_at INTEGER,
      content_type TEXT, content TEXT, send_state TEXT DEFAULT 'sent', deleted INTEGER DEFAULT 0, search_text TEXT,
      message_index INTEGER, detached INTEGER DEFAULT 0,
      PRIMARY KEY (account_id, gid));
    INSERT INTO accounts VALUES ('zt-me', 'w', 'zentao', 'Me', 'https://z', NULL);
    INSERT INTO chat_accounts VALUES ('zt-me', NULL, NULL, 1), ('zt-empty', NULL, NULL, 9);
    INSERT INTO chat_users VALUES ('zt-me', 1, 'me', 'Me Myself'), ('zt-me', 2, 'lan', 'Nguyễn Lan');
    INSERT INTO chat_conversations VALUES
      ('zt-me', '1&2', 'one2one', '', 300, 0, 0, 0),
      ('zt-me', 'g1', 'group', 'Mobile Team', 200, 0, 0, 0),
      ('zt-me', 'g-old', 'group', 'Hidden', 100, 1, 0, 0);
  `);
  const ins = db.prepare('INSERT INTO chat_messages (account_id, gid, cgid, server_id, sender_id, sent_at, content_type, content, search_text, message_index) VALUES (?,?,?,?,?,?,?,?,?,?)');
  ins.run('zt-me', 'a', '1&2', 1, 2, 250, 'plain', 'Đường build lỗi rồi', 'duong build loi roi', 1);
  ins.run('zt-me', 'b', '1&2', 2, 1, 260, 'text', '**ok** để mình xem', 'ok de minh xem', 2);
  ins.run('zt-me', 'c', '1&2', 3, 2, 300, 'file', JSON.stringify({ name: 'log.txt', size: 5 }), null, 3);
  ins.run('zt-me', 'd', 'g1', 14, 1, 200, 'plain', '100% done_now', '100% done_now', 4);
  db.close();
  process.env.WORKNEXUS_DB = file;
});

after(() => fs.rmSync(dir, { recursive: true, force: true }));

test('fold matches WorkNexus search_text folding', () => {
  assert.equal(wn.fold('  Đường   Phố HÀ Nội '), 'duong pho ha noi');
});

test('lists visible chats, naming one2one by the other member', async () => {
  const r = await wn.listConversations({});
  assert.equal(r.account, 'Me');
  assert.equal(r.newestMessageInCache, new Date(300 * 1000).toISOString());
  assert.deepEqual(r.conversations.map((c) => c.name), ['Nguyễn Lan', 'Mobile Team']);
  assert.equal(r.conversations[0].lastMessage, 'Nguyễn Lan: [file] log.txt (5 bytes)');
});

test('reads oldest-first, limited, and before a time', async () => {
  const r = await wn.readMessages({ conversation: 'lan', limit: 2 });
  assert.deepEqual(r.messages.map((m) => m.text), ['**ok** để mình xem', '[file] log.txt (5 bytes)']);
  assert.equal(r.messages[0].from, 'Me Myself (me)');
  const b = await wn.readMessages({ conversation: '1&2', before: new Date(260 * 1000).toISOString() });
  assert.deepEqual(b.messages.map((m) => m.id), [1]);
  // The stored timeline holds the chat's first message: nothing more to fetch.
  assert.equal(b.history, undefined);
  assert.equal(r.messages[1].attachment, 'file');
});

test('searches folded text, raw non-text content and sender names', async () => {
  assert.equal((await wn.searchMessages({ query: 'ĐƯỜNG build' })).total, 1);
  assert.equal((await wn.searchMessages({ query: 'log.txt' })).total, 1);
  assert.equal((await wn.searchMessages({ query: 'nguyen lan' })).total, 2);
  // LIKE wildcards in the query are literal.
  assert.equal((await wn.searchMessages({ query: '100%' })).total, 1);
  assert.equal((await wn.searchMessages({ query: 'done_now', conversation: 'Mobile' })).total, 1);
  assert.equal((await wn.searchMessages({ query: '%' , conversation: 'lan' })).total, 0);
});

test('reports unknown accounts and chats clearly', async () => {
  await assert.rejects(wn.listConversations({ account: 'nobody' }), /not found. Available/);
  await assert.rejects(wn.readMessages({ conversation: 'nope' }), /not found in WorkNexus/);
});

test('sendMessage explains how to turn the WorkNexus API on when it is off', async () => {
  await assert.rejects(wn.sendMessage({ conversation: 'lan', text: 'hi' }), /Let local AI tools use chat/);
});

test('sendMessage posts to the WorkNexus local API with its token', async () => {
  const got = [];
  let status = 200;
  const srv = http.createServer((req, res) => {
    let body = '';
    req.on('data', (c) => (body += c));
    req.on('end', () => {
      got.push({ auth: req.headers.authorization, url: req.url, origin: req.headers.origin, body: JSON.parse(body) });
      res.writeHead(status, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(status === 200 ? { ok: true } : { error: 'Chat is offline' }));
    });
  });
  await new Promise((r) => srv.listen(0, '127.0.0.1', r));
  const apiFile = path.join(dir, 'chat_local_api.json');
  fs.writeFileSync(apiFile, JSON.stringify({ version: 1, port: srv.address().port, token: 'tok', pid: 2 ** 30 }));
  assert.equal(wn.localApiInfo(), null, 'a file whose app is gone is ignored');
  fs.writeFileSync(apiFile, JSON.stringify({ version: 1, port: srv.address().port, token: 'tok', pid: process.pid }));
  try {
    assert.ok(wn.localApiInfo());
    const r = await wn.sendMessage({ conversation: 'Mobile', text: 'xin chào' });
    assert.deepEqual(r, { sent: true, via: 'worknexus', conversation: 'Mobile Team', gid: 'g1' });
    assert.deepEqual(got[0], { auth: 'Bearer tok', url: '/v1/chat/send', origin: undefined, body: { accountId: 'zt-me', chatGid: 'g1', text: 'xin chào' } });

    status = 502;
    await assert.rejects(wn.sendMessage({ conversation: 'lan', text: 'x' }), /HTTP 502\): Chat is offline/);
  } finally {
    srv.close();
    fs.rmSync(apiFile);
  }
});

/** A stand-in for WorkNexus' local API; `routes` answers each path with (body) => [status, json]. */
async function fakeApi(routes) {
  const got = [];
  const srv = http.createServer((req, res) => {
    let body = '';
    req.on('data', (c) => (body += c));
    req.on('end', () => {
      const json = JSON.parse(body);
      got.push({ url: req.url, body: json });
      const [status, out] = routes[req.url]?.(json) ?? [404, { error: 'Unknown endpoint' }];
      res.writeHead(status, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(out));
    });
  });
  await new Promise((r) => srv.listen(0, '127.0.0.1', r));
  const apiFile = path.join(dir, 'chat_local_api.json');
  fs.writeFileSync(apiFile, JSON.stringify({ version: 1, port: srv.address().port, token: 'tok', pid: process.pid }));
  return { got, close: () => { srv.close(); fs.rmSync(apiFile); } };
}

test('with too few stored and the API off, readMessages says how to get more', async () => {
  const r = await wn.readMessages({ conversation: 'Mobile', limit: 5 });
  assert.equal(r.messages.length, 1);
  assert.equal(r.history.enough, false);
  assert.match(r.history.note, /Let local AI tools use chat/);
});

test('readMessages has WorkNexus page back until enough timeline messages are stored', async () => {
  const db = new DatabaseSync(file);
  // A pinned message stored on its own far back must not count as history already there.
  db.prepare("INSERT INTO chat_messages (account_id, gid, cgid, server_id, sender_id, sent_at, content_type, content, message_index, detached) VALUES ('zt-me', 'pin', 'g1', 2, 2, 50, 'plain', 'pinned', 2, 1)").run();
  let next = 13; // server ids / indexes of the older g1 messages WorkNexus "fetches"
  const api = await fakeApi({
    '/v1/chat/load-older': ({ pageSize }) => {
      const add = db.prepare("INSERT OR REPLACE INTO chat_messages (account_id, gid, cgid, server_id, sender_id, sent_at, content_type, content, message_index, detached) VALUES ('zt-me', ?, 'g1', ?, 2, ?, 'plain', ?, ?, 0)");
      const page = Math.min(2, next - 1); // pages of 2, whatever was asked
      for (let i = 0; i < page; i++, next--) add.run(`old${next}`, next, 100 + next, `m${next}`, next);
      return [200, { ok: true, loaded: page, reachesStart: false, pageSize }];
    },
  });
  try {
    const r = await wn.readMessages({ conversation: 'Mobile', limit: 4 });
    assert.deepEqual(r.messages.map((m) => m.text), ['m11', 'm12', 'm13', '100% done_now']);
    assert.deepEqual(r.history, { loadedFromServer: 4, reachesStart: false, enough: true });
    assert.equal(api.got.length, 2);
    assert.deepEqual(api.got[0].body, { accountId: 'zt-me', chatGid: 'g1', pageSize: 50 });

    const none = await wn.readMessages({ conversation: 'Mobile', limit: 10, loadMore: false });
    assert.equal(api.got.length, 2, 'loadMore: false asks nothing');
    assert.equal(none.history.enough, false);
  } finally {
    api.close();
    db.prepare("DELETE FROM chat_messages WHERE cgid = 'g1' AND gid != 'd'").run();
    db.close();
  }
});

test('readMessages stops paging when WorkNexus reaches the start', async () => {
  const api = await fakeApi({ '/v1/chat/load-older': () => [200, { ok: true, loaded: 0, reachesStart: true }] });
  try {
    const r = await wn.readMessages({ conversation: 'Mobile', limit: 50 });
    assert.deepEqual(r.history, { loadedFromServer: 0, reachesStart: true, enough: true });
    assert.equal(api.got.length, 1);
  } finally {
    api.close();
  }
});

test('getAttachment asks WorkNexus for the file and passes on its errors', async () => {
  const api = await fakeApi({
    '/v1/chat/attachment': ({ messageId }) => messageId === 3
      ? [200, { ok: true, path: '/cache/log.txt', name: 'log.txt', size: 5, mimeType: null, isImage: false }]
      : [404, { error: 'Message 9 not found in this chat' }],
  });
  try {
    const r = await wn.getAttachment({ conversation: 'lan', messageId: 3 });
    assert.deepEqual(r, { conversation: 'Nguyễn Lan', gid: '1&2', messageId: 3, path: '/cache/log.txt', name: 'log.txt', size: 5, mimeType: null, isImage: false });
    assert.deepEqual(api.got[0], { url: '/v1/chat/attachment', body: { accountId: 'zt-me', chatGid: '1&2', messageId: 3 } });
    await assert.rejects(wn.getAttachment({ conversation: 'lan', messageId: 9 }), /HTTP 404\): Message 9 not found/);
  } finally {
    api.close();
  }
  await assert.rejects(wn.getAttachment({ conversation: 'lan', messageId: 3 }), /cannot download files and images/);
});
