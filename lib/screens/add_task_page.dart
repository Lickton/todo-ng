import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Data layer
import 'package:doable_todo_list_app/l10n/app_localizations.dart';
import 'package:doable_todo_list_app/models/action_item.dart';
import 'package:doable_todo_list_app/utils/meeting_utils.dart';
import 'package:doable_todo_list_app/repositories/task_repository.dart';
import 'package:doable_todo_list_app/widgets/action_selector.dart';
import 'package:doable_todo_list_app/services/system_alarm_service.dart';
import 'package:doable_todo_list_app/models/task_entity.dart';
import 'package:doable_todo_list_app/utils/task_schedule_codec.dart';
import 'package:doable_todo_list_app/widgets/date_time_picker_section.dart';
import 'package:doable_todo_list_app/widgets/description_markdown_field.dart';
import 'package:doable_todo_list_app/widgets/reminder_setting_field.dart';

class AddTaskPage extends StatefulWidget {
  const AddTaskPage({super.key});

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  // Controllers
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // State
  bool _reminder = false;
  String? _reminderTime; // offset:5, offset:0, custom:..., or absolute
  bool _useSystemAlarm = false;
  DateTimeSectionState _scheduleState = DateTimeSectionState.initial();

  // Action (optional, supports multiple)
  List<ActionItem> _actions = [];
  bool _hasIncompleteAction = false;

  /// 全屏 Markdown 编辑打开时隐藏主保存按钮
  bool _isFullscreenMarkdown = false;

  /// 保存前触发，将描述区内联未暂存内容同步到 controller
  final _descFlushRequested = ValueNotifier<int>(0);

  // Colors (replace with Theme if preferred)
  static const Color blueColor = Color(0xFF2563EB); // Tailwind-ish blue-600
  static const Color black = Colors.black;
  static const Color white = Colors.white;
  static const double kRadius = 16;

  // Layout helpers
  EdgeInsets get _screenHPad {
    final w = MediaQuery.of(context).size.width;
    final hpad = (w * 0.05).clamp(16.0, 24.0); // 5% with sensible bounds
    return EdgeInsets.symmetric(horizontal: hpad);
  }

  String _formatDate(DateTime d) => DateFormat('dd/MM/yy').format(d);
  String _formatTime(TimeOfDay t) {
    final dt = DateTime(0, 1, 1, t.hour, t.minute);
    return DateFormat('h:mm a').format(dt);
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
    final repeatRule = repeatSelection.toStorage();
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
      repeatRule: repeatRule,
      completed: false,
      actions: validActions.isEmpty ? null : validActions,
    );

    await TaskRepository().add(entity);

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

    if (mounted) Navigator.pop(context, true); // return true so Home reloads
  }

  @override
  void dispose() {
    _descFlushRequested.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = 16.0;
    final bigSpacing = 24.0;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: white,
        elevation: 0,
        surfaceTintColor: white,
        leading: IconButton(
          onPressed: () => Navigator.pop(context, false),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          tooltip: AppLocalizations.of(context)!.back,
        ),
        title: Text(
          AppLocalizations.of(context)!.createTodo,
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
          padding: EdgeInsets.only(
            bottom: _isFullscreenMarkdown ? 24 : 120,
          ).add(_screenHPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title / Description
              _FieldLabel(text: AppLocalizations.of(context)!.taskLabel),
              SizedBox(height: spacing),
              _InputField(
                controller: _titleCtrl,
                hint: AppLocalizations.of(context)!.taskInputHint,
                textInputAction: TextInputAction.next,
              ),
              SizedBox(height: spacing),
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

              // 提醒（含重复）
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

              // Bottom spacing
              SizedBox(height: width * 0.1),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _isFullscreenMarkdown
          ? null
          : Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                32 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 56,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6), // Blue 500
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    onPressed: _save,
                    child: Text(AppLocalizations.of(context)!.save),
                  ),
                ),
              ),
            ),
    );
  }
}

/* ---------- Reusable widgets ---------- */

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
