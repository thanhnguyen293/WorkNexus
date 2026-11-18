# WorkNexus MCP server

An [MCP](https://modelcontextprotocol.io) server (stdio) that lets AI tools read
and search **ZenTao chat** and **TBChat**, and send ZenTao messages. Pure
Node.js (≥ 22.13, for the built-in `node:sqlite`): no native modules, so one
file runs on macOS, Windows and Linux.

| Tool | TBChat | ZenTao |
|---|---|---|
| `list_conversations` | ✅ | ✅ |
| `read_messages` | ✅ | ✅ (asks WorkNexus for older pages when too few are stored) |
| `search_messages` | ✅ | ✅ (SQL over the WorkNexus cache, accent-insensitive) |
| `send_message` | — | ✅ (through WorkNexus, or straight to the ZenTao server) |
| `get_attachment` | — | ✅ (through WorkNexus: images inline, small text files as text, else a local path) |

Users don't install it from here: the app ships it as an asset
(`assets/mcp/worknexus-mcp.mjs`), copies it to its app-support folder, and
**Quick Settings › Chat › AI tools › Connect an AI tool** shows the command or
config entry to register it, with absolute paths.

## Where the data comes from

- **ZenTao, reading**: WorkNexus' SQLite cache (`worknexus.sqlite`, read-only).
  No password and no extra chat session. Results carry `newestMessageInCache`,
  how far WorkNexus has synced. Without WorkNexus it falls back to the ZenTao
  server (below). `ZENTAO_READ_SOURCE=api|worknexus` forces one.
- **ZenTao, older history**: when `read_messages` finds fewer timeline
  messages stored than asked (pinned messages and reply parents stored on
  their own do not count), it asks WorkNexus' local API
  (`POST /v1/chat/load-older`) for older pages, at most 20 per call, then
  reads the cache again. `history` in the result says how many arrived and
  whether the chat's start was reached; `loadMore: false` turns it off.
- **ZenTao, attachments**: `get_attachment` has WorkNexus download a
  message's file into its own cache (`POST /v1/chat/attachment`) and reads it
  from there.
- **ZenTao, sending**: WorkNexus' local chat API, on while the user turns on
  *Let local AI tools use chat*. WorkNexus writes `chat_local_api.json`
  (port, token, pid; mode 0600) next to its database; the server answers only
  127.0.0.1 requests with that token, and refuses browser requests. A file left
  by a WorkNexus that is no longer running is ignored. `ZENTAO_SEND_VIA=api|worknexus`
  forces one.
- **ZenTao server** (fallback): logs into the Xuanxuan (xxd) chat server like
  the desktop client: `POST /serverInfo`, then a WebSocket on `/ws`,
  AES-256-CBC. Needs `ZENTAO_SERVER` (e.g. `https://zentao.example.com:11443`),
  `ZENTAO_ACCOUNT`, `ZENTAO_PASSWORD` (or its md5), and `ZENTAO_INSECURE_TLS=1`
  for a self-signed certificate. It is a session of its own: a server that
  allows one login per user may sign the desktop app out.
- **TBChat**: the desktop app's ObjectBox database (LMDB v1), read with a small
  pure-JS reader. The schema is `data/tbchat-objectbox-model.json`, copied from
  the TBChat repo's `lib/database/object_box_models/objectbox-model.json`;
  refresh it when the app's database changes. Found automatically on macOS and
  Windows; elsewhere set `TBCHAT_USER_DATA` (the folder holding `accounts`) or
  `TBCHAT_DB` (a `data.mdb`). TBChat is read-only: sending is not supported.

WorkNexus' database is found at its app-support folder (`WORKNEXUS_DB`
overrides):

| OS | Path |
|---|---|
| macOS | `~/Library/Application Support/com.worknexus.workNexus/worknexus.sqlite` |
| Windows | `%APPDATA%\WorkNexus\WorkNexus\worknexus.sqlite` |
| Linux | `~/.local/share/com.worknexus.workNexus/worknexus.sqlite` |

## Development

```bash
cd mcp
npm install
npm test               # unit tests (fake xxd server, temp SQLite, …)
npm run build          # rebuilds ../assets/mcp/worknexus-mcp.mjs — commit it
npm run check-bundle   # CI: fails when the committed bundle is stale
```

- `scripts/mcp-smoke.mjs` starts the server over stdio and calls each tool
  (`MCP_SERVER=../assets/mcp/worknexus-mcp.mjs` to try the bundle).
- `scripts/zentao-live.mjs` (read-only) and `scripts/zentao-send.mjs` talk to a
  real ZenTao server with the `ZENTAO_*` variables.
- The bundle is committed because the Flutter build needs the asset; CI
  (`test.yml`, job *MCP server*) runs the tests on all three desktops and
  checks the bundle is current.
