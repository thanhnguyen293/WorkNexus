/// A ticket source. Pure domain enum — brand colors are a presentation concern
/// and live in the theme layer, keeping `domain/` free of Flutter imports.
enum ProviderType {
  github(code: 'GH', displayName: 'GitHub'),
  gitlab(code: 'GL', displayName: 'GitLab'),
  jira(code: 'JR', displayName: 'Jira'),
  zentao(code: 'ZT', displayName: 'ZenTao');

  const ProviderType({required this.code, required this.displayName});

  /// Short 2-letter badge code (GH / GL / JR / ZT).
  final String code;
  final String displayName;

  static ProviderType byId(String id) =>
      ProviderType.values.firstWhere((p) => p.name == id);
}
