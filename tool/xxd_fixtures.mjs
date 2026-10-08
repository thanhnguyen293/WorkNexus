#!/usr/bin/env node
// Generate the golden fixtures that pin the Dart xxd protocol code
// (lib/features/chat/data/datasources/xxd/) to the original JS client.
//
//   node tool/xxd_fixtures.mjs --scheme <api_scheme.json> --optimizer <xx_optimizer.cjs>
//
// --scheme:    serverInfo.apiScheme dumped by `xuanxuan_probe.mjs --dump-scheme`.
// --optimizer: the JSONOptimizer class lifted from zentaoclient (see the probe).
//
// Every value is synthetic: no chat data from the server ends up in the repo.
// Output goes to test/fixtures/xxd/.

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const args = Object.fromEntries(
  process.argv.slice(2).reduce((acc, a, i, all) => {
    if (a.startsWith('--')) acc.push([a.slice(2), all[i + 1]]);
    return acc;
  }, []),
);
if (!args.scheme || !args.optimizer) {
  console.error('Usage: node tool/xxd_fixtures.mjs --scheme <file> --optimizer <file>');
  process.exit(2);
}

const outDir = path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'test', 'fixtures', 'xxd');
fs.mkdirSync(outDir, { recursive: true });

const scheme = JSON.parse(fs.readFileSync(args.scheme, 'utf8'));
const Optimizer = createRequire(import.meta.url)(path.resolve(args.optimizer));
const fresh = () => new Optimizer(structuredClone(scheme));
const write = (name, value, { compact = false } = {}) => {
  fs.writeFileSync(path.join(outDir, name), JSON.stringify(value, null, compact ? 0 : 1) + '\n');
  console.log(`wrote ${name}`);
};

write('api_scheme.json', scheme);

// ---- codec cases -----------------------------------------------------------
const VARIANTS = 4;
const names = Object.keys(scheme).filter((n) => !n.startsWith('$')).sort();

function sample(opt, s, variant, depth, label) {
  if (depth > 4) return undefined;
  if (s.map) {
    const values = Array.isArray(s.map) ? s.map : Object.values(s.map);
    if (values.length) return values[(variant + depth) % values.length];
  }
  switch (s.type) {
    case 'object': {
      if (!s.props?.length) return {};
      const out = {};
      s.props.forEach((p, i) => {
        if (variant === 1 && i % 2 === 1) return; // sparse: leave every other prop undefined
        if (variant === 2 && i % 3 === 0) {
          out[p.name] = null;
          return;
        }
        if (variant === 3) return; // empty object: everything takes defaults
        const v = sample(opt, p, variant, depth + 1, `${label}.${p.name}`);
        if (v !== undefined) out[p.name] = v;
      });
      return out;
    }
    case 'array': {
      const item = s.arrType && opt.getDataScheme(s.arrType);
      if (!item || variant === 3) return [];
      // Two items at the top level, one deeper down: enough coverage, small fixtures.
      return (depth === 0 ? [0, 1] : [0]).map((k) => sample(opt, item, variant + k, depth + 1, `${label}[]`)).filter((v) => v !== undefined);
    }
    case 'string':
      return [`${label}`, `Tiếng Việt ✓ ${variant}`, '中文消息', ''][variant % 4];
    case 'number':
      return [7, 0, 1.5, 1791196839774][variant % 4];
    case 'boolean':
      return variant % 2 === 0;
    default:
      return [{ k: 'v', n: 1 }, 'any-text', 42, [1, 'two']][variant % 4];
  }
}

// Turn leaf numbers into strings and vice versa, to exercise decode coercion.
function mutate(v, depth = 0) {
  if (Array.isArray(v)) return v.map((x, i) => (i % 2 === depth % 2 ? mutate(x, depth + 1) : x));
  if (typeof v === 'number' && Number.isInteger(v)) return String(v);
  if (v === true) return 1;
  if (v === false) return 'false';
  return v;
}

const codecCases = [];
for (const name of names) {
  const opt = fresh();
  let s;
  try {
    s = opt.getDataScheme(name);
  } catch (e) {
    codecCases.push({ name, schemeError: true });
    continue;
  }
  if (!s) continue;
  for (let variant = 0; variant < VARIANTS; ++variant) {
    const input = sample(opt, s, variant, 0, name);
    const c = { name, variant, input };
    try {
      c.encoded = opt.encode(name, input);
    } catch (e) {
      c.encodeError = e.message;
      codecCases.push(c);
      continue;
    }
    try {
      c.decoded = fresh().decode(JSON.parse(JSON.stringify(c.encoded)));
    } catch (e) {
      c.decodeError = e.message;
    }
    // Same payload addressed by scheme index instead of name.
    c.index = opt.getSchemeIndexByName(name);
    // Coercion cases only for the full variant: they double the fixture size.
    if (variant === 0) try {
      const mutated = [name, mutate(JSON.parse(JSON.stringify(c.encoded[1])))];
      c.mutated = mutated;
      c.mutatedDecoded = fresh().decode(mutated);
    } catch (e) {
      c.mutatedDecodeError = e.message;
    }
    codecCases.push(JSON.parse(JSON.stringify(c)));
  }
}
// Fallback: an unknown request name packs with `requestPack`.
{
  const opt = fresh();
  const input = { version: '9.1.2', device: 'desktop', lang: 'en', method: 'notinscheme', params: ['a', 1], rid: 'r1', userID: 40 };
  try {
    codecCases.push({ name: 'notinschemeRequest', fallback: 'requestPack', input, encoded: opt.encode('notinschemeRequest', input, 'requestPack') });
  } catch (e) {
    codecCases.push({ name: 'notinschemeRequest', fallback: 'requestPack', input, encodeError: e.message });
  }
}
write('codec_cases.json', { schemeVersion: scheme.$version, cases: codecCases }, { compact: true });

// ---- edge cases: a synthetic scheme that hits every optimizer branch -------
const edgeScheme = {
  $version: 'edge-1',
  $omitDefaultProps: true,
  $validation: true,
  base: { type: 'object', props: [{ name: 'a', type: 'string', default: 'A' }, { name: 'b', type: 'number' }, { name: 'c', type: 'boolean', default: false }] },
  child: { type: 'object', extend: 'base', props: [{ name: 'b', type: 'string', default: 'B' }, { name: 'd', type: 'status' }] },
  status: { type: 'string', map: ['online', 'away', 'offline', { custom: 1 }] },
  kind: { type: 'string', map: { n: 'normal', b: 'broadcast', '7': 'seven' } },
  alias: { type: 'child' },
  list: { type: 'object', props: [{ name: 'items', type: 'array', arrType: 'child' }, { name: 'tags', type: 'array', arrType: 'kind' }, { name: 'free', type: 'any' }] },
  strict: { type: 'object', props: [{ name: 'id', type: 'number', required: true }, { name: 'code', type: 'string', match: '^[A-Z]+$' }] },
  requestPack: { type: 'object', props: [{ name: 'method', type: 'string' }, { name: 'params', type: 'any' }] },
};
const edgeInputs = [
  ['base', { a: 'A', b: 1, c: false }],
  ['base', { a: 'x' }],
  ['base', {}],
  ['base', { a: null, b: 2, c: true }],
  ['base', { a: 'A', b: undefined, c: null }],
  ['child', { a: 'q', b: 'B', c: true, d: 'away' }],
  ['child', { d: { custom: 1 } }],
  ['child', { d: 'unknown-status' }],
  ['alias', { a: 'via alias', d: 'offline' }],
  ['kind', 'broadcast'],
  ['kind', 'seven'],
  ['kind', 'other'],
  ['status', null],
  ['list', { items: [{ a: 'i1' }, { b: 'B', d: 'online' }], tags: ['normal', 'zzz'], free: { deep: [1, { x: null }] } }],
  ['list', { items: [], tags: [] }],
  ['strict', { id: 5, code: 'ABC' }],
  ['strict', { code: 'ABC' }],
  ['strict', { id: 5, code: 'abc' }],
  ['strict', { id: 'not a number' }],
  ['unknownRequest', { method: 'x', params: [1] }, 'requestPack'],
];
const edgeCases = edgeInputs.map(([name, input, fallback]) => {
  const c = { name, input: input === undefined ? null : input };
  if (fallback) c.fallback = fallback;
  try {
    c.encoded = new Optimizer(structuredClone(edgeScheme)).encode(name, input, fallback);
    c.decoded = new Optimizer(structuredClone(edgeScheme)).decode(JSON.parse(JSON.stringify(c.encoded)), null, fallback);
  } catch (e) {
    c.error = e.message;
  }
  return JSON.parse(JSON.stringify(c));
});
const edgeDecodes = [
  ['base', ['x', '12.5abc', 'true']],
  ['base', [5, '', 0]],
  ['base', [true, 'nope', 'TRUE']],
  ['base', ['only']],
  ['child', ['a', 'b', 2, '1']],
  ['child', ['a', 'b', 1, 3]],
  ['kind', '7'],
  ['kind', 7],
  ['status', '2'],
  ['status', 2.0],
  ['status', 9],
  ['list', [[['a']], ['n', 'b', 'x'], 'free']],
].map(([name, payload]) => {
  const c = { encoded: [name, payload] };
  try {
    c.decoded = new Optimizer(structuredClone(edgeScheme)).decode(c.encoded);
  } catch (e) {
    c.error = e.message;
  }
  return JSON.parse(JSON.stringify(c));
});
const edgeOpt = new Optimizer(structuredClone(edgeScheme));
write('edge_cases.json', {
  scheme: edgeScheme,
  cases: edgeCases,
  decodes: edgeDecodes,
  index: { name: 'kind', index: edgeOpt.getSchemeIndexByName('kind') },
});

// ---- frame cases (request envelopes the client actually sends) -------------
const frameRequests = [
  { method: 'userLogin', params: ['', 'demo', 'e10adc3949ba59abbe56e057f20f883e', { status: 'online', simple: false }], rid: 'login_desktop_demo' },
  { method: 'chatGetMessageInfo', params: ['54cc78e8-0000-4000-8000-000000000001'], userID: 40 },
  { method: 'messageSync', params: ['54cc78e8-0000-4000-8000-000000000001', 195017, true, 10, false], userID: 40, rid: 'r-sync' },
  {
    method: 'messagesend',
    params: [[{ gid: '0b9f1d2e-0000-4000-8000-000000000002', cgid: '40&xuanbot', type: 'normal', contentType: 'plain', content: 'xin chào 你好', user: 40, data: '', deleted: false }]],
    userID: 40,
  },
  { method: 'ping', userID: 40 },
];
const frameCases = frameRequests.map((r) => {
  const opt = fresh();
  const data = { version: '9.1.2', device: 'desktop', lang: 'vi', method: r.method.toLowerCase() };
  if (r.params !== undefined) data.params = r.params;
  if (r.rid !== undefined) data.rid = r.rid;
  if (r.userID !== undefined) data.userID = r.userID;
  const packed = opt.encodeToJSON(`${data.method}Request`, data, 'requestPack');
  return { request: r, serverName: '', text: packed };
});
write('frame_cases.json', { clientVersion: '9.1.2', lang: 'vi', device: 'desktop', cases: frameCases });

// ---- cipher cases ----------------------------------------------------------
const token = '0123456789abcdef0123456789abcdef';
const cipherCases = ['', 'a', 'exactly16bytes!!', '{"method":"ping"}', 'Tiếng Việt và 中文 ✓'.repeat(5)].map((plain) => {
  const c = crypto.createCipheriv('aes-256-cbc', token, token.substring(0, 16));
  return { plain, cipherBase64: Buffer.concat([c.update(plain, 'utf8'), c.final()]).toString('base64') };
});
write('cipher_cases.json', { token, cases: cipherCases });
