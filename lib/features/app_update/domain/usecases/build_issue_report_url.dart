import '../../../../core/config/app_config.dart';

/// The GitHub "new issue" page of the repository this build comes from, with
/// the app and system details already in the description.
class BuildIssueReportUrl {
  const BuildIssueReportUrl();

  Uri call({required String appVersion, required String system}) => Uri.https(
    'github.com',
    '/${AppConfig.githubOwner}/${AppConfig.githubRepo}/issues/new',
    {
      'body':
          '**What happened?**\n\n\n'
          '**What did you expect?**\n\n\n'
          '---\n'
          'App: ${AppConfig.appName} $appVersion\n'
          'System: $system',
    },
  );
}
