// Minimal read-only LMDB (data format v1, 64-bit) reader.
// ObjectBox writes classic LMDB v1 files, which lmdb-js (built on LMDB 1.x) refuses to open,
// so we walk the B-tree ourselves on an in-memory snapshot of the file.
import fs from 'node:fs';

const P_BRANCH = 0x01;
const P_LEAF = 0x02;
const P_META = 0x08;
const P_LEAF2 = 0x20;
const F_BIGDATA = 0x01;
const F_SUBDATA = 0x02;
const PAGEHDRSZ = 16;
const META_MAGIC = 0xbeefc0de;

function readDb(buf, off) {
  return {
    pad: buf.readUInt32LE(off),
    flags: buf.readUInt16LE(off + 4),
    depth: buf.readUInt16LE(off + 6),
    entries: Number(buf.readBigUInt64LE(off + 32)),
    root: Number(buf.readBigUInt64LE(off + 40)),
  };
}

// Pages are read on demand: on Windows LMDB pre-sizes data.mdb to the full map size (often 1 GB+),
// so slurping the file would be wasteful. Each page is cached as its own Buffer.
export class LmdbSnapshot {
  constructor(filePath) {
    this.fd = fs.openSync(filePath, 'r');
    this.size = fs.fstatSync(this.fd).size;
    this.cache = new Map();
    try {
      const head = this.#read(0, PAGEHDRSZ + 32);
      if (head.readUInt32LE(PAGEHDRSZ) !== META_MAGIC) throw new Error('Not an LMDB v1 file');
      this.pageSize = head.readUInt32LE(PAGEHDRSZ + 24);
      const metas = [];
      for (const pg of [0, 1]) {
        const b = this.#read(pg * this.pageSize, PAGEHDRSZ + 160);
        if (b.readUInt32LE(PAGEHDRSZ) !== META_MAGIC || !(b.readUInt16LE(10) & P_META)) continue;
        const m = PAGEHDRSZ;
        metas.push({
          version: b.readUInt32LE(m + 4),
          mainDb: readDb(b, m + 24 + 48),
          txnid: b.readBigUInt64LE(m + 24 + 96 + 8),
        });
      }
      metas.sort((a, b) => (a.txnid > b.txnid ? -1 : 1));
      this.meta = metas[0];
      if (!this.meta || this.meta.version !== 1) throw new Error('Unsupported LMDB meta/version');
    } catch (e) {
      this.close();
      throw e;
    }
  }

  close() {
    if (this.fd !== undefined) fs.closeSync(this.fd);
    this.fd = undefined;
    this.cache.clear();
  }

  #read(pos, len) {
    const b = Buffer.alloc(len);
    const n = fs.readSync(this.fd, b, 0, len, pos);
    if (n !== len) throw new Error(`Short read at ${pos} (file changed while reading?)`);
    return b;
  }

  /** The page (plus any following overflow pages) as its own Buffer. */
  page(pgno, count = 1) {
    let b = this.cache.get(pgno);
    if (!b || b.length < count * this.pageSize) {
      b = this.#read(pgno * this.pageSize, count * this.pageSize);
      this.cache.set(pgno, b);
    }
    return b;
  }

  /** Iterate all [key, value] Buffers of a DB (main DB by default) in key order. */
  *entries(db = this.meta.mainDb) {
    if (db.root === -1 || db.entries === 0 || db.root > 0xffffffffffff) return;
    yield* this.#walk(db.root);
  }

  *#walk(pgno) {
    const b = this.page(pgno);
    const p = 0;
    const flags = b.readUInt16LE(p + 10);
    const lower = b.readUInt16LE(p + 12);
    const n = (lower - PAGEHDRSZ) >> 1;
    if (flags & P_LEAF2) throw new Error('LEAF2 pages (DUPFIXED) not supported');
    for (let i = 0; i < n; i++) {
      const node = p + b.readUInt16LE(p + PAGEHDRSZ + i * 2);
      const lo = b.readUInt16LE(node);
      const hi = b.readUInt16LE(node + 2);
      const nflags = b.readUInt16LE(node + 4);
      const ksize = b.readUInt16LE(node + 6);
      const key = b.subarray(node + 8, node + 8 + ksize);
      if (flags & P_BRANCH) {
        yield* this.#walk(lo + hi * 0x10000 + nflags * 0x100000000);
      } else if (flags & P_LEAF) {
        const dsize = lo + hi * 0x10000;
        const dOff = node + 8 + ksize;
        if (nflags & F_SUBDATA) continue; // named sub-DB / dupsort: not used by ObjectBox data
        let value;
        if (nflags & F_BIGDATA) {
          const pages = Math.ceil((PAGEHDRSZ + dsize) / this.pageSize);
          const ov = this.page(Number(b.readBigUInt64LE(dOff)), pages);
          value = ov.subarray(PAGEHDRSZ, PAGEHDRSZ + dsize);
        } else {
          value = b.subarray(dOff, dOff + dsize);
        }
        yield [key, value];
      }
    }
  }
}
