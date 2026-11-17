import '../../../../core/error/result.dart';
import '../entities/mcp_setup.dart';
import '../repositories/mcp_setup_repository.dart';

/// Gets the bundled MCP server ready to register with an AI tool.
class PrepareMcpSetup {
  const PrepareMcpSetup(this._repository);

  final McpSetupRepository _repository;

  Future<Result<McpSetup>> call() => _repository.prepare();
}
