// Bundles the MCP server into one file the app ships as an asset (no node_modules needed).
// Usage: npm run build            -> writes ../assets/mcp/worknexus-mcp.mjs
//        npm run build -- --check -> fails if that file is not what the sources build to
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { build } from 'esbuild';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const outfile = path.join(root, '..', 'assets', 'mcp', 'worknexus-mcp.mjs');

const result = await build({
  entryPoints: [path.join(root, 'src', 'server.js')],
  bundle: true,
  minify: true,
  platform: 'node',
  format: 'esm',
  target: 'node22',
  legalComments: 'none',
  // ws's optional native speed-ups; it falls back to JS without them.
  external: ['bufferutil', 'utf-8-validate'],
  // Bundled CommonJS deps (ws) call require(), which ESM output lacks.
  banner: {
    js: "// Generated from mcp/ by 'npm run build'. Do not edit.\nimport { createRequire as __createRequire } from 'node:module';\nconst require = __createRequire(import.meta.url);",
  },
  write: false,
});
const code = result.outputFiles[0].contents;

if (process.argv.includes('--check')) {
  const current = fs.existsSync(outfile) ? fs.readFileSync(outfile) : Buffer.alloc(0);
  if (!current.equals(Buffer.from(code))) {
    console.error(`${path.relative(process.cwd(), outfile)} is out of date: run "npm run build" in mcp/ and commit it.`);
    process.exit(1);
  }
  console.log('Bundled MCP server is up to date.');
} else {
  fs.mkdirSync(path.dirname(outfile), { recursive: true });
  fs.writeFileSync(outfile, code);
  console.log(`Wrote ${path.relative(process.cwd(), outfile)} (${(code.length / 1024).toFixed(0)} KB)`);
}
