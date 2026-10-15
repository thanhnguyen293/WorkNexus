import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/value_objects/provider_type.dart';
import 'tool_module.dart';

/// Registry of tool modules keyed by [ProviderType].
/// Overridden in `main.dart` with `defaultToolRegistry`.
final toolRegistryProvider = Provider<Map<ProviderType, ToolModule>>(
  (ref) => const <ProviderType, ToolModule>{},
);
