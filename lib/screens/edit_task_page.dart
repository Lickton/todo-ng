import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:doable_todo_list_app/l10n/app_localizations.dart';
import 'package:doable_todo_list_app/models/action_item.dart';
import 'package:doable_todo_list_app/utils/meeting_utils.dart';
import 'package:doable_todo_list_app/repositories/task_repository.dart';
import 'package:doable_todo_list_app/widgets/action_selector.dart';
import 'package:doable_todo_list_app/models/task_entity.dart';
import 'package:doable_todo_list_app/utils/task_schedule_codec.dart';
import 'package:doable_todo_list_app/widgets/date_time_picker_section.dart';
import 'package:doable_todo_list_app/widgets/description_markdown_field.dart';
import 'package:doable_todo_list_app/services/system_alarm_service.dart';
import 'package:doable_todo_list_app/widgets/reminder_setting_field.dart';

// Import Task view model from Home if you keep it there,
// or duplicate the minimal fields you need here.
import 'package:doable_todo_list_app/screens/home_page.dart' show Task;

class EditTaskPage extends StatefulWidget {
  const EditTaskPage({super.key});

  @override
  State<EditTaskPage> createState() => _EditTaskPageState();
}

class _EditTaskPageState extends State<EditTaskPage> {
  // Controllers
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // Incoming task to edit
  late Task _task;

  // UI state
  bool _reminder = false;
  String? _reminderTime;
  bool _useSystemAlarm = false;
  late DateTimeSectionState _scheduleState;

  // Action (optional, supports multiple)
  List<ActionItem> _actions = [];
  bool _hasIncompleteAction = false;

  /// 全屏 Markdown 编辑打开时隐藏主保存按钮
  bool _isFullscreenMarkdown = false;

  /// 保存前触发，将描述区内联未暂存内容同步到 controller
  final _descFlushRequested = ValueNotifier<int>(0);

  // Convenience paddings
  EdgeInsets get _screenHPad {
    final w = MediaQuery.of(context).size.width;
    final hpad = (w * 0.05).clamp(16.0, 24.0);
    return EdgeInsets.symmetric(horizontal: hpad);
  }

  @override
  void initState() {
    super.initState();
    // Read arguments after first frame to ensure context is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final arg = ModalRoute.of(context)!.settings.arguments;
      _task = arg as Task;

      // Prefill text
      _titleCtrl.text = _task.title;
      _descCtrl.text = _task.description ?? '';

      // Prefill toggles
      _reminder = _task.hasNotification;
      _useSystemAlarm = _task.useSystemAlarm;
      final selectedDate = _parseDateOrNull(_task.date) ?? DateTime.now();
      final selectedTime =
          _parseTimeOrNull(_task.time) ?? const TimeOfDay(hour: 0, minute: 0);
      _scheduleState = DateTimeSectionState(
        dateEnabled: (_task.date ?? '').trim().isNotEmpty,
        timeEnabled: (_task.time ?? '').trim().isNotEmpty,
        repeatEnabled: (_task.repeatRule ?? '').trim().isNotEmpty,
        date: selectedDate,
        time: selectedTime,
        repeat: _repeatUiFromStorage(_task.repeatRule),
      ).normalized();
      _reminderTime = ReminderRule.toLegacyUi(
        _task.reminderTime,
        occurrenceDateTime: DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          selectedTime.hour,
          selectedTime.minute,
        ),
      );

      // Prefill action
      _actions = _task.actions ?? [];

      setState(() {});
    });
  }

  @override
  void dispose() {
    _descFlushRequested.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ===== Formatting / parsing =====

  String _formatDate(DateTime d) => DateFormat('dd/MM/yy').format(d);

  String _formatTime(TimeOfDay t) {
    final dt = DateTime(0, 1, 1, t.hour, t.minute);
    return DateFormat('h:mm a').format(dt);
  }

  DateTime? _parseDateOrNull(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    try {
      return DateFormat('dd/MM/yy').parseStrict(s);
    } catch (_) {
      return null;
    }
  }

  TimeOfDay? _parseTimeOrNull(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    try {
      final dt = DateFormat('h:mm a').parseStrict(s);
      return TimeOfDay.fromDateTime(dt);
    } catch (_) {
      return null;
    }
  }

  RepeatUiConfig _repeatUiFromStorage(String? rule) {
    final parsed = RepeatSelection.fromStorage(rule);
    switch (parsed.frequency) {
      case RepeatFrequency.weekly:
        return RepeatUiConfig(
          type: RepeatUiType.weekly,
          weekdays: parsed.weekdays,
        );
      case RepeatFrequency.monthly:
        return RepeatUiConfig(
          type: RepeatUiType.monthly,
          monthDays: parsed.monthDays,
        );
      case RepeatFrequency.daily:
        return const RepeatUiConfig(type: RepeatUiType.daily);
      default:
        return const RepeatUiConfig(type: RepeatUiType.daily);
    }
  }

  RepeatSelection _repeatSelectionFromState(RepeatUiConfig repeat) {
    switch (repeat.type) {
      case RepeatUiType.daily:
        return const RepeatSelection(frequency: RepeatFrequency.daily);
      case RepeatUiType.weekly:
        return RepeatSelection(
          frequency: RepeatFrequency.weekly,
          weekdays: Set<int>.from(repeat.weekdays),
        );
      case RepeatUiType.monthly:
        return RepeatSelection(
          frequency: RepeatFrequency.monthly,
          monthDays: Set<int>.from(repeat.monthDays),
        );
    }
  }

  // ===== Pickers =====

  // ===== Save =====

  Future<void> _save() async {
    _descFlushRequested.value++;
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseEnterTitle)),
      );
      return;
    }

    if (_hasIncompleteAction) {
      final hasMeetingIncomplete = _actions.any((a) =>
          a.type == 'meeting' &&
          (a.data == null ||
              a.data!.trim().isEmpty ||
              !MeetingUtils.hasValidMeetingData(a.data!)));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasMeetingIncomplete
                ? AppLocalizations.of(context)!.meetingInvitationEmpty
                : AppLocalizations.of(context)!.pleaseFillActionOrSelectNone,
          ),
        ),
      );
      return;
    }

    // Build display strings
    final dateStr =
        _scheduleState.dateEnabled ? _formatDate(_scheduleState.date) : null;
    final timeStr =
        _scheduleState.timeEnabled ? _formatTime(_scheduleState.time) : null;

    final occurrenceDateTime = DateTime(
      _scheduleState.date.year,
      _scheduleState.date.month,
      _scheduleState.date.day,
      _scheduleState.time.hour,
      _scheduleState.time.minute,
    );
    final repeatSelection = _scheduleState.repeatEnabled
        ? _repeatSelectionFromState(_scheduleState.repeat)
        : const RepeatSelection(frequency: RepeatFrequency.none);
    final normalizedRepeat = repeatSelection.toStorage();
    final reminderEnabled = _reminder && _scheduleState.timeEnabled;
    final reminderStorage = reminderEnabled
        ? ReminderRule.fromUi(
            _reminderTime,
            occurrenceDateTime: occurrenceDateTime,
          )?.toStorage()
        : null;

    final validActions = _actions
        .where((a) => a.type.isNotEmpty && (a.data?.trim().isNotEmpty == true))
        .toList();
    final entity = TaskEntity(
      id: _task.id,
      title: title,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text,
      time: timeStr,
      date: dateStr,
      timeKind: TimeKind.startOnly,
      endTime: null,
      endDate: null,
      hasNotification: reminderEnabled,
      reminderTime: reminderStorage,
      useSystemAlarm: reminderEnabled ? _useSystemAlarm : false,
      repeatRule: normalizedRepeat,
      completed: _task.completed,
      actions: validActions.isEmpty ? null : validActions,
    );

    await TaskRepository().update(entity);

    if (mounted &&
        reminderEnabled &&
        _useSystemAlarm &&
        SystemAlarmService.instance.isSupported) {
      final hm = ReminderSettingField.getReminderHourMinute(
        reminderTime: _reminderTime,
        taskDate: _scheduleState.date,
        taskTime: _scheduleState.time,
      );
      if (hm != null && mounted) {
        await SystemAlarmService.instance.createAlarm(
          hour: hm.$1,
          minute: hm.$2,
          title: title,
          context: context,
          getPermissionTitle: () =>
              AppLocalizations.of(context)!.systemAlarmPermissionTitle,
          getPermissionMessage: () =>
              AppLocalizations.of(context)!.systemAlarmPermissionMessage,
          getGoToSettingsLabel: () =>
              AppLocalizations.of(context)!.goToSettings,
          getCancelLabel: () =>
              AppLocalizations.of(context)!.useSystemAlarmFallback,
        );
      }
    }

    if (mounted) Navigator.pop(context, true); // signal Home to refresh
  }

  @override
  Widget build(BuildContext context) {
    // 编辑模式：有 arguments 时需等待 addPostFrameCallback 加载任务数据后再渲染表单，
    // 否则 ActionSelector 会在 initState 收到 null，导致已保存的动作无法正确回显
    final hasArgs = ModalRoute.of(context)?.settings.arguments != null;
    if (hasArgs && _titleCtrl.text.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final spacing = 16.0;
    final bigSpacing = 24.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.pop(context, false),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          tooltip: AppLocalizations.of(context)!.back,
        ),
        title: Text(
          AppLocalizations.of(context)!.modifyTodo,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: _screenHPad.add(EdgeInsets.only(
            bottom: _isFullscreenMarkdown ? 24 : 120,
            top: 8,
          )),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldLabel(text: AppLocalizations.of(context)!.taskLabel),
              SizedBox(height: spacing),
              _InputField(
                controller: _titleCtrl,
                hint: AppLocalizations.of(context)!.title,
                textInputAction: TextInputAction.next,
              ),
              SizedBox(height: bigSpacing),
              _FieldLabel(text: AppLocalizations.of(context)!.description),
              SizedBox(height: spacing),
              DescriptionField(
                controller: _descCtrl,
                hintText: AppLocalizations.of(context)!.description,
                onChanged: () => setState(() {}),
              ),
              SizedBox(height: bigSpacing),

              // 选择日期与时间
              _FieldLabel(text: AppLocalizations.of(context)!.dateAndTime),
              SizedBox(height: spacing),
              DateTimePickerSection(
                state: _scheduleState,
                onChanged: (next) => setState(() {
                  _scheduleState = next;
                  if (!_scheduleState.timeEnabled) {
                    _reminder = false;
                    _reminderTime = null;
                    _useSystemAlarm = false;
                  }
                }),
              ),
              SizedBox(height: bigSpacing),

              // Action selector
              ActionSelector(
                showTitle: true,
                initialActions: _actions,
                onActionsChanged: (list) => setState(() => _actions = list),
                onHasIncompleteChanged: (v) =>
                    setState(() => _hasIncompleteAction = v),
              ),
              SizedBox(height: bigSpacing),

              // 提醒（含重复，仅开始时间可重复）
              _FieldLabel(text: AppLocalizations.of(context)!.reminder),
              SizedBox(height: spacing),
              if (_scheduleState.timeEnabled)
                ReminderSettingField(
                  reminderEnabled: _reminder,
                  reminderTime: _reminderTime,
                  taskDate: _scheduleState.date,
                  taskTime: _scheduleState.time,
                  onReminderChanged: (enabled, time) => setState(() {
                    _reminder = enabled;
                    _reminderTime = time;
                  }),
                  useSystemAlarm: _useSystemAlarm,
                  onSystemAlarmChanged: Platform.isAndroid
                      ? (v) => setState(() => _useSystemAlarm = v)
                      : null,
                ),
              if (!_scheduleState.timeEnabled)
                Text(
                  '未启用时间，提醒不可用',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/* ================= Reusable widgets ================= */

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: textInputAction,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
        ),
      ),
      style: const TextStyle(fontSize: 14, height: 1.4),
    );
  }
}
