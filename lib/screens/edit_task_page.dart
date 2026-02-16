import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:doable_todo_list_app/l10n/app_localizations.dart';
import 'package:doable_todo_list_app/models/action_item.dart';
import 'package:doable_todo_list_app/utils/meeting_utils.dart';
import 'package:doable_todo_list_app/repositories/task_repository.dart';
import 'package:doable_todo_list_app/widgets/action_selector.dart';
import 'package:doable_todo_list_app/models/task_entity.dart';
import 'package:doable_todo_list_app/widgets/date_time_picker_section.dart';
import 'package:doable_todo_list_app/widgets/description_markdown_field.dart';
import 'package:doable_todo_list_app/services/system_alarm_service.dart';
import 'package:doable_todo_list_app/widgets/priority_picker_field.dart';
import 'package:doable_todo_list_app/widgets/reminder_setting_field.dart';
import 'package:doable_todo_list_app/widgets/repeat_picker_field.dart';

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
  TaskPriority _priority = TaskPriority.white;
  bool _reminder = false;
  String? _reminderTime;
  bool _useSystemAlarm = false;
  TimeKind _timeKind = TimeKind.startOnly;
  String? _repeatRule;
  final Set<int> _repeatWeekdays = {};
  final Set<int> _repeatMonthDays = {};
  final Map<int, Set<int>> _repeatYearMonthDays = {};
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  DateTime? _selectedEndDate;
  TimeOfDay? _selectedEndTime;

  // Action (optional, supports multiple)
  List<ActionItem> _actions = [];
  bool _hasIncompleteAction = false;

  /// 全屏 Markdown 编辑打开时隐藏主保存按钮
  bool _isFullscreenMarkdown = false;

  /// 保存前触发，将描述区内联未暂存内容同步到 controller
  final _descFlushRequested = ValueNotifier<int>(0);

  // Style constants
  static const Color blueColor = Color(0xFF2563EB); // button/active color

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
      _priority = _task.priority;
      _reminder = _task.hasNotification;
      _reminderTime = _task.reminderTime;
      _useSystemAlarm = _task.useSystemAlarm;
      _repeatRule = _task.repeatRule;
      _hydrateAllFromRule(_repeatRule);
      _timeKind = _task.timeKind;

      // Prefill date/time
      _selectedDate = _parseDateOrNull(_task.date) ?? DateTime.now();
      _selectedTime = _parseTimeOrNull(_task.time) ?? const TimeOfDay(hour: 0, minute: 0);
      _selectedEndDate = _parseDateOrNull(_task.endDate);
      _selectedEndTime = _parseTimeOrNull(_task.endTime);

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

  void _hydrateAllFromRule(String? rule) {
    _repeatWeekdays.clear();
    _repeatMonthDays.clear();
    _repeatYearMonthDays.clear();
    if (rule == null) return;
    final colon = rule.indexOf(':');
    if (colon < 0 || colon + 1 >= rule.length) return;
    final suffix = rule.substring(colon + 1).trim();
    if (rule.startsWith('Weekly')) {
      for (final s in suffix.split(RegExp(r'[,\s\[\]]+'))) {
        final v = int.tryParse(s.trim());
        if (v != null && v >= 1 && v <= 7) _repeatWeekdays.add(v);
      }
    } else if (rule.startsWith('Monthly')) {
      for (final s in suffix.split(RegExp(r'[,\s\[\]]+'))) {
        final v = int.tryParse(s.trim());
        if (v != null && v >= 1 && v <= 31) _repeatMonthDays.add(v);
      }
    } else if (rule.startsWith('Yearly')) {
      for (final part in suffix.split(',')) {
        final dash = part.indexOf('-');
        if (dash > 0 && dash < part.length - 1) {
          final m = int.tryParse(part.substring(0, dash).trim());
          final d = int.tryParse(part.substring(dash + 1).trim());
          if (m != null && d != null && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
            _repeatYearMonthDays.putIfAbsent(m, () => {}).add(d);
          }
        }
      }
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
          (a.data == null || a.data!.trim().isEmpty || !MeetingUtils.hasValidMeetingData(a.data!)));
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
    final dateStr = _formatDate(_selectedDate);
    final timeStr = _formatTime(_selectedTime);
    final endDateStr = _selectedEndDate != null ? _formatDate(_selectedEndDate!) : null;
    final endTimeStr = _selectedEndTime != null ? _formatTime(_selectedEndTime!) : null;

    String? normalizedRepeat;
    if (_timeKind != TimeKind.startOnly) {
      normalizedRepeat = null;
    } else if (_repeatRule == null || _repeatRule == 'No repeat') {
      normalizedRepeat = null;
    } else if (_repeatRule == 'Weekly' && _repeatWeekdays.isNotEmpty) {
      normalizedRepeat = 'Weekly:${_repeatWeekdays.toList()..sort()}';
    } else if (_repeatRule == 'Monthly' && _repeatMonthDays.isNotEmpty) {
      normalizedRepeat = 'Monthly:${_repeatMonthDays.toList()..sort()}';
    } else if (_repeatRule == 'Yearly' && _repeatYearMonthDays.isNotEmpty) {
      final parts = <String>[];
      for (final e in _repeatYearMonthDays.entries) {
        for (final d in e.value) {
          parts.add('${e.key}-$d');
        }
      }
      parts.sort();
      normalizedRepeat = 'Yearly:${parts.join(',')}';
    } else {
      normalizedRepeat = _repeatRule;
    }

    final validActions = _actions.where((a) => a.type.isNotEmpty && (a.data?.trim().isNotEmpty == true)).toList();
    final entity = TaskEntity(
      id: _task.id,
      title: title,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text,
      priority: _priority,
      time: timeStr,
      date: dateStr,
      timeKind: _timeKind,
      endTime: endTimeStr,
      endDate: endDateStr,
      hasNotification: _reminder,
      reminderTime: _reminder ? _reminderTime : null,
      useSystemAlarm: _useSystemAlarm,
      repeatRule: normalizedRepeat,
      completed: _task.completed,
      actions: validActions.isEmpty ? null : validActions,
    );

    await TaskRepository().update(entity);

    if (mounted && _reminder && _useSystemAlarm && SystemAlarmService.instance.isSupported) {
      final hm = ReminderSettingField.getReminderHourMinute(
        reminderTime: _reminderTime,
        taskDate: _selectedDate,
        taskTime: _selectedTime,
      );
      if (hm != null && mounted) {
        await SystemAlarmService.instance.createAlarm(
          hour: hm.$1,
          minute: hm.$2,
          title: title,
          context: context,
          getPermissionTitle: () => AppLocalizations.of(context)!.systemAlarmPermissionTitle,
          getPermissionMessage: () => AppLocalizations.of(context)!.systemAlarmPermissionMessage,
          getGoToSettingsLabel: () => AppLocalizations.of(context)!.goToSettings,
          getCancelLabel: () => AppLocalizations.of(context)!.useSystemAlarmFallback,
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
              SizedBox(height: spacing),
              _FieldLabel(text: AppLocalizations.of(context)!.priority),
              SizedBox(height: spacing),
              PriorityPickerField(
                value: _priority,
                onChanged: (p) => setState(() => _priority = p),
              ),
              SizedBox(height: bigSpacing),
              _FieldLabel(text: AppLocalizations.of(context)!.description),
              SizedBox(height: spacing),
              DescriptionMarkdownField(
                controller: _descCtrl,
                hintText: AppLocalizations.of(context)!.description,
                onChanged: () => setState(() {}),
                onFullscreenChanged: (v) =>
                    setState(() => _isFullscreenMarkdown = v),
                flushRequested: _descFlushRequested,
              ),
              SizedBox(height: bigSpacing),

              // 选择日期与时间
              _FieldLabel(text: AppLocalizations.of(context)!.dateAndTime),
              SizedBox(height: spacing),
              DateTimePickerSection(
                timeKind: _timeKind,
                selectedDate: _selectedDate,
                selectedTime: _selectedTime,
                onDateChanged: (d) => setState(() => _selectedDate = d),
                onTimeChanged: (t) => setState(() => _selectedTime = t),
                onTimeKindChanged: (k) => setState(() {
                  _timeKind = k;
                  if (k == TimeKind.both) {
                    _selectedEndDate ??= _selectedDate.add(const Duration(days: 1));
                    _selectedEndTime ??= _selectedTime;
                  } else {
                    _selectedEndDate = null;
                    _selectedEndTime = null;
                  }
                }),
                selectedEndDate: _selectedEndDate,
                selectedEndTime: _selectedEndTime,
                onEndDateChanged: (d) => setState(() => _selectedEndDate = d),
                onEndTimeChanged: (t) => setState(() => _selectedEndTime = t),
              ),
              SizedBox(height: bigSpacing),

              // Action selector
              ActionSelector(
                showTitle: true,
                initialActions: _actions,
                onActionsChanged: (list) => setState(() => _actions = list),
                onHasIncompleteChanged: (v) => setState(() => _hasIncompleteAction = v),
              ),
              SizedBox(height: bigSpacing),

              // 提醒（含重复，仅开始时间可重复）
              _FieldLabel(text: AppLocalizations.of(context)!.reminder),
              SizedBox(height: spacing),
              if (_timeKind == TimeKind.startOnly)
                RepeatPickerField(
                repeatRule: _repeatRule,
                repeatWeekdays: _repeatWeekdays,
                repeatMonthDays: _repeatMonthDays,
                repeatYearMonthDays: _repeatYearMonthDays,
                selectedTime: _selectedTime,
                onTimeChanged: (t) => setState(() => _selectedTime = t ?? const TimeOfDay(hour: 0, minute: 0)),
                showTimePicker: false,
                onChanged: (rule, {weekdays, monthDays, yearMonthDays}) {
                  setState(() {
                    _repeatRule = rule;
                    _repeatWeekdays.clear();
                    _repeatWeekdays.addAll(weekdays ?? {});
                    _repeatMonthDays.clear();
                    _repeatMonthDays.addAll(monthDays ?? {});
                    _repeatYearMonthDays.clear();
                    _repeatYearMonthDays.addAll(yearMonthDays ?? {});
                  });
                },
              ),
              if (_timeKind == TimeKind.startOnly) const SizedBox(height: 12),
              ReminderSettingField(
                reminderEnabled: _reminder,
                reminderTime: _reminderTime,
                taskDate: _selectedDate,
                taskTime: _selectedTime,
                onReminderChanged: (enabled, time) =>
                    setState(() {
                      _reminder = enabled;
                      _reminderTime = time;
                    }),
                useSystemAlarm: _useSystemAlarm,
                onSystemAlarmChanged: Platform.isAndroid
                    ? (v) => setState(() => _useSystemAlarm = v)
                    : null,
              ),
              const SizedBox(height: 8),
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
                      backgroundColor: const Color(0xFF3B82F6),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
