#!/usr/bin/env node
// MCP server (stdio) exposing TBChat (local DB, read-only) and ZenTao chat
// (read: WorkNexus local DB or ZenTao server; send: WorkNexus local API or ZenTao server).
import fs from 'node:fs';
import path from 'node:path';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';
import * as tbchat from './tbchat.js';
import * as zentao from './zentao.js';
import * as worknexus from './worknexus.js';

// ZenTao reads come from WorkNexus' local cache when it is installed (no login needed),
// else from the ZenTao server. ZENTAO_READ_SOURCE=api|worknexus forces one.
function zentaoReader() {
  const forced = (process.env.ZENTAO_READ_SOURCE ?? '').toLowerCase();
  if (forced === 'api') return zentao;
  if (forced === 'worknexus' || worknexus.findDatabase()) return worknexus;
  return zentao;
}
const reader = (app) => (app === 'tbchat' ? tbchat : zentaoReader());

// Sends go through WorkNexus' session when its local API is on (no password here);
// with ZENTAO_PASSWORD set and WorkNexus' API off, straight to the ZenTao server.
// ZENTAO_SEND_VIA=api|worknexus forces one.
function zentaoSender() {
  const forced = (process.env.ZENTAO_SEND_VIA ?? '').toLowerCase();
  if (forced === 'api') return zentao;
  if (forced === 'worknexus' || worknexus.localApiInfo()) return worknexus;
  return process.env.ZENTAO_PASSWORD ? zentao : worknexus;
}

const server = new McpServer({ name: 'worknexus', version: '1.0.0' });

const App = z.enum(['tbchat', 'zentao']).describe('Which chat app: "tbchat" (local, read-only) or "zentao" (read from WorkNexus cache when available)');
const ok = (data) => ({ content: [{ type: 'text', text: JSON.stringify(data, null, 2) }] });
const run = (fn) => async (args) => {
  try {
    return ok(await fn(args));
  } catch (e) {
    return { isError: true, content: [{ type: 'text', text: String(e?.message ?? e) }] };
  }
};

server.registerTool(
  'list_conversations',
  {
    description: 'List recent conversations (direct chats and groups), newest first, with a preview of the last message.',
    inputSchema: {
      app: App,
      limit: z.number().int().min(1).max(500).default(50),
      account: z.string().optional().describe('TBChat: local account folder id; ZenTao via WorkNexus: account handle or id'),
    },
  },
  run(({ app, ...a }) => reader(app).listConversations(a)),
);

server.registerTool(
  'read_messages',
  {
    description: 'Read messages of one conversation in chronological order (the most recent `limit` messages, optionally before a time). ZenTao via WorkNexus: when fewer are stored than asked, WorkNexus fetches older ones from the server first (if its local API is on); `history` in the result says what happened. To page further back, pass the oldest `time` as `before`. Messages with `attachment` can be opened with get_attachment.',
    inputSchema: {
      app: App,
      conversation: z.string().describe('Conversation name or id as returned by list_conversations (TBChat: sessionId; ZenTao: gid)'),
      limit: z.number().int().min(1).max(500).default(50),
      before: z.string().optional().describe('ISO date/time; only messages strictly before it'),
      loadMore: z.boolean().default(true).describe('ZenTao via WorkNexus: let WorkNexus fetch older messages from the server when too few are stored'),
      account: z.string().optional(),
    },
  },
  run(({ app, ...a }) => reader(app).readMessages(a)),
);

server.registerTool(
  'search_messages',
  {
    description: 'Case-insensitive text search over messages (content and sender name), newest first.',
    inputSchema: {
      app: App,
      query: z.string().min(1),
      conversation: z.string().optional().describe('Restrict to one conversation (name or id)'),
      limit: z.number().int().min(1).max(500).default(50),
      account: z.string().optional(),
    },
  },
  run(({ app, ...a }) => reader(app).searchMessages(a)),
);

server.registerTool(
  'send_message',
  {
    description: 'Send a text message to a ZenTao chat (direct or group). Sends for real as the logged-in user: confirm the recipient and text with the user first.',
    inputSchema: {
      app: z.literal('zentao').describe('Only "zentao" is supported for sending'),
      conversation: z.string().describe('Conversation name or gid as returned by list_conversations'),
      text: z.string().min(1),
      account: z.string().optional().describe('WorkNexus ZenTao account handle or id, when it has several'),
    },
  },
  run(({ app, ...a }) => zentaoSender().sendMessage(a)),
);

// What get_attachment returns inline: images an MCP client can show, and small text files.
const MAX_INLINE_IMAGE = 5 * 1024 * 1024;
const MAX_INLINE_TEXT = 256 * 1024;
const IMAGE_TYPES = { png: 'image/png', jpg: 'image/jpeg', jpeg: 'image/jpeg', gif: 'image/gif', webp: 'image/webp' };
const TEXT_EXTENSIONS = new Set(['txt', 'md', 'csv', 'tsv', 'json', 'log', 'xml', 'yaml', 'yml', 'ini', 'toml', 'html', 'css',
  'js', 'mjs', 'ts', 'tsx', 'jsx', 'dart', 'py', 'java', 'kt', 'swift', 'go', 'rs', 'c', 'h', 'cpp', 'cs', 'php', 'rb', 'sh', 'sql', 'diff', 'patch']);

function attachmentContent(file) {
  const ext = path.extname(file.name || file.path).slice(1).toLowerCase();
  const size = fs.statSync(file.path).size;
  const meta = { type: 'text', text: JSON.stringify(file, null, 2) };
  const imageType = file.isImage ? (IMAGE_TYPES[ext] ?? Object.values(IMAGE_TYPES).find((t) => t === file.mimeType)) : null;
  if (imageType && size <= MAX_INLINE_IMAGE) {
    return [meta, { type: 'image', data: fs.readFileSync(file.path).toString('base64'), mimeType: imageType }];
  }
  if (!file.isImage && size <= MAX_INLINE_TEXT && (file.mimeType?.startsWith('text/') || TEXT_EXTENSIONS.has(ext))) {
    return [meta, { type: 'text', text: fs.readFileSync(file.path, 'utf8') }];
  }
  return [meta, { type: 'text', text: `Not shown inline (${file.isImage ? 'image type or size' : 'binary or large file'}); open it at ${file.path}.` }];
}

server.registerTool(
  'get_attachment',
  {
    description: 'Open the file or image of a ZenTao message (one read_messages marks with `attachment`), downloaded through WorkNexus: images come back as images, small text files as text, anything else as a local file path. Needs WorkNexus running with "Let local AI tools use chat" on.',
    inputSchema: {
      app: z.literal('zentao').describe('Only "zentao" (through WorkNexus) is supported'),
      conversation: z.string().describe('Conversation name or gid'),
      messageId: z.number().int().positive().describe('The message `id` from read_messages or search_messages'),
      account: z.string().optional().describe('WorkNexus ZenTao account handle or id, when it has several'),
    },
  },
  async ({ app, ...a }) => {
    try {
      return { content: attachmentContent(await worknexus.getAttachment(a)) };
    } catch (e) {
      return { isError: true, content: [{ type: 'text', text: String(e?.message ?? e) }] };
    }
  },
);

await server.connect(new StdioServerTransport());
