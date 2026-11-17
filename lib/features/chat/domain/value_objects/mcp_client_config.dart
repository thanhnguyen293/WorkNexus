/// An AI tool the setup guide shows how to register the MCP server with.
enum McpClient { claudeCode, claudeDesktop, other }

/// The desktop OS the guide is shown on: config files live in different
/// places on each.
enum McpHostOs { macos, windows, linux }

/// How to register the MCP server with one [client]: a command to run, or a
/// JSON entry for [configFile] (null for a command, or when the file depends
/// on the tool).
typedef McpClientConfig = ({
  McpClient client,
  String? configFile,
  String snippet,
});
