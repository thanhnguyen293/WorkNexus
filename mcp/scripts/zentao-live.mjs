// Read-only check against a real ZenTao server, using ZENTAO_* env vars. Sends nothing.
import { listConversations, readMessages } from '../src/zentao.js';

const list = await listConversations({ limit: 5 });
console.log(`Logged in as ${list.me}. ${list.conversations.length} recent chats:`);
for (const c of list.conversations) console.log(`- ${c.name} [${c.type}] ${c.lastTime ?? ''}`);
if (list.warning) console.log('WARNING:', list.warning);
if (list.conversations[0]) {
  const r = await readMessages({ conversation: list.conversations[0].gid, limit: 3 });
  console.log(`\nLast ${r.messages.length} messages in "${r.conversation}":`);
  for (const m of r.messages) console.log(`  ${m.time} ${m.from}: ${m.text.slice(0, 80)}`);
}
process.exit(0);
