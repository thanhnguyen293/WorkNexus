/// The fields of GitHub's `GET /repos/{owner}/{repo}/releases/latest` the
/// updater reads.
class GithubReleaseDto {
  const GithubReleaseDto({
    required this.tagName,
    required this.body,
    required this.htmlUrl,
    required this.assets,
  });

  factory GithubReleaseDto.fromJson(Map<String, dynamic> json) =>
      GithubReleaseDto(
        tagName: json['tag_name'] as String? ?? '',
        body: json['body'] as String? ?? '',
        htmlUrl: json['html_url'] as String? ?? '',
        assets: {
          for (final asset in json['assets'] as List<dynamic>? ?? const [])
            if (asset case {
              'name': final String name,
              'browser_download_url': final String url,
            })
              name: url,
        },
      );

  final String tagName;
  final String body;
  final String htmlUrl;

  /// Asset file name → download URL.
  final Map<String, String> assets;
}
