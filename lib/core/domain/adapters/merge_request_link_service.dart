import '../../error/result.dart';
import '../value_objects/provider_type.dart';

/// Loads one GitLab merge request / GitHub pull request on demand — e.g. one
/// linked in chat — through the connected account for its host, so its live
/// state can be shown and it can open in the detail panel.
abstract interface class MergeRequestLinkService {
  /// Fetches MR/PR [number] of [project] (`group/repo`) from the [provider]
  /// account on [host], stores it and returns its WorkNexus ticket id.
  Future<Result<String>> fetchMergeRequest({
    required ProviderType provider,
    required String host,
    required String project,
    required String number,
  });
}
