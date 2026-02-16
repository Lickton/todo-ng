// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get settings => '设置';

  @override
  String get notifications => '通知';

  @override
  String get defaultPhonePrefix => '默认电话前缀';

  @override
  String get defaultPhonePrefixHint => '如 +86';

  @override
  String get clearAllData => '清除全部数据';

  @override
  String get language => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageEn => 'English';

  @override
  String get languageZh => '简体中文';

  @override
  String get license => '许可';

  @override
  String get version => '版本';

  @override
  String get back => '返回';

  @override
  String get clearAllDataTitle => '清除全部数据？';

  @override
  String get clearAllDataContent => '将删除所有任务并重置应用。此操作无法撤销。';

  @override
  String get cancel => '取消';

  @override
  String get clear => '清除';

  @override
  String get notificationPermissionDenied => '通知权限被拒绝';

  @override
  String get notificationsEnabledAndScheduled => '通知已开启并已排期';

  @override
  String get allNotificationsCancelled => '所有通知已取消';

  @override
  String get notificationPermissionRequired => '需要通知权限';

  @override
  String get notificationsDisabledInSettings => '通知已在设置中关闭';

  @override
  String get testNotification => '测试通知';

  @override
  String get testNotificationBody => '这是一条测试通知，用于验证通知功能是否正常。';

  @override
  String get testNotificationSent => '测试通知已发送';

  @override
  String get allDataCleared => '全部数据已清除';

  @override
  String couldNotOpenUrl(String url) {
    return '无法打开 $url';
  }

  @override
  String get today => '今天';

  @override
  String get calendar => '日历';

  @override
  String get filter => '筛选';

  @override
  String get selectDate => '选择日期';

  @override
  String get selectTime => '选择时间';

  @override
  String get setDate => '设置日期';

  @override
  String get setTime => '设置时间';

  @override
  String get time => '时间';

  @override
  String get dateAndTime => '日期与时间';

  @override
  String get startTime => '开始时间';

  @override
  String get endTime => '结束时间';

  @override
  String get startDate => '开始日期';

  @override
  String get endDate => '结束日期';

  @override
  String get timeKindStartOnly => '仅开始时间（可重复）';

  @override
  String get timeKindEndOnly => '仅结束时间（不重复）';

  @override
  String get timeKindBoth => '开始与结束时间（不重复）';

  @override
  String daysBeforeAt(int days, String time) {
    return '提前 $days 天 $time 提醒';
  }

  @override
  String hoursMinutesBefore(int hours, int minutes) {
    return '提前 $hours 小时 $minutes 分钟';
  }

  @override
  String get completionStatus => '完成状态';

  @override
  String get completed => '已完成';

  @override
  String taskCompletedMessage(String title) {
    return '已完成：$title';
  }

  @override
  String get incomplete => '未完成';

  @override
  String get any => '任意';

  @override
  String get repeat => '重复';

  @override
  String get daily => '每天';

  @override
  String get weekly => '每周';

  @override
  String get monthly => '每月';

  @override
  String get yearly => '每年';

  @override
  String get noRepeat => '不重复';

  @override
  String get mondayShort => '一';

  @override
  String get tuesdayShort => '二';

  @override
  String get wednesdayShort => '三';

  @override
  String get thursdayShort => '四';

  @override
  String get fridayShort => '五';

  @override
  String get saturdayShort => '六';

  @override
  String get sundayShort => '日';

  @override
  String get priority => '优先级';

  @override
  String get priorityRed => '红';

  @override
  String get priorityYellow => '黄';

  @override
  String get priorityBlue => '蓝';

  @override
  String get priorityWhite => '白';

  @override
  String get reminders => '提醒';

  @override
  String get on => '开启';

  @override
  String get off => '关闭';

  @override
  String get applyFilter => '应用筛选';

  @override
  String get clearSelections => '清除选择';

  @override
  String get createTodo => '创建待办';

  @override
  String get modifyTodo => '修改待办';

  @override
  String get setReminder => '设置提醒';

  @override
  String get tellUsAboutTask => '告诉我们你的任务';

  @override
  String get taskLabel => '任务';

  @override
  String get taskInputHint => '告诉我你的任务';

  @override
  String get title => '标题';

  @override
  String get description => '描述';

  @override
  String get sunday => '周日';

  @override
  String get monday => '周一';

  @override
  String get tuesday => '周二';

  @override
  String get wednesday => '周三';

  @override
  String get thursday => '周四';

  @override
  String get friday => '周五';

  @override
  String get saturday => '周六';

  @override
  String get save => '保存';

  @override
  String get saveDraft => '暂存';

  @override
  String get pleaseEnterTitle => '请输入标题';

  @override
  String get pleaseFillActionOrSelectNone => '请填写动作内容或选择「无动作」';

  @override
  String actionOpened(String action) {
    return '已打开 $action';
  }

  @override
  String get actionOpenFailed => '打开失败，请检查是否安装对应应用';

  @override
  String get actionTypeNoAction => '无动作';

  @override
  String get actionTypeNavigation => '导航';

  @override
  String get actionTypePhone => '电话';

  @override
  String get actionTypeWeb => '网页';

  @override
  String get actionTypeMeeting => '会议';

  @override
  String get actionTypeMessage => '消息';

  @override
  String get actionTypeLabelNavigation => '导航';

  @override
  String get actionTypeLabelPhone => '拨打';

  @override
  String get actionTypeLabelWeb => '打开';

  @override
  String get actionTypeLabelMeeting => '会议';

  @override
  String get actionTypeLabelMessage => '消息';

  @override
  String get actionTypeLabelDefault => '动作';

  @override
  String get addAction => '添加动作';

  @override
  String get actionType => '动作类型';

  @override
  String get destinationAddress => '目的地地址';

  @override
  String get inputAddress => '输入地址';

  @override
  String get navApp => '导航应用';

  @override
  String get gaode => '高德';

  @override
  String get baidu => '百度';

  @override
  String get google => '谷歌';

  @override
  String get phoneNumber => '电话号码';

  @override
  String get phoneNumberHint => '请输入中国手机号';

  @override
  String get webUrl => '网页地址';

  @override
  String get meetingIdOrLink => '会议号或会议链接';

  @override
  String get meetingIdOrLinkHint => '会议号或完整链接';

  @override
  String get meetingPlatform => '会议平台';

  @override
  String get tencentMeeting => '腾讯会议';

  @override
  String get zoom => 'Zoom';

  @override
  String get dingtalk => '钉钉';

  @override
  String get messageContent => '消息内容';

  @override
  String get messageContentHint => '预设消息文本';

  @override
  String get contactOptional => '联系人（可选）';

  @override
  String get contactHint => '联系人标识';

  @override
  String get pleaseFillContent => '请填写内容';

  @override
  String get meetingInvitationEmpty => '会议邀请为空';

  @override
  String get tencentMeetingNotInstalled => '腾讯会议未安装';

  @override
  String get phoneError => '请输入正确的中国手机号（11 位）';

  @override
  String get urlError => '请输入以 http:// 或 https:// 开头的网址';

  @override
  String get removeAction => '移除动作';

  @override
  String get delete => '删除';

  @override
  String get addAnotherAction => '添加动作';

  @override
  String versionLabel(String version) {
    return '版本 $version';
  }

  @override
  String get reminder => '提醒';

  @override
  String get reminderEnabled => '开启提醒';

  @override
  String get reminderTime => '提醒时间';

  @override
  String minutesBefore(int minutes) {
    return '提前 $minutes 分钟';
  }

  @override
  String get onTime => '准时';

  @override
  String get customTime => '自定义时间...';

  @override
  String get tapToSetReminderTime => '点击设置提醒时间';

  @override
  String get modify => '修改';

  @override
  String get set => '设置';

  @override
  String get timeNotSet => '未设置';

  @override
  String get quickOptions => '快捷选项';

  @override
  String todayAt(String time) {
    return '今天 $time';
  }

  @override
  String tomorrowAt(String time) {
    return '明天 $time';
  }

  @override
  String get overdue => '过期';

  @override
  String get reschedule => '重新安排';

  @override
  String get noTasks => '没有任务';

  @override
  String get tomorrow => '明天';

  @override
  String get tapToAddTask => '点击下方 + 按钮添加任务';

  @override
  String get thisWeekend => '本周末';

  @override
  String get customDate => '自定义日期';

  @override
  String get goToToday => '回到今天';

  @override
  String tasksRescheduled(int count) {
    return '已重新安排 $count 个任务';
  }

  @override
  String get systemAlarmTitle => '设定系统闹钟';

  @override
  String get systemAlarmSubtitle => '同时在系统闹钟中添加提醒';

  @override
  String get systemAlarmPermissionTitle => '需要闹钟权限';

  @override
  String get systemAlarmPermissionMessage =>
      '为静默添加闹钟，请前往「设置」->「隐私/安全」->「特殊应用权限」->「闹钟和提醒」为本应用授权。';

  @override
  String get goToSettings => '去设置';

  @override
  String get useSystemAlarmFallback => '使用系统界面添加';

  @override
  String get markdownSyntaxHint => 'Markdown 语法提示';

  @override
  String get markdownHintBold => '粗体文字';

  @override
  String get markdownHintItalic => '斜体文字';

  @override
  String get markdownHintHeading => '一级标题';

  @override
  String get markdownHintList => '无序列表';

  @override
  String get markdownHintTask => '待办事项';

  @override
  String get markdownHintLink => '超链接';

  @override
  String get draftFound => '发现草稿';

  @override
  String get draftLoadPrompt => '是否加载上次未保存的内容?';

  @override
  String get ignore => '忽略';

  @override
  String get load => '加载';

  @override
  String get editDescription => '编辑描述';

  @override
  String get edit => '编辑';

  @override
  String get preview => '预览';

  @override
  String get markdownHintStrikethrough => '删除线';

  @override
  String get markdownHintQuote => '引用';

  @override
  String get markdownHintCode => '代码';

  @override
  String get markdownHintOrderedList => '有序列表';

  @override
  String get markdownHintTable => '表格';

  @override
  String get markdownHintImage => '图片';

  @override
  String get insertTemplate => '插入模板';

  @override
  String get meetingNotes => '会议记录';

  @override
  String get todoList => '待办清单';

  @override
  String get dailyLog => '日志模板';

  @override
  String get markdownHintPlaceholder =>
      '支持 Markdown 语法...\n\n# 标题\n**粗体** *斜体*\n- 列表项\n- [ ] 待办事项';

  @override
  String get previewEmpty => '# 预览\n\n暂无内容';

  @override
  String characterCount(int count) {
    return '$count 字符';
  }

  @override
  String get done => '完成';

  @override
  String get fullscreenEdit => '全屏编辑';

  @override
  String get taskReminder => '任务提醒';

  @override
  String get notificationChannelName => '任务提醒';

  @override
  String get notificationChannelDescription => '任务提醒通知';

  @override
  String templateMeetingNotes(String time) {
    return '## 会议记录\n\n**时间**: $time\n**参与者**: \n\n### 议题\n- \n\n### 决议\n- \n\n### 待办事项\n- [ ] \n';
  }

  @override
  String get templateTodoList =>
      '## 待办清单\n\n- [ ] 任务 1\n- [ ] 任务 2\n- [ ] 任务 3\n';

  @override
  String templateDailyLog(String date) {
    return '## $date 日志\n\n### 完成\n- \n\n### 进行中\n- \n\n### 计划\n- \n';
  }

  @override
  String get completedTasks => '已完成';

  @override
  String get sortBy => '排序方式';

  @override
  String get sortByPriority => '优先级';

  @override
  String get sortByStartTime => '开始时间';

  @override
  String get sortByEndTime => '截止时间';

  @override
  String get sortByDuration => '持续时间';

  @override
  String get sortAscending => '升序';

  @override
  String get sortDescending => '降序';

  @override
  String get noCompletedTasks => '暂无已完成任务';

  @override
  String get batchDelete => '删除';

  @override
  String selectedCount(int count) {
    return '已选 $count 项';
  }
}
