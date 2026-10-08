#!/usr/bin/env node
// Probe a ZenTao chat (xuanxuan / xxd) server before building the chat feature.
//
//   Step 1: POST {server}/serverInfo -> token, chatPort, socketUrl, version
//   Step 2 (unless --info-only): open the WebSocket and log in (userLogin).
//   Step 3: chat list + the newest 10 messages of one chat (messageSync).
//   Step 4 (only with --send and --chat): send one text message (messagesend).
//   Step 5: listen for pushed `messagesend` packets for --listen seconds.
//
// Protocol taken from the bundled xuanxuan 9.1.2 client (zentaoclient.app):
//   serverInfo: {method:'sysgetserverinfo', params:[serverName, account,
//                authKey, apiVersion], version, device, lang}
//   socket:     {method:'userLogin', params:[serverName, account, authKey,
//                {status, simple}], rid}
//   authKey for password login = md5(password). Frames are AES-256-CBC
//   (key=token, iv=token[0..16]) only when serverInfo says enableClientAES.
//
// Usage:
//   node --experimental-websocket tool/xuanxuan_probe.mjs \
//     --server https://chat.example.com:11443 --account thanh \
//     [--server-name ""] [--insecure] [--info-only] [--optimizer <path.cjs>]
//     [--chat <gid>] [--send "text"] [--listen 60] [--download <dir>]
//     [--dump-scheme <file.json>] [--dump-frames <dir>]
//
// --dump-scheme: write serverInfo.apiScheme (protocol metadata, no user data).
// --dump-frames: write every decrypted socket frame (raw packed JSON) and the
//   JS optimizer's decoding of it. Contains real chat data: keep it out of git.
//
// --download: fetch the first image/file found in the chat history via
//   GET {server}/fileDownload?fileName&time&id&gid=<userId>&sid=md5(sessionID+fileName)
//
// --optimizer: the JSON optimizer class (scheme-based packet packer) lifted
// from the 9.x client. Required when serverInfo returns an apiScheme.
//
// The password is read from XX_PASSWORD or asked for on stdin (not echoed).

import crypto from 'node:crypto';
import readline from 'node:readline';
import { createRequire } from 'node:module';
import fs from 'node:fs';
import path from 'node:path';

const args = parseArgs(process.argv.slice(2));
if (!args.server || !args.account) {
  console.error(
    'Usage: node --experimental-websocket tool/xuanxuan_probe.mjs ' +
      '--server https://host:11443 --account <user> ' +
      '[--server-name <name>] [--insecure] [--info-only] [--optimizer <path.cjs>] ' +
      '[--chat <gid>] [--send "text"] [--listen 60]',
  );
  process.exit(2);
}
// xxd is commonly deployed with a self-signed certificate.
if (args.insecure) process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

const server = new URL(args.server);
if (!server.port) server.port = '11443';
const serverName = args['server-name'] ?? '';
const password = process.env.XX_PASSWORD ?? (await askHidden('Password: '));
const passwordMd5 = crypto.createHash('md5').update(password).digest('hex');

// ---- Step 1: serverInfo ----------------------------------------------------
const infoUrl = `${server.origin}/serverInfo`;
console.log(`\n[1] POST ${infoUrl}`);
const body = JSON.stringify({
  method: 'sysgetserverinfo',
  params: [serverName, args.account, passwordMd5, ''],
  version: '9.1.2',
  device: 'desktop',
  lang: 'en',
});

let info;
try {
  const res = await fetch(infoUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8' },
    body: `data=${encodeURIComponent(body)}`,
  });
  const text = await res.text();
  console.log(`    HTTP ${res.status}`);
  try {
    info = JSON.parse(text);
  } catch {
    console.log('    Response is not JSON:\n' + text.slice(0, 1000));
    process.exit(1);
  }
} catch (e) {
  console.error(`    Request failed: ${e.cause?.code ?? ''} ${e.message}`);
  console.error('    Check the host/port, firewall, and try --insecure for self-signed certs.');
  process.exit(1);
}

const { apiScheme, ...infoShown } = info;
if (apiScheme) infoShown.apiScheme = `<${Object.keys(apiScheme).length} entries, $version=${apiScheme.$version}>`;
console.log('    Response:', JSON.stringify(redact(infoShown), null, 2).replace(/\n/g, '\n    '));
if (!info?.token) {
  console.log('\n    No token in response -> login rejected or protocol changed.');
  process.exit(1);
}
if (args['info-only']) process.exit(0);

// ---- Step 2: WebSocket + encrypted chat/login ------------------------------
if (typeof WebSocket === 'undefined') {
  console.error('\nWebSocket unavailable: rerun with `node --experimental-websocket` (Node 20) or Node 22+.');
  process.exit(1);
}

const key = Buffer.from(info.token, 'utf8');
const iv = Buffer.from(info.token.substring(0, 16), 'utf8');
const aes = !!info.enableClientAES;
const encrypt = (s) => {
  const c = crypto.createCipheriv('aes-256-cbc', key, iv);
  return Buffer.concat([c.update(s, 'utf8'), c.final()]);
};
const decrypt = (buf) => {
  const d = crypto.createDecipheriv('aes-256-cbc', key, iv);
  return Buffer.concat([d.update(buf), d.final()]).toString('utf8');
};

if (args['dump-scheme'] && info.apiScheme) {
  fs.writeFileSync(args['dump-scheme'], JSON.stringify(info.apiScheme, null, 2) + '\n');
  console.log(`    apiScheme written to ${args['dump-scheme']}`);
}

// 9.x servers pack every socket packet with the scheme from serverInfo.
let optimizer = null;
if (info.apiScheme) {
  if (!args.optimizer) {
    console.error('\nServer uses apiScheme packing: rerun with --optimizer <xx_optimizer.cjs>.');
    process.exit(1);
  }
  const Optimizer = createRequire(import.meta.url)(args.optimizer);
  optimizer = new Optimizer(info.apiScheme);
}
const pack = (req) => {
  const full = { version: '9.1.2', device: 'desktop', lang: 'en', ...req, method: req.method.toLowerCase() };
  if (!optimizer) return JSON.stringify(full);
  const encoded = optimizer.encodeToJSON(`${full.method}Request`, full, 'requestPack');
  // The client prepends serverName to the login packet (xxd >= 3.1).
  return full.method === 'userlogin' ? serverName + encoded : encoded;
};
const unpack = (data) => (optimizer && Array.isArray(data) ? optimizer.decode(data, null, 'responsePack') : data);

const socketUrl = info.socketUrl || defaultSocketUrl(server, info.chatPort);
console.log(`\n[2] WebSocket ${socketUrl}  (AES ${aes ? 'on' : 'off'})`);
const ws = new WebSocket(socketUrl);
ws.binaryType = 'arraybuffer';

const listenSeconds = Number(args.listen ?? 60);
let me = null;
let sessionID = null;
let chats = [];
let timer = null;
const send = (req) => {
  const text = pack({ ...req, ...(me ? { userID: me.id } : {}) });
  ws.send(aes ? encrypt(text) : text);
};

ws.addEventListener('open', () => {
  console.log('    Connected. Sending userLogin…');
  send({
    method: 'userLogin',
    params: [serverName, args.account, passwordMd5, { status: 'online', simple: false }],
    rid: `login_desktop_${args.account}`,
  });
});

ws.addEventListener('message', (ev) => {
  let text;
  if (typeof ev.data === 'string') {
    text = ev.data;
  } else if (!aes) {
    text = Buffer.from(ev.data).toString('utf8');
  } else {
    try {
      text = decrypt(Buffer.from(ev.data));
    } catch (e) {
      console.log(`    <binary ${ev.data.byteLength}B, decrypt failed: ${e.message}>`);
      return;
    }
  }
  const packets = parsePackets(text);
  if (args['dump-frames']) dumpFrame(text, packets);
  for (const p of packets) handlePacket(p);
});

ws.addEventListener('error', (ev) => console.error('    Socket error:', ev.message ?? ev.error?.message ?? ev));
ws.addEventListener('close', (ev) => {
  clearTimeout(timer);
  console.log(`    Closed (code ${ev.code}${ev.reason ? `, ${ev.reason}` : ''}).`);
});

function handlePacket(p) {
  const api = (p.module && p.module !== 'im' ? `${p.module}/` : '') + p.method;
  const tag = `    <- ${api}  result=${p.result ?? '-'}` + (p.message ? `  message=${p.message}` : '');
  switch (p.method?.toLowerCase()) {
    case 'userlogin':
      console.log(tag);
      if (p.result === 'success' && !me) {
        me = p.data;
        console.log(`       logged in as #${me.id} ${me.account} (${me.realname})`);
      }
      return;
    case 'chatgetlist':
      chats = Array.isArray(p.data) ? p.data : [];
      console.log(`${tag}  ${chats.length} chats`);
      if (chats[0]) console.log(`       chat fields: ${Object.keys(chats[0]).join(', ')}`);
      for (const c of chats.slice(0, 15)) console.log('       ' + describeChat(c));
      if (chats.length > 15) console.log(`       … ${chats.length - 15} more`);
      return;
    case 'syssessionid':
      sessionID = (typeof p.data === 'string' && p.data) || p.sessionID || null;
      console.log(`${tag}  sessionID ${sessionID ? `${sessionID.slice(0, 4)}…(${sessionID.length} chars)` : 'missing'}`);
      afterLogin();
      return;
    case 'chatgetmessageinfo': {
      console.log(`${tag}  ${JSON.stringify(p.data)}`);
      const last = p.data?.lastMessage;
      if (last) send({ method: 'messageSync', params: [targetChat, last, true, 10, false] });
      return;
    }
    case 'messagesync': {
      const list = Array.isArray(p.data) ? p.data : [];
      console.log(`${tag}  ${list.length} messages (newest page)`);
      if (list[0] && typeof list[0] === 'object') console.log(`       message fields: ${Object.keys(list[0]).join(', ')}`);
      for (const m of list) console.log('       ' + describeMessage(m));
      if (args.download) downloadFirstFile(list);
      return;
    }
    case 'messagesend': {
      const list = Array.isArray(p.data) ? p.data : p.data ? [p.data] : [];
      console.log(`${tag}  ${list.length} message(s) pushed`);
      for (const m of list) console.log('       ' + describeMessage(m));
      return;
    }
    default: {
      const size = Array.isArray(p.data) ? `${p.data.length} items` : typeof p.data;
      console.log(`${tag}  data=${size}`);
    }
  }
}

let targetChat = null;
function afterLogin() {
  if (!me) return;
  targetChat = args.chat ?? chats[0]?.gid;
  if (targetChat) {
    console.log(`\n[3] History of chat ${targetChat}`);
    send({ method: 'chatGetMessageInfo', params: [targetChat] });
  }
  if (args.send && targetChat) {
    if (!args.chat) {
      console.log('    --send needs an explicit --chat <gid>; not sending.');
    } else {
      console.log(`\n[4] Sending a text message to ${targetChat}`);
      send({
        method: 'messagesend',
        params: [[{
          gid: crypto.randomUUID(),
          cgid: targetChat,
          type: 'normal',
          contentType: 'plain',
          content: String(args.send),
          user: me.id,
          data: '',
          deleted: false,
        }]],
      });
    }
  }
  console.log(`\n[5] Listening for pushed messages for ${listenSeconds}s (send yourself a message from another client)…`);
  timer = setTimeout(() => {
    console.log('\n    Done. Closing.');
    ws.close();
  }, listenSeconds * 1000);
}

async function downloadFirstFile(messages) {
  const msg = messages.find((m) => m?.contentType === 'image' || m?.contentType === 'file');
  if (!msg) {
    console.log('\n[6] No image/file message on this page; try another --chat.');
    return;
  }
  let file;
  try {
    file = JSON.parse(msg.content);
  } catch {
    console.log(`\n[6] Message #${msg.id} content is not JSON: ${String(msg.content).slice(0, 120)}`);
    return;
  }
  if (!sessionID) {
    console.log('\n[6] No sessionID from syssessionid; cannot sign the download.');
    return;
  }
  const params = new URLSearchParams({
    fileName: file.name,
    time: String(Math.floor(Number(file.time) / 1000)),
    id: String(file.id),
    gid: String(me.id),
    sid: crypto.createHash('md5').update(sessionID + file.name).digest('hex'),
  });
  if (serverName) params.set('ServerName', serverName);
  const url = `${server.origin}/fileDownload?${params}`;
  console.log(`\n[6] Download file #${file.id} "${file.name}" (${file.size} B) from message #${msg.id}`);
  console.log(`    GET ${server.origin}/fileDownload?fileName=…&time=${params.get('time')}&id=${file.id}&gid=${me.id}&sid=…`);
  try {
    const res = await fetch(url);
    const buf = Buffer.from(await res.arrayBuffer());
    console.log(`    HTTP ${res.status}  ${res.headers.get('content-type')}  ${buf.length} B` +
      (file.size ? `  (expected ${file.size} B${buf.length === Number(file.size) ? ', match' : ''})` : ''));
    if (res.ok && buf.length) {
      fs.mkdirSync(args.download, { recursive: true });
      const out = path.join(args.download, `${file.id}_${path.basename(file.name)}`);
      fs.writeFileSync(out, buf);
      console.log(`    Saved to ${out}`);
    } else {
      console.log(`    Body: ${buf.toString('utf8').slice(0, 300)}`);
    }
  } catch (e) {
    console.log(`    Download failed: ${e.cause?.code ?? ''} ${e.message}`);
  }
}

let frameNo = 0;
function dumpFrame(raw, decoded) {
  fs.mkdirSync(args['dump-frames'], { recursive: true });
  const base = path.join(args['dump-frames'], String(++frameNo).padStart(3, '0'));
  fs.writeFileSync(`${base}.raw.json`, raw);
  fs.writeFileSync(`${base}.decoded.json`, JSON.stringify(decoded.length === 1 ? decoded[0] : decoded));
}

// ---- helpers ---------------------------------------------------------------
function parsePackets(text) {
  let raw;
  try {
    raw = JSON.parse(text);
  } catch {
    console.log('    <non-JSON>', text.slice(0, 300));
    return [];
  }
  try {
    // A packed packet is itself an array ([schemeName, values]); a batch is an array of those.
    if (optimizer && Array.isArray(raw)) {
      const isBatch = raw.length && Array.isArray(raw[0]);
      return (isBatch ? raw : [raw]).map(unpack);
    }
  } catch (e) {
    console.log(`    <decode failed: ${e.message}>`, text.slice(0, 300));
    return [];
  }
  return Array.isArray(raw) ? raw : [raw];
}

function describeChat(c) {
  const members = Array.isArray(c.members) ? `${c.members.length} members` : '';
  return [c.gid, c.type, JSON.stringify(c.name ?? ''), members, c.lastActiveTime ? `active ${fmtDate(c.lastActiveTime)}` : '']
    .filter(Boolean)
    .join('  ');
}

function describeMessage(m) {
  if (typeof m !== 'object' || !m) return JSON.stringify(m);
  const body = String(m.content ?? '').replace(/\s+/g, ' ');
  return `#${m.id ?? '?'} ${fmtDate(m.date)} user=${m.user} [${m.contentType}] ${body.slice(0, 80)}${body.length > 80 ? '…' : ''}`;
}

function fmtDate(d) {
  if (!d) return '-';
  const n = Number(d);
  const date = new Date(n < 1e12 ? n * 1000 : n);
  return Number.isNaN(date.getTime()) ? String(d) : date.toISOString().replace('T', ' ').slice(0, 19);
}

function defaultSocketUrl(url, port) {
  const u = new URL(url);
  u.protocol = u.protocol === 'https:' ? 'wss:' : 'ws:';
  u.pathname = '/ws';
  u.port = String(port ?? 11444);
  return u.toString();
}

function redact(obj) {
  return JSON.parse(
    JSON.stringify(obj, (k, v) =>
      /token|password|key/i.test(k) && typeof v === 'string' ? `${v.slice(0, 4)}…(${v.length} chars)` : v,
    ),
  );
}

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith('--')) continue;
    const name = a.slice(2);
    const next = argv[i + 1];
    if (next === undefined || next.startsWith('--')) out[name] = true;
    else out[name] = argv[++i];
  }
  return out;
}

function askHidden(prompt) {
  return new Promise((resolve) => {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout, terminal: true });
    rl._writeToOutput = (s) => {
      if (s.includes(prompt)) rl.output.write(prompt);
    };
    rl.question(prompt, (answer) => {
      rl.close();
      process.stdout.write('\n');
      resolve(answer);
    });
  });
}
