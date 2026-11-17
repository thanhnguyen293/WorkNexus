import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/mcp_setup.dart';
import '../../domain/repositories/mcp_setup_repository.dart';
import '../../domain/usecases/build_mcp_client_configs.dart';
import '../../domain/usecases/prepare_mcp_setup.dart';
import '../../domain/value_objects/mcp_client_config.dart';

/// The bundled MCP server, ready to register (prepared each time the guide
/// opens, so a Node.js installed meanwhile is found).
final mcpSetupProvider = FutureProvider.autoDispose<McpSetup>((ref) async {
  final result = await PrepareMcpSetup(getIt<McpSetupRepository>())();
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
});

/// How to register [setup] with each AI tool on this OS.
List<McpClientConfig> mcpClientConfigs(McpSetup setup) =>
    const BuildMcpClientConfigs()(setup, switch (defaultTargetPlatform) {
      TargetPlatform.windows => McpHostOs.windows,
      TargetPlatform.linux => McpHostOs.linux,
      _ => McpHostOs.macos,
    });
