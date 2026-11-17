// Sends one text message through the ZenTao server, using ZENTAO_* env vars.
// Usage: node test/zentao-send.mjs "<conversation name or gid>" "<text>"
import { sendMessage } from '../src/zentao.js';

const [conversation, text] = process.argv.slice(2);
if (!conversation || !text) {
  console.error('Usage: node test/zentao-send.mjs "<conversation name or gid>" "<text>"');
  process.exit(2);
}
try {
  const r = await sendMessage({ conversation, text });
  console.log(r.sent ? `Sent to "${r.conversation}" (${r.gid}) at ${r.message?.time}` : `Server did not confirm the message: ${JSON.stringify(r)}`);
  process.exit(r.sent ? 0 : 1);
} catch (e) {
  console.error('Send failed:', e.message);
  process.exit(1);
}
