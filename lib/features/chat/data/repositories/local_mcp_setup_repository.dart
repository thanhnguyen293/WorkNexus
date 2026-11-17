import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/mcp_setup.dart';
import '../../domain/repositories/mcp_setup_repository.dart';
import '../datasources/mcp_script_installer.dart';
import '../datasources/node_runtime_probe.dart';

/// [McpSetupRepository] over the bundled script and this computer's Node.js.
class LocalMcpSetupRepository implements McpSetupRepository {
  LocalMcpSetupRepository({required this.installer, required this.probe});

  final McpScriptInstaller installer;
  final NodeRuntimeProbe probe;

  @override
  Future<Result<McpSetup>> prepare() async {
    final String script;
    try {
      script = await installer.install();
    } on FileSystemException catch (e) {
      return Err(StorageFailure('Could not copy the MCP server', cause: e));
    } on FlutterError catch (e) {
      // The asset is missing from this build.
      return Err(NotFoundFailure('This build has no MCP server', cause: e));
    }
    final node = await probe.find();
    return Ok(
      McpSetup(
        scriptPath: script,
        nodePath: node?.path,
        nodeVersion: node?.version,
      ),
    );
  }
}
