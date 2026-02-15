import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import 'package:doable_todo_list_app/l10n/app_localizations.dart';
import 'package:doable_todo_list_app/models/action_item.dart';
import 'package:doable_todo_list_app/models/task_entity.dart';
import 'package:doable_todo_list_app/repositories/task_repository.dart';
import 'package:doable_todo_list_app/services/notification_service.dart';
import 'package:doable_todo_list_app/utils/meeting_utils.dart';
import 'package:doable_todo_list_app/widgets/action_selector.dart';

import 'package:doable_todo_list_app/screens/home_page.dart' show Task;

class TaskDetailSheet extends StatefulWidget {
  const TaskDetailSheet({super.key, required this.task});

  final Task task;

  @override
  State<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<TaskDetailSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  late Task _task;

  bool _reminder = false;
  String? _repeatRule;
  final Set<int> _repeatWeekdays = {};
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  List<ActionItem> _actions = [];
  bool _hasIncompleteAction = false;

  static const Color _blueColor = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _task = widget.task;

    _titleCtrl.text = _task.title;
    _descCtrl.text = _task.description ?? '';

    _reminder = _task.hasNotification;
    _repeatRule = _task.repeatRule;
    _hydrateWeekdaysFromRule(_repeatRule);

    _selectedDate = _parseDateOrNull(_task.date);
    _selectedTime = _parseTimeOrNull(_task.time);

    _actions = _task.actions ?? [];
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

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

  void _hydrateWeekdaysFromRule(String? rule) {
    _repeatWeekdays.clear();
    if (rule == null) return;
    if (!rule.startsWith('Weekly')) return;

    final exp = RegExp(r'(\d+)');
    for (final m in exp.allMatches(rule)) {
      final v = int.tryParse(m.group(1)!);
      if (v != null && v >= 1 && v <= 7) _repeatWeekdays.add(v);
    }
  }

  void _selectRepeatRule(String rule) {
    setState(() {
      _repeatRule = rule;
      if (rule != 'Weekly') {
        _repeatWeekdays.clear();
      }
    });
  }

  void _toggleWeekday(int weekday) {
    setState(() {
      if (_repeatWeekdays.contains(weekday)) {
        _repeatWeekdays.remove(weekday);
      } else {
        _repeatWeekdays.add(weekday);
      }
      if (_repeatWeekdays.isNotEmpty) {
        _repeatRule = 'Weekly';
      }
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: AppLocalizations.of(context)!.selectDate,
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      helpText: AppLocalizations.of(context)!.selectTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  void _toggleReminder() async {
    final userEnabled = await NotificationService.areNotificationsEnabledByUser();

    if (!userEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Notifications are disabled in settings'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () {
              Navigator.pushNamed(context, 'settings');
            },
          ),
        ),
      );
      return;
    }

    setState(() => _reminder = !_reminder);
  }

  Future<void> _save() async {
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

    final dateStr = _selectedDate != null ? _formatDate(_selectedDate!) : null;
    final timeStr = _selectedTime != null ? _formatTime(_selectedTime!) : null;

    String? normalizedRepeat;
    if (_repeatRule == null || _repeatRule == 'No repeat') {
      normalizedRepeat = null;
    } else if (_repeatRule == 'Weekly' && _repeatWeekdays.isNotEmpty) {
      final list = _repeatWeekdays.toList()..sort();
      normalizedRepeat = 'Weekly:${list.toString()}';
    } else {
      normalizedRepeat = _repeatRule;
    }

    final validActions = _actions
        .where((a) =>
            a.type.isNotEmpty && (a.data?.trim().isNotEmpty == true))
        .toList();
    final entity = TaskEntity(
      id: _task.id,
      title: title,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      time: timeStr,
      date: dateStr,
      hasNotification: _reminder,
      repeatRule: normalizedRepeat,
      completed: _task.completed,
      actions: validActions.isEmpty ? null : validActions,
    );

    await TaskRepository().update(entity);

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final initialSize = viewInsets > 0 ? 0.95 : 0.7;

    return DraggableScrollableSheet(
      initialChildSize: initialSize,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _buildDragHandle(),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: _buildContent(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDragHandle() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    const spacing = 16.0;
    const bigSpacing = 24.0;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReminderButton(
            enabled: _reminder,
            onTap: _toggleReminder,
          ),
          const SizedBox(height: bigSpacing),

          _FieldLabel(text: AppLocalizations.of(context)!.tellUsAboutTask),
          const SizedBox(height: spacing),

          _InputField(
            controller: _titleCtrl,
            hint: AppLocalizations.of(context)!.title,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: spacing),
          _InputField(
            controller: _descCtrl,
            hint: AppLocalizations.of(context)!.description,
            maxLines: 3,
          ),
          const SizedBox(height: bigSpacing),

          _FieldLabel(text: AppLocalizations.of(context)!.repeat),
          const SizedBox(height: spacing),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _RepeatChip(
                label: AppLocalizations.of(context)!.daily,
                selected: _repeatRule == 'Daily',
                onTap: () => _selectRepeatRule('Daily'),
              ),
              _RepeatChip(
                label: AppLocalizations.of(context)!.weekly,
                selected: _repeatRule == 'Weekly',
                onTap: () => _selectRepeatRule('Weekly'),
              ),
              _RepeatChip(
                label: AppLocalizations.of(context)!.monthly,
                selected: _repeatRule == 'Monthly',
                onTap: () => _selectRepeatRule('Monthly'),
              ),
              _RepeatChip(
                label: AppLocalizations.of(context)!.noRepeat,
                selected: _repeatRule == null || _repeatRule == 'No repeat',
                onTap: () => _selectRepeatRule('No repeat'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _WeekdayChip(
                label: AppLocalizations.of(context)!.sunday,
                selected: _repeatWeekdays.contains(7),
                onTap: () => _toggleWeekday(7),
              ),
              _WeekdayChip(
                label: AppLocalizations.of(context)!.monday,
                selected: _repeatWeekdays.contains(1),
                onTap: () => _toggleWeekday(1),
              ),
              _WeekdayChip(
                label: AppLocalizations.of(context)!.tuesday,
                selected: _repeatWeekdays.contains(2),
                onTap: () => _toggleWeekday(2),
              ),
              _WeekdayChip(
                label: AppLocalizations.of(context)!.wednesday,
                selected: _repeatWeekdays.contains(3),
                onTap: () => _toggleWeekday(3),
              ),
              _WeekdayChip(
                label: AppLocalizations.of(context)!.thursday,
                selected: _repeatWeekdays.contains(4),
                onTap: () => _toggleWeekday(4),
              ),
              _WeekdayChip(
                label: AppLocalizations.of(context)!.friday,
                selected: _repeatWeekdays.contains(5),
                onTap: () => _toggleWeekday(5),
              ),
              _WeekdayChip(
                label: AppLocalizations.of(context)!.saturday,
                selected: _repeatWeekdays.contains(6),
                onTap: () => _toggleWeekday(6),
              ),
            ],
          ),
          const SizedBox(height: bigSpacing),

          ActionSelector(
            showTitle: true,
            initialActions: _actions,
            onActionsChanged: (list) => setState(() => _actions = list),
            onHasIncompleteChanged: (v) =>
                setState(() => _hasIncompleteAction = v),
          ),
          const SizedBox(height: bigSpacing),

          _FieldLabel(text: AppLocalizations.of(context)!.dateAndTime),
          const SizedBox(height: spacing),

          _PickerField(
            hint: AppLocalizations.of(context)!.setDate,
            valueText:
                _selectedDate != null ? _formatDate(_selectedDate!) : null,
            iconAsset: 'assets/calendar.svg',
            onTap: _pickDate,
            onClear: _selectedDate != null
                ? () => setState(() => _selectedDate = null)
                : null,
          ),
          const SizedBox(height: spacing),

          _PickerField(
            hint: AppLocalizations.of(context)!.setTime,
            valueText:
                _selectedTime != null ? _formatTime(_selectedTime!) : null,
            iconAsset: 'assets/clock.svg',
            onTap: _pickTime,
            onClear: _selectedTime != null
                ? () => setState(() => _selectedTime = null)
                : null,
          ),
          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blueColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context)!.save,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

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

class _ReminderButton extends StatelessWidget {
  const _ReminderButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;

  static const _blueColor = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    final bg = enabled ? _blueColor : Colors.white;
    final fg = enabled ? Colors.white : Colors.black;

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: bg,
        shape: StadiumBorder(
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context)!.setReminder,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                SvgPicture.asset(
                  enabled ? 'assets/bell_white.svg' : 'assets/bell.svg',
                  height: 18,
                  width: 18,
                  colorFilter: enabled
                      ? null
                      : const ColorFilter.mode(Colors.black87, BlendMode.srcIn),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RepeatChip extends StatelessWidget {
  const _RepeatChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? Colors.black : Colors.white;
    final fg = selected ? Colors.white : Colors.black;

    return Material(
      color: bg,
      shape: StadiumBorder(side: BorderSide(color: Colors.grey.shade300)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekdayChip extends StatelessWidget {
  const _WeekdayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? Colors.black : Colors.white;
    final fg = selected ? Colors.white : Colors.black;

    return Material(
      color: bg,
      shape: StadiumBorder(side: BorderSide(color: Colors.grey.shade300)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.hint,
    required this.iconAsset,
    required this.onTap,
    this.valueText,
    this.onClear,
  });

  final String hint;
  final String iconAsset;
  final String? valueText;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final hasValue = valueText != null && valueText!.isNotEmpty;

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              SvgPicture.asset(
                iconAsset,
                height: 18,
                width: 18,
                colorFilter:
                    const ColorFilter.mode(Colors.black87, BlendMode.srcIn),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasValue ? valueText! : hint,
                  style: TextStyle(
                    color: hasValue ? Colors.black : Colors.black54,
                    fontWeight: hasValue ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
              if (hasValue && onClear != null)
                IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close, size: 20, color: Colors.black54),
                  onPressed: onClear,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
