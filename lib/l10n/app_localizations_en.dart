// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settings => 'Settings';

  @override
  String get notifications => 'Notifications';

  @override
  String get defaultPhonePrefix => 'Default phone prefix';

  @override
  String get defaultPhonePrefixHint => 'e.g. +86';

  @override
  String get clearAllData => 'Clear All Data';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageEn => 'English';

  @override
  String get languageZh => '简体中文';

  @override
  String get license => 'License';

  @override
  String get version => 'Version';

  @override
  String get back => 'Back';

  @override
  String get clearAllDataTitle => 'Clear all data?';

  @override
  String get clearAllDataContent =>
      'This will delete all tasks and reset the app to a fresh state. This action cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get clear => 'Clear';

  @override
  String get notificationPermissionDenied => 'Notification permission denied';

  @override
  String get notificationsEnabledAndScheduled =>
      'Notifications enabled and scheduled';

  @override
  String get allNotificationsCancelled => 'All notifications cancelled';

  @override
  String get notificationPermissionRequired =>
      'Notification permission required';

  @override
  String get notificationsDisabledInSettings =>
      'Notifications are disabled in settings';

  @override
  String get testNotification => 'Test Notification';

  @override
  String get testNotificationBody =>
      'This is a test notification to verify notifications are working!';

  @override
  String get testNotificationSent => 'Test notification sent';

  @override
  String get allDataCleared => 'All data cleared';

  @override
  String couldNotOpenUrl(String url) {
    return 'Could not open $url';
  }

  @override
  String get today => 'Today';

  @override
  String get calendar => 'Calendar';

  @override
  String get filter => 'Filter';

  @override
  String get selectDate => 'Select date';

  @override
  String get selectTime => 'Select time';

  @override
  String get setDate => 'Set date';

  @override
  String get setTime => 'Set time';

  @override
  String get time => 'Time';

  @override
  String get date => 'Date';

  @override
  String get dateAndTime => 'Date & Time';

  @override
  String get startTime => 'Start time';

  @override
  String get endTime => 'End time';

  @override
  String get startDate => 'Start date';

  @override
  String get endDate => 'End date';

  @override
  String get timeKindStartOnly => 'Start time only (recurring allowed)';

  @override
  String get timeKindEndOnly => 'End time only (no repeat)';

  @override
  String get timeKindBoth => 'Start and end time (no repeat)';

  @override
  String daysBeforeAt(int days, String time) {
    return '$days day(s) before at $time';
  }

  @override
  String hoursMinutesBefore(int hours, int minutes) {
    return '${hours}h ${minutes}m before';
  }

  @override
  String get completionStatus => 'Completion Status';

  @override
  String get completed => 'Completed';

  @override
  String taskCompletedMessage(String title) {
    return 'Completed: $title';
  }

  @override
  String get incomplete => 'Incomplete';

  @override
  String get any => 'Any';

  @override
  String get repeat => 'Repeat';

  @override
  String get daily => 'Daily';

  @override
  String get weekly => 'Weekly';

  @override
  String get monthly => 'Monthly';

  @override
  String get yearly => 'Yearly';

  @override
  String get noRepeat => 'No repeat';

  @override
  String get mondayShort => 'Mon';

  @override
  String get tuesdayShort => 'Tue';

  @override
  String get wednesdayShort => 'Wed';

  @override
  String get thursdayShort => 'Thu';

  @override
  String get fridayShort => 'Fri';

  @override
  String get saturdayShort => 'Sat';

  @override
  String get sundayShort => 'Sun';

  @override
  String get reminders => 'Reminders';

  @override
  String get on => 'On';

  @override
  String get off => 'Off';

  @override
  String get applyFilter => 'Apply Filter';

  @override
  String get clearSelections => 'Clear selections';

  @override
  String get createTodo => 'Create to-do';

  @override
  String get modifyTodo => 'Modify to-do';

  @override
  String get setReminder => 'Set Reminder';

  @override
  String get tellUsAboutTask => 'Tell us about your task';

  @override
  String get taskLabel => 'Task';

  @override
  String get taskInputHint => 'Tell me about your task';

  @override
  String get title => 'Title';

  @override
  String get description => 'Description';

  @override
  String get sunday => 'Sunday';

  @override
  String get monday => 'Monday';

  @override
  String get tuesday => 'Tuesday';

  @override
  String get wednesday => 'Wednesday';

  @override
  String get thursday => 'Thursday';

  @override
  String get friday => 'Friday';

  @override
  String get saturday => 'Saturday';

  @override
  String get save => 'Save';

  @override
  String get saveDraft => 'Save draft';

  @override
  String get pleaseEnterTitle => 'Please enter a title';

  @override
  String get selectAtLeastOneDay => 'Select at least one day';

  @override
  String get pleaseFillActionOrSelectNone =>
      'Please fill in the action content or select \"No action\"';

  @override
  String actionOpened(String action) {
    return 'Opened $action';
  }

  @override
  String get actionOpenFailed =>
      'Failed to open. Please check if the corresponding app is installed.';

  @override
  String get actionTypeNoAction => 'No action';

  @override
  String get actionTypeNavigation => 'Navigation';

  @override
  String get actionTypePhone => 'Phone';

  @override
  String get actionTypeWeb => 'Web';

  @override
  String get actionTypeMeeting => 'Meeting';

  @override
  String get actionTypeMessage => 'Message';

  @override
  String get actionTypeLabelNavigation => 'Navigate';

  @override
  String get actionTypeLabelPhone => 'Call';

  @override
  String get actionTypeLabelWeb => 'Open';

  @override
  String get actionTypeLabelMeeting => 'Meeting';

  @override
  String get actionTypeLabelMessage => 'Message';

  @override
  String get actionTypeLabelDefault => 'Action';

  @override
  String get addAction => 'Add action';

  @override
  String get actionType => 'Action type';

  @override
  String get destinationAddress => 'Destination address';

  @override
  String get inputAddress => 'Enter address';

  @override
  String get navApp => 'Navigation app';

  @override
  String get gaode => 'Gaode';

  @override
  String get baidu => 'Baidu';

  @override
  String get google => 'Google';

  @override
  String get phoneNumber => 'Phone number';

  @override
  String get phoneNumberHint => 'Enter Chinese mobile number';

  @override
  String get webUrl => 'Web URL';

  @override
  String get meetingIdOrLink => 'Meeting ID or link';

  @override
  String get meetingIdOrLinkHint => 'Meeting ID or full link';

  @override
  String get meetingPlatform => 'Meeting platform';

  @override
  String get tencentMeeting => 'Tencent Meeting';

  @override
  String get zoom => 'Zoom';

  @override
  String get dingtalk => 'DingTalk';

  @override
  String get messageContent => 'Message content';

  @override
  String get messageContentHint => 'Preset message text';

  @override
  String get contactOptional => 'Contact (optional)';

  @override
  String get contactHint => 'Contact identifier';

  @override
  String get pleaseFillContent => 'Please fill in';

  @override
  String get meetingInvitationEmpty => 'Meeting invitation is empty';

  @override
  String get tencentMeetingNotInstalled => 'Tencent Meeting is not installed';

  @override
  String get phoneError =>
      'Please enter a valid Chinese mobile number (11 digits)';

  @override
  String get urlError => 'Please enter a URL starting with http:// or https://';

  @override
  String get removeAction => 'Remove action';

  @override
  String get delete => 'Delete';

  @override
  String get addAnotherAction => 'Add another action';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get reminder => 'Reminder';

  @override
  String get reminderEnabled => 'Reminder enabled';

  @override
  String get reminderTime => 'Reminder time';

  @override
  String minutesBefore(int minutes) {
    return '$minutes min before';
  }

  @override
  String get onTime => 'On time';

  @override
  String get customTime => 'Custom time...';

  @override
  String get tapToSetReminderTime => 'Tap to set reminder time';

  @override
  String get modify => 'Modify';

  @override
  String get set => 'Set';

  @override
  String get timeNotSet => 'Not set';

  @override
  String get timeOnlyNotAllowed => 'Time-only is not allowed';

  @override
  String get quickOptions => 'Quick options';

  @override
  String todayAt(String time) {
    return 'Today $time';
  }

  @override
  String tomorrowAt(String time) {
    return 'Tomorrow $time';
  }

  @override
  String get overdue => 'Overdue';

  @override
  String get reschedule => 'Reschedule';

  @override
  String get noTasks => 'No tasks';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get tapToAddTask => 'Tap + to add a task';

  @override
  String get thisWeekend => 'This weekend';

  @override
  String get customDate => 'Custom date';

  @override
  String get goToToday => 'Go to today';

  @override
  String tasksRescheduled(int count) {
    return '$count tasks rescheduled';
  }

  @override
  String get systemAlarmTitle => 'Set system alarm';

  @override
  String get systemAlarmSubtitle => 'Also add reminder in system alarm app';

  @override
  String get systemAlarmPermissionTitle => 'Alarm permission required';

  @override
  String get systemAlarmPermissionMessage =>
      'To add alarms silently, please go to Settings -> Privacy/Security -> Special app access -> Alarms & reminders to grant permission.';

  @override
  String get goToSettings => 'Go to Settings';

  @override
  String get useSystemAlarmFallback => 'Add via system alarm app';

  @override
  String get draftFound => 'Draft found';

  @override
  String get draftLoadPrompt => 'Load unsaved content?';

  @override
  String get ignore => 'Ignore';

  @override
  String get load => 'Load';

  @override
  String get editDescription => 'Edit description';

  @override
  String get edit => 'Edit';

  @override
  String get preview => 'Preview';

  @override
  String get markdownHintStrikethrough => 'Strikethrough';

  @override
  String get markdownHintQuote => 'Quote';

  @override
  String get markdownHintCode => 'Code';

  @override
  String get markdownHintOrderedList => 'Ordered list';

  @override
  String get markdownHintTable => 'Table';

  @override
  String get markdownHintImage => 'Image';

  @override
  String get insertTemplate => 'Insert template';

  @override
  String get meetingNotes => 'Meeting notes';

  @override
  String get todoList => 'Todo list';

  @override
  String get dailyLog => 'Daily log';

  @override
  String get previewEmpty => '# Preview\n\nNo content';

  @override
  String characterCount(int count) {
    return '$count characters';
  }

  @override
  String get done => 'Done';

  @override
  String get fullscreenEdit => 'Fullscreen edit';

  @override
  String get taskReminder => 'Task Reminder';

  @override
  String get notificationChannelName => 'Task Reminders';

  @override
  String get notificationChannelDescription => 'Reminders for your tasks';

  @override
  String templateMeetingNotes(String time) {
    return '## Meeting notes\n\n**Time**: $time\n**Participants**: \n\n### Agenda\n- \n\n### Decisions\n- \n\n### Action items\n- [ ] \n';
  }

  @override
  String get templateTodoList =>
      '## Todo list\n\n- [ ] Task 1\n- [ ] Task 2\n- [ ] Task 3\n';

  @override
  String templateDailyLog(String date) {
    return '## $date Log\n\n### Done\n- \n\n### In progress\n- \n\n### Planned\n- \n';
  }

  @override
  String get completedTasks => 'Completed';

  @override
  String get sortBy => 'Sort by';

  @override
  String get sortByStartTime => 'Start time';

  @override
  String get sortByEndTime => 'End time';

  @override
  String get sortByDuration => 'Duration';

  @override
  String get sortAscending => 'Ascending';

  @override
  String get sortDescending => 'Descending';

  @override
  String get noCompletedTasks => 'No completed tasks';

  @override
  String get batchDelete => 'Delete';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }
}
