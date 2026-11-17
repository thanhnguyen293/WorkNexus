// Starts the MCP server over stdio and calls each tool once. Usage: node test/mcp-smoke.mjs [conversation]
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';

const transport = new StdioClientTransport({ command: process.execPath, args: [process.env.MCP_SERVER ?? 'src/server.js'], env: process.env });
const client = new Client({ name: 'smoke', version: '0' });
await client.connect(transport);
console.log('tools:', (await client.listTools()).tools.map((t) => t.name).join(', '));
const call = async (name, args) => {
  const r = await client.callTool({ name, arguments: args });
  const text = r.content[0].text;
  console.log(`\n${name} ${JSON.stringify(args)} -> ${r.isError ? 'ERROR ' : ''}${text.length} chars`);
  return r.isError ? text : JSON.parse(text);
};
const list = await call('list_conversations', { app: 'tbchat', limit: 3 });
console.log(list.conversations.map((c) => `${c.name} (${c.type})`));
const read = await call('read_messages', { app: 'tbchat', conversation: list.conversations[0].name, limit: 2 });
console.log(read.messages.map((m) => `${m.time} ${m.from} [${m.type}] len=${m.text.length}`));
const s = await call('search_messages', { app: 'tbchat', query: 'test', limit: 3 });
console.log('hits', s.total);
const zl = await call('list_conversations', { app: 'zentao', limit: 3 });
console.log(typeof zl === 'string' ? zl : { source: zl.source, newest: zl.newestMessageInCache, chats: zl.conversations.map((c) => c.name) });
const zs = await call('search_messages', { app: 'zentao', query: 'build', limit: 2 });
console.log(typeof zs === 'string' ? zs : { total: zs.total });
console.log(await call('send_message', { app: 'tbchat', conversation: 'x', text: 'y' }));
await client.close();
