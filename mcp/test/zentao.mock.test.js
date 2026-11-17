// Exercises the ZenTao client against an in-process fake xxd server (serverInfo over HTTP, AES WebSocket).
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import http from 'node:http';
import { WebSocketServer } from 'ws';

const TOKEN = 'abcdefghijklmnopqrstuvwxyz012345'; // 32 bytes: AES-256 key, first 16 = IV
const md5 = (s) => crypto.createHash('md5').update(s).digest('hex');
const aes = (mode, buf) => {
  const c = (mode === 'enc' ? crypto.createCipheriv : crypto.createDecipheriv)('aes-256-cbc', Buffer.from(TOKEN), Buffer.from(TOKEN.slice(0, 16)));
  return Buffer.concat([c.update(buf), c.final()]);
};

const me = { id: 1, account: 'tester', realname: 'Tester' };
const users = { 1: me, 2: { id: 2, account: 'alice', realname: 'Alice' } };
const chats = [
  { gid: '1&2', type: 'one2one', name: '', members: [1, 2], lastActiveTime: 200 },
  { gid: 'g-team', type: 'group', name: 'Team', members: [1, 2], lastActiveTime: 100 },
];
const messages = { '1&2': [], 'g-team': [] };
for (let i = 1; i <= 120; i++) {
  messages['1&2'].push({ id: i, gid: `m${i}`, cgid: '1&2', user: i % 2 ? 2 : 1, date: 1000 + i, contentType: 'text', content: i === 7 ? 'deploy the build' : `hello ${i}` });
}
messages['g-team'].push({ id: 500, gid: 'm500', cgid: 'g-team', user: 2, date: 5000, contentType: 'file', content: JSON.stringify({ name: 'spec.pdf', size: 10 }) });

let httpServer, wss, sent = [];

before(async () => {
  wss = new WebSocketServer({ port: 0, path: '/ws' });
  await new Promise((r) => wss.once('listening', r));
  httpServer = http.createServer((req, res) => {
    let body = '';
    req.on('data', (c) => (body += c));
    req.on('end', () => {
      const payload = JSON.parse(body.replace(/^data=/, ''));
      assert.equal(payload.method, 'sysgetserverinfo');
      res.end(JSON.stringify({ token: TOKEN, chatPort: wss.address().port, enableClientAES: true, version: '7.0', serverTime: Math.floor(Date.now() / 1000) }));
    });
  });
  await new Promise((r) => httpServer.listen(0, r));

  wss.on('connection', (ws) => {
    const reply = (req, data, extra = {}) => ws.send(aes('enc', Buffer.from(JSON.stringify({ method: req.method, rid: req.rid, result: 'success', data, ...extra }))));
    ws.on('message', (raw) => {
      const req = JSON.parse(aes('dec', raw).toString());
      const p = req.params ?? [];
      switch (req.method) {
        case 'userlogin':
          return p[2] === md5('secret') ? reply(req, me) : reply(req, null, { result: 'fail', message: 'bad password' });
        case 'chatgetlist': return reply(req, chats);
        case 'usergetlist': return reply(req, Object.fromEntries(p[0].map((id) => [id, users[id]])));
        case 'chatgetmessageinfo': {
          const list = messages[p[0]];
          return reply(req, { lastMessage: list.at(-1).id, messageCount: list.length });
        }
        case 'messagesync': {
          const [cgid, from, , limit] = p;
          const ids = messages[cgid].filter((m) => m.id <= from).map((m) => m.id).slice(-limit);
          return reply(req, ids);
        }
        case 'messagegetlist': return reply(req, messages[p[0]].filter((m) => p[1].includes(m.id)));
        case 'messagesend': {
          const m = { ...p[0][0], id: 999, date: 9999 };
          sent.push(m);
          // Real servers echo sends without our rid sometimes; exercise the method-name fallback.
          return ws.send(aes('enc', Buffer.from(JSON.stringify({ method: 'messagesend', result: 'success', data: [m] }))));
        }
        default: return reply(req, null);
      }
    });
  });

  process.env.ZENTAO_SERVER = `http://127.0.0.1:${httpServer.address().port}`;
  process.env.ZENTAO_ACCOUNT = 'tester';
  process.env.ZENTAO_PASSWORD = 'secret';
});

after(() => {
  wss.clients.forEach((c) => c.terminate());
  wss.close();
  httpServer.close();
});

const zentao = await import('../src/zentao.js');

test('lists conversations with resolved one2one names', async () => {
  const r = await zentao.listConversations({});
  assert.equal(r.me, 'Tester');
  assert.deepEqual(r.conversations.map((c) => c.name), ['Alice', 'Team']);
});

test('reads the latest messages across pages, oldest first', async () => {
  const r = await zentao.readMessages({ conversation: 'alice', limit: 70 });
  assert.equal(r.messages.length, 70);
  assert.equal(r.messages.at(-1).text, 'hello 120');
  assert.equal(r.messages[0].text, 'hello 51');
  assert.equal(r.messages.at(-1).from, 'Tester (me)');
});

test('reads before a given time', async () => {
  const r = await zentao.readMessages({ conversation: '1&2', limit: 3, before: new Date(1011 * 1000).toISOString() });
  assert.deepEqual(r.messages.map((m) => m.text), ['hello 8', 'hello 9', 'hello 10']);
});

test('searches history client-side', async () => {
  const r = await zentao.searchMessages({ query: 'DEPLOY' });
  assert.equal(r.total, 1);
  assert.equal(r.messages[0].text, 'deploy the build');
  const f = await zentao.searchMessages({ query: 'spec.pdf', conversation: 'Team' });
  assert.equal(f.messages[0].text, '[file] spec.pdf (10 bytes)');
});

test('sends a text message', async () => {
  const r = await zentao.sendMessage({ conversation: 'Team', text: 'hi team' });
  assert.equal(r.sent, true);
  assert.equal(sent.at(-1).cgid, 'g-team');
  assert.equal(sent.at(-1).content, 'hi team');
  assert.equal(sent.at(-1).user, 1);
  assert.equal(sent.at(-1).contentType, 'text');
});
