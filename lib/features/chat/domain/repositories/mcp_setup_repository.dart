import '../../../../core/error/result.dart';
import '../entities/mcp_setup.dart';

/// Gets the bundled MCP server ready for AI tools to run.
abstract class McpSetupRepository {
  /// Copies the server script out of the app (refreshing an older copy) and
  /// looks for Node.js to run it with.
  Future<Result<McpSetup>> prepare();

  /// Brings a script copied out earlier up to this build's version; does
  /// nothing when the user never set the server up.
  Future<Result<void>> refreshInstalledScript();
}
