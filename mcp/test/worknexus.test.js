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
      PRIMARY KEY (account_id, gid));
    INSERT INTO accounts VALUES ('zt-me', 'w', 'zentao', 'Me', 'https://z', NULL);
    INSERT INTO chat_accounts VALUES ('zt-me', NULL, NULL, 1), ('zt-empty', NULL, NULL, 9);
    INSERT INTO chat_users VALUES ('zt-me', 1, 'me', 'Me Myself'), ('zt-me', 2, 'lan', 'Nguyễn Lan');
    INSERT INTO chat_conversations VALUES
      ('zt-me', '1&2', 'one2one', '', 300, 0, 0, 0),
      ('zt-me', 'g1', 'group', 'Mobile Team', 200, 0, 0, 0),
      ('zt-me', 'g-old', 'group', 'Hidden', 100, 1, 0, 0);
  `);
  const ins = db.prepare('INSERT INTO chat_messages (account_id, gid, cgid, server_id, sender_id, sent_at, content_type, content, search_text) VALUES (?,?,?,?,?,?,?,?,?)');
  ins.run('zt-me', 'a', '1&2', 1, 2, 250, 'plain', 'Đường build lỗi rồi', 'duong build loi roi');
  ins.run('zt-me', 'b', '1&2', 2, 1, 260, 'text', '**ok** để mình xem', 'ok de minh xem');
  ins.run('zt-me', 'c', '1&2', 3, 2, 300, 'file', JSON.stringify({ name: 'log.txt', size: 5 }), null);
  ins.run('zt-me', 'd', 'g1', 4, 1, 200, 'plain', '100% done_now', '100% done_now');
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
  await assert.rejects(wn.sendMessage({ conversation: 'lan', text: 'hi' }), /Let local AI tools send messages/);
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
