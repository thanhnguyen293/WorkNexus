// Decodes ObjectBox objects (FlatBuffers) from an LMDB snapshot using the app's objectbox-model.json.
import fs from 'node:fs';
import { LmdbSnapshot } from './lmdb.js';

// ObjectBox stores entity objects under a 4-byte big-endian key prefix: 0x18000000 | (entityId << 2).
const OBJECT_PREFIX = 0x18000000;

// ObjectBox property type codes (see objectbox OBXPropertyType).
const T = { Bool: 1, Byte: 2, Short: 3, Char: 4, Int: 5, Long: 6, Float: 7, Double: 8, String: 9, Date: 10, Relation: 11, DateNano: 12, ByteVector: 23, StringVector: 30 };

/** Indexes an objectbox-model.json (parsed object, or a path to read it from) by entity name. */
export function loadModel(modelOrPath) {
  const raw = typeof modelOrPath === 'string' ? JSON.parse(fs.readFileSync(modelOrPath, 'utf8')) : modelOrPath;
  const entities = {};
  for (const e of raw.entities) {
    entities[e.name] = {
      id: Number(e.id.split(':')[0]),
      props: e.properties.map((p) => ({ id: Number(p.id.split(':')[0]), name: p.name, type: p.type })),
    };
  }
  return entities;
}

function readField(buf, table, vt, vtSize, prop) {
  const slot = 4 + (prop.id - 1) * 2;
  if (slot + 2 > vtSize) return undefined;
  const fo = buf.readUInt16LE(vt + slot);
  if (!fo) return undefined;
  const at = table + fo;
  const str = (pos) => {
    const s = pos + buf.readUInt32LE(pos);
    return buf.toString('utf8', s + 4, s + 4 + buf.readUInt32LE(s));
  };
  switch (prop.type) {
    case T.Bool: return buf.readUInt8(at) !== 0;
    case T.Byte: return buf.readInt8(at);
    case T.Short: case T.Char: return buf.readInt16LE(at);
    case T.Int: return buf.readInt32LE(at);
    case T.Float: return buf.readFloatLE(at);
    case T.Double: return buf.readDoubleLE(at);
    case T.Long: case T.Date: case T.DateNano: case T.Relation: return Number(buf.readBigInt64LE(at));
    case T.String: return str(at);
    case T.StringVector: {
      const v = at + buf.readUInt32LE(at);
      const n = buf.readUInt32LE(v);
      return Array.from({ length: n }, (_, i) => str(v + 4 + i * 4));
    }
    case T.ByteVector: {
      const v = at + buf.readUInt32LE(at);
      return buf.subarray(v + 4, v + 4 + buf.readUInt32LE(v));
    }
    default: return undefined;
  }
}

export function decode(buf, entity) {
  const table = buf.readUInt32LE(0);
  const vt = table - buf.readInt32LE(table);
  const vtSize = buf.readUInt16LE(vt);
  const obj = {};
  for (const p of entity.props) {
    const v = readField(buf, table, vt, vtSize, p);
    if (v !== undefined) obj[p.name] = v;
  }
  return obj;
}

export class ObjectBoxReader {
  constructor(dataMdbPath, model) {
    this.snap = new LmdbSnapshot(dataMdbPath);
    this.model = model;
  }

  close() {
    this.snap.close();
  }

  /** All objects of an entity, decoded. Small DBs only: this scans the whole main tree once per call. */
  all(entityName) {
    const e = this.model[entityName];
    if (!e) throw new Error(`Unknown entity ${entityName}`);
    const prefix = (OBJECT_PREFIX | (e.id << 2)) >>> 0;
    const out = [];
    for (const [k, v] of this.snap.entries()) {
      if (k.length >= 4 && k.readUInt32BE(0) === prefix) out.push(decode(v, e));
    }
    return out;
  }
}
