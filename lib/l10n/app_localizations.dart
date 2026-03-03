import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
    Locale('zh')
  ];

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @defaultPhonePrefix.
  ///
  /// In en, this message translates to:
  /// **'Default phone prefix'**
  String get defaultPhonePrefix;

  /// No description provided for @defaultPhonePrefixHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. +86'**
  String get defaultPhonePrefixHint;

  /// No description provided for @clearAllData.
  ///
  /// In en, this message translates to:
  /// **'Clear All Data'**
  String get clearAllData;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEn;

  /// No description provided for @languageZh.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get languageZh;

  /// No description provided for @license.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get license;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @clearAllDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all data?'**
  String get clearAllDataTitle;

  /// No description provided for @clearAllDataContent.
  ///
  /// In en, this message translates to:
  /// **'This will delete all tasks and reset the app to a fresh state. This action cannot be undone.'**
  String get clearAllDataContent;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @notificationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Notification permission denied'**
  String get notificationPermissionDenied;

  /// No description provided for @notificationsEnabledAndScheduled.
  ///
  /// In en, this message translates to:
  /// **'Notifications enabled and scheduled'**
  String get notificationsEnabledAndScheduled;

  /// No description provided for @allNotificationsCancelled.
  ///
  /// In en, this message translates to:
  /// **'All notifications cancelled'**
  String get allNotificationsCancelled;

  /// No description provided for @notificationPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Notification permission required'**
  String get notificationPermissionRequired;

  /// No description provided for @notificationsDisabledInSettings.
  ///
  /// In en, this message translates to:
  /// **'Notifications are disabled in settings'**
  String get notificationsDisabledInSettings;

  /// No description provided for @testNotification.
  ///
  /// In en, this message translates to:
  /// **'Test Notification'**
  String get testNotification;

  /// No description provided for @testNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'This is a test notification to verify notifications are working!'**
  String get testNotificationBody;

  /// No description provided for @testNotificationSent.
  ///
  /// In en, this message translates to:
  /// **'Test notification sent'**
  String get testNotificationSent;

  /// No description provided for @allDataCleared.
  ///
  /// In en, this message translates to:
  /// **'All data cleared'**
  String get allDataCleared;

  /// No description provided for @couldNotOpenUrl.
  ///
  /// In en, this message translates to:
  /// **'Could not open {url}'**
  String couldNotOpenUrl(String url);

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @calendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get selectDate;

  /// No description provided for @selectTime.
  ///
  /// In en, this message translates to:
  /// **'Select time'**
  String get selectTime;

  /// No description provided for @setDate.
  ///
  /// In en, this message translates to:
  /// **'Set date'**
  String get setDate;

  /// No description provided for @setTime.
  ///
  /// In en, this message translates to:
  /// **'Set time'**
  String get setTime;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @dateAndTime.
  ///
  /// In en, this message translates to:
  /// **'Date & Time'**
  String get dateAndTime;

  /// No description provided for @startTime.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get startTime;

  /// No description provided for @endTime.
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get endTime;

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get startDate;

  /// No description provided for @endDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get endDate;

  /// No description provided for @timeKindStartOnly.
  ///
  /// In en, this message translates to:
  /// **'Start time only (recurring allowed)'**
  String get timeKindStartOnly;

  /// No description provided for @timeKindEndOnly.
  ///
  /// In en, this message translates to:
  /// **'End time only (no repeat)'**
  String get timeKindEndOnly;

  /// No description provided for @timeKindBoth.
  ///
  /// In en, this message translates to:
  /// **'Start and end time (no repeat)'**
  String get timeKindBoth;

  /// No description provided for @daysBeforeAt.
  ///
  /// In en, this message translates to:
  /// **'{days} day(s) before at {time}'**
  String daysBeforeAt(int days, String time);

  /// No description provided for @hoursMinutesBefore.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m before'**
  String hoursMinutesBefore(int hours, int minutes);

  /// No description provided for @completionStatus.
  ///
  /// In en, this message translates to:
  /// **'Completion Status'**
  String get completionStatus;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @taskCompletedMessage.
  ///
  /// In en, this message translates to:
  /// **'Completed: {title}'**
  String taskCompletedMessage(String title);

  /// No description provided for @incomplete.
  ///
  /// In en, this message translates to:
  /// **'Incomplete'**
  String get incomplete;

  /// No description provided for @any.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get any;

  /// No description provided for @repeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeat;

  /// No description provided for @daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// No description provided for @weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @yearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearly;

  /// No description provided for @noRepeat.
  ///
  /// In en, this message translates to:
  /// **'No repeat'**
  String get noRepeat;

  /// No description provided for @mondayShort.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get mondayShort;

  /// No description provided for @tuesdayShort.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get tuesdayShort;

  /// No description provided for @wednesdayShort.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get wednesdayShort;

  /// No description provided for @thursdayShort.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get thursdayShort;

  /// No description provided for @fridayShort.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get fridayShort;

  /// No description provided for @saturdayShort.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get saturdayShort;

  /// No description provided for @sundayShort.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get sundayShort;

  /// No description provided for @reminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get reminders;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get on;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @applyFilter.
  ///
  /// In en, this message translates to:
  /// **'Apply Filter'**
  String get applyFilter;

  /// No description provided for @clearSelections.
  ///
  /// In en, this message translates to:
  /// **'Clear selections'**
  String get clearSelections;

  /// No description provided for @createTodo.
  ///
  /// In en, this message translates to:
  /// **'Create to-do'**
  String get createTodo;

  /// No description provided for @modifyTodo.
  ///
  /// In en, this message translates to:
  /// **'Modify to-do'**
  String get modifyTodo;

  /// No description provided for @setReminder.
  ///
  /// In en, this message translates to:
  /// **'Set Reminder'**
  String get setReminder;

  /// No description provided for @tellUsAboutTask.
  ///
  /// In en, this message translates to:
  /// **'Tell us about your task'**
  String get tellUsAboutTask;

  /// No description provided for @taskLabel.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get taskLabel;

  /// No description provided for @taskInputHint.
  ///
  /// In en, this message translates to:
  /// **'Tell me about your task'**
  String get taskInputHint;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @sunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get sunday;

  /// No description provided for @monday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get monday;

  /// No description provided for @tuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get tuesday;

  /// No description provided for @wednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get wednesday;

  /// No description provided for @thursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get thursday;

  /// No description provided for @friday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get friday;

  /// No description provided for @saturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get saturday;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get saveDraft;

  /// No description provided for @pleaseEnterTitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get pleaseEnterTitle;

  /// No description provided for @pleaseFillActionOrSelectNone.
  ///
  /// In en, this message translates to:
  /// **'Please fill in the action content or select \"No action\"'**
  String get pleaseFillActionOrSelectNone;

  /// No description provided for @actionOpened.
  ///
  /// In en, this message translates to:
  /// **'Opened {action}'**
  String actionOpened(String action);

  /// No description provided for @actionOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open. Please check if the corresponding app is installed.'**
  String get actionOpenFailed;

  /// No description provided for @actionTypeNoAction.
  ///
  /// In en, this message translates to:
  /// **'No action'**
  String get actionTypeNoAction;

  /// No description provided for @actionTypeNavigation.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get actionTypeNavigation;

  /// No description provided for @actionTypePhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get actionTypePhone;

  /// No description provided for @actionTypeWeb.
  ///
  /// In en, this message translates to:
  /// **'Web'**
  String get actionTypeWeb;

  /// No description provided for @actionTypeMeeting.
  ///
  /// In en, this message translates to:
  /// **'Meeting'**
  String get actionTypeMeeting;

  /// No description provided for @actionTypeMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get actionTypeMessage;

  /// No description provided for @actionTypeLabelNavigation.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get actionTypeLabelNavigation;

  /// No description provided for @actionTypeLabelPhone.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get actionTypeLabelPhone;

  /// No description provided for @actionTypeLabelWeb.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get actionTypeLabelWeb;

  /// No description provided for @actionTypeLabelMeeting.
  ///
  /// In en, this message translates to:
  /// **'Meeting'**
  String get actionTypeLabelMeeting;

  /// No description provided for @actionTypeLabelMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get actionTypeLabelMessage;

  /// No description provided for @actionTypeLabelDefault.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get actionTypeLabelDefault;

  /// No description provided for @addAction.
  ///
  /// In en, this message translates to:
  /// **'Add action'**
  String get addAction;

  /// No description provided for @actionType.
  ///
  /// In en, this message translates to:
  /// **'Action type'**
  String get actionType;

  /// No description provided for @destinationAddress.
  ///
  /// In en, this message translates to:
  /// **'Destination address'**
  String get destinationAddress;

  /// No description provided for @inputAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter address'**
  String get inputAddress;

  /// No description provided for @navApp.
  ///
  /// In en, this message translates to:
  /// **'Navigation app'**
  String get navApp;

  /// No description provided for @gaode.
  ///
  /// In en, this message translates to:
  /// **'Gaode'**
  String get gaode;

  /// No description provided for @baidu.
  ///
  /// In en, this message translates to:
  /// **'Baidu'**
  String get baidu;

  /// No description provided for @google.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get google;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// No description provided for @phoneNumberHint.
  ///
  /// In en, this message translates to:
  /// **'Enter Chinese mobile number'**
  String get phoneNumberHint;

  /// No description provided for @webUrl.
  ///
  /// In en, this message translates to:
  /// **'Web URL'**
  String get webUrl;

  /// No description provided for @meetingIdOrLink.
  ///
  /// In en, this message translates to:
  /// **'Meeting ID or link'**
  String get meetingIdOrLink;

  /// No description provided for @meetingIdOrLinkHint.
  ///
  /// In en, this message translates to:
  /// **'Meeting ID or full link'**
  String get meetingIdOrLinkHint;

  /// No description provided for @meetingPlatform.
  ///
  /// In en, this message translates to:
  /// **'Meeting platform'**
  String get meetingPlatform;

  /// No description provided for @tencentMeeting.
  ///
  /// In en, this message translates to:
  /// **'Tencent Meeting'**
  String get tencentMeeting;

  /// No description provided for @zoom.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get zoom;

  /// No description provided for @dingtalk.
  ///
  /// In en, this message translates to:
  /// **'DingTalk'**
  String get dingtalk;

  /// No description provided for @messageContent.
  ///
  /// In en, this message translates to:
  /// **'Message content'**
  String get messageContent;

  /// No description provided for @messageContentHint.
  ///
  /// In en, this message translates to:
  /// **'Preset message text'**
  String get messageContentHint;

  /// No description provided for @contactOptional.
  ///
  /// In en, this message translates to:
  /// **'Contact (optional)'**
  String get contactOptional;

  /// No description provided for @contactHint.
  ///
  /// In en, this message translates to:
  /// **'Contact identifier'**
  String get contactHint;

  /// No description provided for @pleaseFillContent.
  ///
  /// In en, this message translates to:
  /// **'Please fill in'**
  String get pleaseFillContent;

  /// No description provided for @meetingInvitationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Meeting invitation is empty'**
  String get meetingInvitationEmpty;

  /// No description provided for @tencentMeetingNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'Tencent Meeting is not installed'**
  String get tencentMeetingNotInstalled;

  /// No description provided for @phoneError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid Chinese mobile number (11 digits)'**
  String get phoneError;

  /// No description provided for @urlError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a URL starting with http:// or https://'**
  String get urlError;

  /// No description provided for @removeAction.
  ///
  /// In en, this message translates to:
  /// **'Remove action'**
  String get removeAction;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @addAnotherAction.
  ///
  /// In en, this message translates to:
  /// **'Add another action'**
  String get addAnotherAction;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String versionLabel(String version);

  /// No description provided for @reminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminder;

  /// No description provided for @reminderEnabled.
  ///
  /// In en, this message translates to:
  /// **'Reminder enabled'**
  String get reminderEnabled;

  /// No description provided for @reminderTime.
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get reminderTime;

  /// No description provided for @minutesBefore.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min before'**
  String minutesBefore(int minutes);

  /// No description provided for @onTime.
  ///
  /// In en, this message translates to:
  /// **'On time'**
  String get onTime;

  /// No description provided for @customTime.
  ///
  /// In en, this message translates to:
  /// **'Custom time...'**
  String get customTime;

  /// No description provided for @tapToSetReminderTime.
  ///
  /// In en, this message translates to:
  /// **'Tap to set reminder time'**
  String get tapToSetReminderTime;

  /// No description provided for @modify.
  ///
  /// In en, this message translates to:
  /// **'Modify'**
  String get modify;

  /// No description provided for @set.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get set;

  /// No description provided for @timeNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get timeNotSet;

  /// No description provided for @timeOnlyNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Time-only is not allowed'**
  String get timeOnlyNotAllowed;

  /// No description provided for @quickOptions.
  ///
  /// In en, this message translates to:
  /// **'Quick options'**
  String get quickOptions;

  /// No description provided for @todayAt.
  ///
  /// In en, this message translates to:
  /// **'Today {time}'**
  String todayAt(String time);

  /// No description provided for @tomorrowAt.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow {time}'**
  String tomorrowAt(String time);

  /// No description provided for @overdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdue;

  /// No description provided for @reschedule.
  ///
  /// In en, this message translates to:
  /// **'Reschedule'**
  String get reschedule;

  /// No description provided for @noTasks.
  ///
  /// In en, this message translates to:
  /// **'No tasks'**
  String get noTasks;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @tapToAddTask.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add a task'**
  String get tapToAddTask;

  /// No description provided for @thisWeekend.
  ///
  /// In en, this message translates to:
  /// **'This weekend'**
  String get thisWeekend;

  /// No description provided for @customDate.
  ///
  /// In en, this message translates to:
  /// **'Custom date'**
  String get customDate;

  /// No description provided for @goToToday.
  ///
  /// In en, this message translates to:
  /// **'Go to today'**
  String get goToToday;

  /// No description provided for @tasksRescheduled.
  ///
  /// In en, this message translates to:
  /// **'{count} tasks rescheduled'**
  String tasksRescheduled(int count);

  /// No description provided for @systemAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Set system alarm'**
  String get systemAlarmTitle;

  /// No description provided for @systemAlarmSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Also add reminder in system alarm app'**
  String get systemAlarmSubtitle;

  /// No description provided for @systemAlarmPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Alarm permission required'**
  String get systemAlarmPermissionTitle;

  /// No description provided for @systemAlarmPermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'To add alarms silently, please go to Settings -> Privacy/Security -> Special app access -> Alarms & reminders to grant permission.'**
  String get systemAlarmPermissionMessage;

  /// No description provided for @goToSettings.
  ///
  /// In en, this message translates to:
  /// **'Go to Settings'**
  String get goToSettings;

  /// No description provided for @useSystemAlarmFallback.
  ///
  /// In en, this message translates to:
  /// **'Add via system alarm app'**
  String get useSystemAlarmFallback;

  /// No description provided for @draftFound.
  ///
  /// In en, this message translates to:
  /// **'Draft found'**
  String get draftFound;

  /// No description provided for @draftLoadPrompt.
  ///
  /// In en, this message translates to:
  /// **'Load unsaved content?'**
  String get draftLoadPrompt;

  /// No description provided for @ignore.
  ///
  /// In en, this message translates to:
  /// **'Ignore'**
  String get ignore;

  /// No description provided for @load.
  ///
  /// In en, this message translates to:
  /// **'Load'**
  String get load;

  /// No description provided for @editDescription.
  ///
  /// In en, this message translates to:
  /// **'Edit description'**
  String get editDescription;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @markdownHintStrikethrough.
  ///
  /// In en, this message translates to:
  /// **'Strikethrough'**
  String get markdownHintStrikethrough;

  /// No description provided for @markdownHintQuote.
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get markdownHintQuote;

  /// No description provided for @markdownHintCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get markdownHintCode;

  /// No description provided for @markdownHintOrderedList.
  ///
  /// In en, this message translates to:
  /// **'Ordered list'**
  String get markdownHintOrderedList;

  /// No description provided for @markdownHintTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get markdownHintTable;

  /// No description provided for @markdownHintImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get markdownHintImage;

  /// No description provided for @insertTemplate.
  ///
  /// In en, this message translates to:
  /// **'Insert template'**
  String get insertTemplate;

  /// No description provided for @meetingNotes.
  ///
  /// In en, this message translates to:
  /// **'Meeting notes'**
  String get meetingNotes;

  /// No description provided for @todoList.
  ///
  /// In en, this message translates to:
  /// **'Todo list'**
  String get todoList;

  /// No description provided for @dailyLog.
  ///
  /// In en, this message translates to:
  /// **'Daily log'**
  String get dailyLog;

  /// No description provided for @previewEmpty.
  ///
  /// In en, this message translates to:
  /// **'# Preview\n\nNo content'**
  String get previewEmpty;

  /// No description provided for @characterCount.
  ///
  /// In en, this message translates to:
  /// **'{count} characters'**
  String characterCount(int count);

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @fullscreenEdit.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen edit'**
  String get fullscreenEdit;

  /// No description provided for @taskReminder.
  ///
  /// In en, this message translates to:
  /// **'Task Reminder'**
  String get taskReminder;

  /// No description provided for @notificationChannelName.
  ///
  /// In en, this message translates to:
  /// **'Task Reminders'**
  String get notificationChannelName;

  /// No description provided for @notificationChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Reminders for your tasks'**
  String get notificationChannelDescription;

  /// No description provided for @templateMeetingNotes.
  ///
  /// In en, this message translates to:
  /// **'## Meeting notes\n\n**Time**: {time}\n**Participants**: \n\n### Agenda\n- \n\n### Decisions\n- \n\n### Action items\n- [ ] \n'**
  String templateMeetingNotes(String time);

  /// No description provided for @templateTodoList.
  ///
  /// In en, this message translates to:
  /// **'## Todo list\n\n- [ ] Task 1\n- [ ] Task 2\n- [ ] Task 3\n'**
  String get templateTodoList;

  /// No description provided for @templateDailyLog.
  ///
  /// In en, this message translates to:
  /// **'## {date} Log\n\n### Done\n- \n\n### In progress\n- \n\n### Planned\n- \n'**
  String templateDailyLog(String date);

  /// No description provided for @completedTasks.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completedTasks;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @sortByStartTime.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get sortByStartTime;

  /// No description provided for @sortByEndTime.
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get sortByEndTime;

  /// No description provided for @sortByDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get sortByDuration;

  /// No description provided for @sortAscending.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get sortAscending;

  /// No description provided for @sortDescending.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get sortDescending;

  /// No description provided for @noCompletedTasks.
  ///
  /// In en, this message translates to:
  /// **'No completed tasks'**
  String get noCompletedTasks;

  /// No description provided for @batchDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get batchDelete;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
