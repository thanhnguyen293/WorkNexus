// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Unified Task Board';

  @override
  String get board => 'Board';

  @override
  String get list => 'List';

  @override
  String get integrations => 'Integrations';

  @override
  String get views => 'Views';

  @override
  String get workspace => 'Workspace';

  @override
  String get sources => 'Sources';

  @override
  String get activity => 'Activity';

  @override
  String get allWorkspaces => 'All workspaces';

  @override
  String get personal => 'Personal';

  @override
  String get search => 'Search tasks, IDs, projects…';

  @override
  String get provider => 'Provider';

  @override
  String get account => 'Account';

  @override
  String get project => 'Project';

  @override
  String get status => 'Status';

  @override
  String get priority => 'Priority';

  @override
  String get assignee => 'Assignee';

  @override
  String get severity => 'Severity';

  @override
  String get bugType => 'Type';

  @override
  String get resolution => 'Resolution';

  @override
  String get unassigned => 'Unassigned';

  @override
  String get noBoardFilters => 'No filters for this board';

  @override
  String get assignedToMe => 'Assigned to me';

  @override
  String get resolvedByMe => 'Resolved by me';

  @override
  String get bugTabAll => 'All';

  @override
  String get bugTabUnclosed => 'Unclosed';

  @override
  String get bugTabReportedByMe => 'Reported by me';

  @override
  String get bugTabAssignedByMe => 'Assigned by me';

  @override
  String get bugTabLoadFailed => 'Couldn\'t load bugs';

  @override
  String get filters => 'Filters';

  @override
  String get hide => 'Hide';

  @override
  String get clear => 'Clear';

  @override
  String get results => 'results';

  @override
  String get result => 'result';

  @override
  String get colInbox => 'Inbox';

  @override
  String get colTodo => 'Todo';

  @override
  String get colInprogress => 'In Progress';

  @override
  String get colReview => 'Review';

  @override
  String get colBlocked => 'Blocked';

  @override
  String get colDone => 'Done';

  @override
  String get viewAll => 'All tasks';

  @override
  String get viewToday => 'Today';

  @override
  String get viewMine => 'My tasks';

  @override
  String get viewReview => 'In review';

  @override
  String get viewBlocked => 'Blocked';

  @override
  String get allSynced => 'All synced';

  @override
  String assignedToYou(int count) {
    return '$count tasks assigned to you';
  }

  @override
  String get syncedAgo => 'Synced 2m ago';

  @override
  String get justNow => 'just now';

  @override
  String minutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String get task => 'Task';

  @override
  String get summary => 'Summary';

  @override
  String get updated => 'Updated';

  @override
  String get priorityUrgent => 'Urgent';

  @override
  String get priorityHigh => 'High';

  @override
  String get priorityMedium => 'Medium';

  @override
  String get priorityLow => 'Low';

  @override
  String get original => 'Original';

  @override
  String get vietnamese => 'Vietnamese';

  @override
  String get description => 'Description';

  @override
  String get comments => 'Comments';

  @override
  String get development => 'Development';

  @override
  String get translate => 'Translate with OpenCode';

  @override
  String get retranslate => 'Re-translate with OpenCode';

  @override
  String get translating => 'Translating with OpenCode…';

  @override
  String get notTranslated => 'Not translated';

  @override
  String get translated => 'Translated';

  @override
  String get translationOutdated => 'Outdated translation';

  @override
  String get translationFailed => 'Translation failed';

  @override
  String get connectedAccounts => 'Connected accounts';

  @override
  String get connect => 'Connect account';

  @override
  String get connected => 'Connected';

  @override
  String get chooseProvider => 'Choose a provider';

  @override
  String get emptyTitle => 'No tasks match these filters';

  @override
  String get emptyDesc => 'Try clearing a filter or switching workspace.';

  @override
  String get clearAllFilters => 'Clear all filters';

  @override
  String get quickSettings => 'Quick settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get theme => 'Theme';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeMidnight => 'Midnight';

  @override
  String get surface => 'Surface';

  @override
  String get surfaceFlat => 'Flat';

  @override
  String get surfaceOutline => 'Outline';

  @override
  String get density => 'Density';

  @override
  String get densityComfortable => 'Comfortable';

  @override
  String get densityCompact => 'Compact';

  @override
  String get detailLayout => 'Detail layout';

  @override
  String get layoutTwoPane => 'Two pane';

  @override
  String get layoutDocument => 'Document';

  @override
  String get companyTint => 'Company tint';

  @override
  String get settingOff => 'Off';

  @override
  String get settingOn => 'On';

  @override
  String get font => 'Font';

  @override
  String get systemFont => 'System';

  @override
  String get chooseUiFont => 'Choose UI font';

  @override
  String get cornerRadius => 'Corner radius';

  @override
  String get primaryColor => 'Primary color';

  @override
  String get colorDefault => 'Default';

  @override
  String get projects => 'Projects';

  @override
  String get pinProject => 'Pin project';

  @override
  String get unpinProject => 'Unpin project';

  @override
  String get loadingProjects => 'Loading projects…';

  @override
  String get projectsUnavailable => 'Can\'t load projects';

  @override
  String get projectOpenFailed => 'Couldn\'t open project';

  @override
  String get executions => 'Executions';

  @override
  String get loadingExecutions => 'Loading executions…';

  @override
  String get executionsUnavailable => 'Can\'t load executions';

  @override
  String get noExecutions => 'No executions';

  @override
  String get executionOpenFailed => 'Couldn\'t open execution';

  @override
  String get close => 'Close';

  @override
  String get download => 'Download';

  @override
  String get attachments => 'Attachments';

  @override
  String get savedToDownloads => 'Saved to Downloads';

  @override
  String get saveFailed => 'Couldn\'t save the file';

  @override
  String get attachmentLoadFailed => 'Couldn\'t load the attachment';

  @override
  String get previewUnavailable =>
      'Preview isn\'t available for this file type';

  @override
  String get confirmed => 'Confirmed';

  @override
  String reopenedTimes(int count) {
    return 'Reopened ×$count';
  }

  @override
  String get openedBy => 'Opened by';

  @override
  String get assignedTo => 'Assigned to';

  @override
  String get lastEdited => 'Last edited';

  @override
  String get classification => 'Classification';

  @override
  String get lifecycle => 'Lifecycle';

  @override
  String showEmptyFields(int count) {
    return 'Show $count empty fields';
  }

  @override
  String get hideEmptyFields => 'Hide empty fields';

  @override
  String get stepsToReproduce => 'Steps to reproduce';

  @override
  String get actualResult => 'Actual result';

  @override
  String get expectedResult => 'Expected result';

  @override
  String get fieldProduct => 'Product';

  @override
  String get fieldExecution => 'Execution';

  @override
  String get fieldModule => 'Module';

  @override
  String get fieldBranch => 'Branch';

  @override
  String get fieldType => 'Type';

  @override
  String get fieldSeverity => 'Severity';

  @override
  String get fieldPlan => 'Plan';

  @override
  String get fieldStory => 'Story';

  @override
  String get fieldOs => 'OS';

  @override
  String get fieldBrowser => 'Browser';

  @override
  String get fieldOpenedBuild => 'Opened build';

  @override
  String get fieldOpened => 'Opened';

  @override
  String get fieldAssigned => 'Assigned';

  @override
  String get fieldDeadline => 'Deadline';

  @override
  String get fieldResolvedBy => 'Resolved by';

  @override
  String get fieldResolved => 'Resolved';

  @override
  String get fieldResolvedBuild => 'Resolved build';

  @override
  String get fieldClosedBy => 'Closed by';

  @override
  String get fieldClosed => 'Closed';
}
