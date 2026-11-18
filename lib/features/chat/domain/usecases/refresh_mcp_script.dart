import '../../../../core/error/result.dart';
import '../repositories/mcp_setup_repository.dart';

/// Keeps the MCP server AI tools were pointed at in step with this app: the
/// copy is only refreshed when the setup guide is opened, so without this an
/// app update would leave registered tools on the old server (missing new
/// tools, or reading a database it no longer understands).
class RefreshMcpScript {
  const RefreshMcpScript(this._repository);

  final McpSetupRepository _repository;

  Future<Result<void>> call() => _repository.refreshInstalledScript();
}
