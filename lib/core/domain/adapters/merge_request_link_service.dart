import '../../error/result.dart';
import '../value_objects/linked_item_kind.dart';
import '../value_objects/provider_type.dart';

/// Loads one GitLab merge request / GitHub pull request — or an issue of
/// either — on demand, e.g. one linked in chat, through the connected
/// account for its host, so its live state can be shown and it can open in
/// the detail panel.
abstract interface class MergeRequestLinkService {
  /// Fetches the [kind] item [number] of [project] (`group/repo`) from the
  /// [provider] account on [host], stores it and returns its WorkNexus
  /// ticket id.
  Future<Result<String>> fetchMergeRequest({
    required ProviderType provider,
    required LinkedItemKind kind,
    required String host,
    required String project,
    required String number,
  });
}
