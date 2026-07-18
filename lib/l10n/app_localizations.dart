import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Unified Task Board'**
  String get appTitle;

  /// No description provided for @board.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get board;

  /// No description provided for @list.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get list;

  /// No description provided for @integrations.
  ///
  /// In en, this message translates to:
  /// **'Integrations'**
  String get integrations;

  /// No description provided for @views.
  ///
  /// In en, this message translates to:
  /// **'Views'**
  String get views;

  /// No description provided for @workspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get workspace;

  /// No description provided for @sources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get sources;

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// No description provided for @allWorkspaces.
  ///
  /// In en, this message translates to:
  /// **'All workspaces'**
  String get allWorkspaces;

  /// No description provided for @personal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get personal;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search tasks, IDs, projects…'**
  String get search;

  /// No description provided for @provider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get provider;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @project.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get project;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @priority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priority;

  /// No description provided for @assignee.
  ///
  /// In en, this message translates to:
  /// **'Assignee'**
  String get assignee;

  /// No description provided for @severity.
  ///
  /// In en, this message translates to:
  /// **'Severity'**
  String get severity;

  /// No description provided for @bugType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get bugType;

  /// No description provided for @resolution.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get resolution;

  /// No description provided for @unassigned.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get unassigned;

  /// No description provided for @noBoardFilters.
  ///
  /// In en, this message translates to:
  /// **'No filters for this board'**
  String get noBoardFilters;

  /// No description provided for @assignedToMe.
  ///
  /// In en, this message translates to:
  /// **'Assigned to me'**
  String get assignedToMe;

  /// No description provided for @resolvedByMe.
  ///
  /// In en, this message translates to:
  /// **'Resolved by me'**
  String get resolvedByMe;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @results.
  ///
  /// In en, this message translates to:
  /// **'results'**
  String get results;

  /// No description provided for @result.
  ///
  /// In en, this message translates to:
  /// **'result'**
  String get result;

  /// No description provided for @colInbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get colInbox;

  /// No description provided for @colTodo.
  ///
  /// In en, this message translates to:
  /// **'Todo'**
  String get colTodo;

  /// No description provided for @colInprogress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get colInprogress;

  /// No description provided for @colReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get colReview;

  /// No description provided for @colBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get colBlocked;

  /// No description provided for @colDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get colDone;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'All tasks'**
  String get viewAll;

  /// No description provided for @viewToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get viewToday;

  /// No description provided for @viewMine.
  ///
  /// In en, this message translates to:
  /// **'My tasks'**
  String get viewMine;

  /// No description provided for @viewReview.
  ///
  /// In en, this message translates to:
  /// **'In review'**
  String get viewReview;

  /// No description provided for @viewBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get viewBlocked;

  /// No description provided for @allSynced.
  ///
  /// In en, this message translates to:
  /// **'All synced'**
  String get allSynced;

  /// No description provided for @assignedToYou.
  ///
  /// In en, this message translates to:
  /// **'{count} tasks assigned to you'**
  String assignedToYou(int count);

  /// No description provided for @syncedAgo.
  ///
  /// In en, this message translates to:
  /// **'Synced 2m ago'**
  String get syncedAgo;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String minutesAgo(int count);

  /// No description provided for @task.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get task;

  /// No description provided for @summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary;

  /// No description provided for @updated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get updated;

  /// No description provided for @priorityUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get priorityUrgent;

  /// No description provided for @priorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get priorityHigh;

  /// No description provided for @priorityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get priorityMedium;

  /// No description provided for @priorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get priorityLow;

  /// No description provided for @original.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get original;

  /// No description provided for @vietnamese.
  ///
  /// In en, this message translates to:
  /// **'Vietnamese'**
  String get vietnamese;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @comments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get comments;

  /// No description provided for @development.
  ///
  /// In en, this message translates to:
  /// **'Development'**
  String get development;

  /// No description provided for @translate.
  ///
  /// In en, this message translates to:
  /// **'Translate with OpenCode'**
  String get translate;

  /// No description provided for @retranslate.
  ///
  /// In en, this message translates to:
  /// **'Re-translate with OpenCode'**
  String get retranslate;

  /// No description provided for @translating.
  ///
  /// In en, this message translates to:
  /// **'Translating with OpenCode…'**
  String get translating;

  /// No description provided for @notTranslated.
  ///
  /// In en, this message translates to:
  /// **'Not translated'**
  String get notTranslated;

  /// No description provided for @translated.
  ///
  /// In en, this message translates to:
  /// **'Translated'**
  String get translated;

  /// No description provided for @translationOutdated.
  ///
  /// In en, this message translates to:
  /// **'Outdated translation'**
  String get translationOutdated;

  /// No description provided for @translationFailed.
  ///
  /// In en, this message translates to:
  /// **'Translation failed'**
  String get translationFailed;

  /// No description provided for @connectedAccounts.
  ///
  /// In en, this message translates to:
  /// **'Connected accounts'**
  String get connectedAccounts;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect account'**
  String get connect;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @chooseProvider.
  ///
  /// In en, this message translates to:
  /// **'Choose a provider'**
  String get chooseProvider;

  /// No description provided for @emptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No tasks match these filters'**
  String get emptyTitle;

  /// No description provided for @emptyDesc.
  ///
  /// In en, this message translates to:
  /// **'Try clearing a filter or switching workspace.'**
  String get emptyDesc;

  /// No description provided for @clearAllFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear all filters'**
  String get clearAllFilters;

  /// No description provided for @quickSettings.
  ///
  /// In en, this message translates to:
  /// **'Quick settings'**
  String get quickSettings;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeMidnight.
  ///
  /// In en, this message translates to:
  /// **'Midnight'**
  String get themeMidnight;

  /// No description provided for @surface.
  ///
  /// In en, this message translates to:
  /// **'Surface'**
  String get surface;

  /// No description provided for @surfaceFlat.
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get surfaceFlat;

  /// No description provided for @surfaceOutline.
  ///
  /// In en, this message translates to:
  /// **'Outline'**
  String get surfaceOutline;

  /// No description provided for @density.
  ///
  /// In en, this message translates to:
  /// **'Density'**
  String get density;

  /// No description provided for @densityComfortable.
  ///
  /// In en, this message translates to:
  /// **'Comfortable'**
  String get densityComfortable;

  /// No description provided for @densityCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get densityCompact;

  /// No description provided for @detailLayout.
  ///
  /// In en, this message translates to:
  /// **'Detail layout'**
  String get detailLayout;

  /// No description provided for @layoutTwoPane.
  ///
  /// In en, this message translates to:
  /// **'Two pane'**
  String get layoutTwoPane;

  /// No description provided for @layoutDocument.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get layoutDocument;

  /// No description provided for @companyTint.
  ///
  /// In en, this message translates to:
  /// **'Company tint'**
  String get companyTint;

  /// No description provided for @settingOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingOff;

  /// No description provided for @settingOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get settingOn;

  /// No description provided for @font.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get font;

  /// No description provided for @systemFont.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemFont;

  /// No description provided for @chooseUiFont.
  ///
  /// In en, this message translates to:
  /// **'Choose UI font'**
  String get chooseUiFont;

  /// No description provided for @cornerRadius.
  ///
  /// In en, this message translates to:
  /// **'Corner radius'**
  String get cornerRadius;

  /// No description provided for @primaryColor.
  ///
  /// In en, this message translates to:
  /// **'Primary color'**
  String get primaryColor;

  /// No description provided for @colorDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get colorDefault;

  /// No description provided for @projects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get projects;

  /// No description provided for @pinProject.
  ///
  /// In en, this message translates to:
  /// **'Pin project'**
  String get pinProject;

  /// No description provided for @unpinProject.
  ///
  /// In en, this message translates to:
  /// **'Unpin project'**
  String get unpinProject;

  /// No description provided for @loadingProjects.
  ///
  /// In en, this message translates to:
  /// **'Loading projects…'**
  String get loadingProjects;

  /// No description provided for @projectsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Can\'t load projects'**
  String get projectsUnavailable;

  /// No description provided for @projectOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open project'**
  String get projectOpenFailed;

  /// No description provided for @executions.
  ///
  /// In en, this message translates to:
  /// **'Executions'**
  String get executions;

  /// No description provided for @loadingExecutions.
  ///
  /// In en, this message translates to:
  /// **'Loading executions…'**
  String get loadingExecutions;

  /// No description provided for @executionsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Can\'t load executions'**
  String get executionsUnavailable;

  /// No description provided for @noExecutions.
  ///
  /// In en, this message translates to:
  /// **'No executions'**
  String get noExecutions;

  /// No description provided for @executionOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open execution'**
  String get executionOpenFailed;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @attachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get attachments;

  /// No description provided for @savedToDownloads.
  ///
  /// In en, this message translates to:
  /// **'Saved to Downloads'**
  String get savedToDownloads;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the file'**
  String get saveFailed;

  /// No description provided for @attachmentLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the attachment'**
  String get attachmentLoadFailed;

  /// No description provided for @previewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Preview isn\'t available for this file type'**
  String get previewUnavailable;

  /// No description provided for @confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get confirmed;

  /// No description provided for @reopenedTimes.
  ///
  /// In en, this message translates to:
  /// **'Reopened ×{count}'**
  String reopenedTimes(int count);

  /// No description provided for @openedBy.
  ///
  /// In en, this message translates to:
  /// **'Opened by'**
  String get openedBy;

  /// No description provided for @assignedTo.
  ///
  /// In en, this message translates to:
  /// **'Assigned to'**
  String get assignedTo;

  /// No description provided for @lastEdited.
  ///
  /// In en, this message translates to:
  /// **'Last edited'**
  String get lastEdited;

  /// No description provided for @classification.
  ///
  /// In en, this message translates to:
  /// **'Classification'**
  String get classification;

  /// No description provided for @lifecycle.
  ///
  /// In en, this message translates to:
  /// **'Lifecycle'**
  String get lifecycle;

  /// No description provided for @showEmptyFields.
  ///
  /// In en, this message translates to:
  /// **'Show {count} empty fields'**
  String showEmptyFields(int count);

  /// No description provided for @hideEmptyFields.
  ///
  /// In en, this message translates to:
  /// **'Hide empty fields'**
  String get hideEmptyFields;

  /// No description provided for @stepsToReproduce.
  ///
  /// In en, this message translates to:
  /// **'Steps to reproduce'**
  String get stepsToReproduce;

  /// No description provided for @actualResult.
  ///
  /// In en, this message translates to:
  /// **'Actual result'**
  String get actualResult;

  /// No description provided for @expectedResult.
  ///
  /// In en, this message translates to:
  /// **'Expected result'**
  String get expectedResult;

  /// No description provided for @fieldProduct.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get fieldProduct;

  /// No description provided for @fieldExecution.
  ///
  /// In en, this message translates to:
  /// **'Execution'**
  String get fieldExecution;

  /// No description provided for @fieldModule.
  ///
  /// In en, this message translates to:
  /// **'Module'**
  String get fieldModule;

  /// No description provided for @fieldBranch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get fieldBranch;

  /// No description provided for @fieldType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get fieldType;

  /// No description provided for @fieldSeverity.
  ///
  /// In en, this message translates to:
  /// **'Severity'**
  String get fieldSeverity;

  /// No description provided for @fieldPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get fieldPlan;

  /// No description provided for @fieldStory.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get fieldStory;

  /// No description provided for @fieldOs.
  ///
  /// In en, this message translates to:
  /// **'OS'**
  String get fieldOs;

  /// No description provided for @fieldBrowser.
  ///
  /// In en, this message translates to:
  /// **'Browser'**
  String get fieldBrowser;

  /// No description provided for @fieldOpenedBuild.
  ///
  /// In en, this message translates to:
  /// **'Opened build'**
  String get fieldOpenedBuild;

  /// No description provided for @fieldOpened.
  ///
  /// In en, this message translates to:
  /// **'Opened'**
  String get fieldOpened;

  /// No description provided for @fieldAssigned.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get fieldAssigned;

  /// No description provided for @fieldDeadline.
  ///
  /// In en, this message translates to:
  /// **'Deadline'**
  String get fieldDeadline;

  /// No description provided for @fieldResolvedBy.
  ///
  /// In en, this message translates to:
  /// **'Resolved by'**
  String get fieldResolvedBy;

  /// No description provided for @fieldResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get fieldResolved;

  /// No description provided for @fieldResolvedBuild.
  ///
  /// In en, this message translates to:
  /// **'Resolved build'**
  String get fieldResolvedBuild;

  /// No description provided for @fieldClosedBy.
  ///
  /// In en, this message translates to:
  /// **'Closed by'**
  String get fieldClosedBy;

  /// No description provided for @fieldClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get fieldClosed;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'vi':
      return AppL10nVi();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
