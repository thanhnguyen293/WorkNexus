import '../core/domain/value_objects/provider_type.dart';
import '../core/tools/tool_module.dart';
import '../tools/github/github_module.dart';
import '../tools/gitlab/gitlab_module.dart';
import '../tools/zentao/zentao_module.dart';

/// Default tool registry mapping ProviderType to its ToolModule implementation.
final Map<ProviderType, ToolModule> defaultToolRegistry = {
  ProviderType.zentao: const ZentaoModule(),
  ProviderType.github: const GithubModule(),
  ProviderType.gitlab: const GitlabModule(),
};
