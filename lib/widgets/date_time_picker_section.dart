import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:doable_todo_list_app/l10n/app_localizations.dart';
import 'package:doable_todo_list_app/models/task_entity.dart';

/// 日期与时间选择区域，支持开始/结束时间区分
/// - start_only: 仅开始日期+时间，可重复
/// - end_only: 仅结束日期+时间，不重复
/// - both: 开始+结束都有，不重复
class DateTimePickerSection extends StatelessWidget {
  const DateTimePickerSection({
    super.key,
    required this.timeKind,
    required this.selectedDate,
    required this.selectedTime,
    required this.onDateChanged,
    required this.onTimeChanged,
    this.onTimeKindChanged,
    this.selectedEndDate,
    this.selectedEndTime,
    this.onEndDateChanged,
    this.onEndTimeChanged,
  });

  final TimeKind timeKind;
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final void Function(DateTime) onDateChanged;
  final void Function(TimeOfDay) onTimeChanged;
  final void Function(TimeKind)? onTimeKindChanged;
  final DateTime? selectedEndDate;
  final TimeOfDay? selectedEndTime;
  final void Function(DateTime)? onEndDateChanged;
  final void Function(TimeOfDay)? onEndTimeChanged;

  static String formatDate(DateTime d) => DateFormat('dd/MM/yy').format(d);

  static String formatTime(TimeOfDay t) {
    final dt = DateTime(0, 1, 1, t.hour, t.minute);
    return DateFormat('h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 时间类型选择（可选）
        if (onTimeKindChanged != null) ...[
          _TimeKindSelector(
            timeKind: timeKind,
            onChanged: onTimeKindChanged!,
          ),
          const SizedBox(height: 12),
        ],
        // 主日期+时间（开始或结束，取决于 timeKind）
        _DateTile(
          label: timeKind == TimeKind.endOnly ? l10n.endDate : l10n.startDate,
          date: selectedDate,
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              helpText: l10n.selectDate,
            );
            if (picked != null) onDateChanged(picked);
          },
        ),
        const SizedBox(height: 12),
        _TimeTile(
          label: timeKind == TimeKind.endOnly ? l10n.endTime : l10n.startTime,
          time: selectedTime,
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: selectedTime,
              helpText: l10n.selectTime,
            );
            if (picked != null) onTimeChanged(picked);
          },
        ),
        // 结束日期+时间（仅 both 时显示）
        if (timeKind == TimeKind.both &&
            selectedEndDate != null &&
            selectedEndTime != null &&
            onEndDateChanged != null &&
            onEndTimeChanged != null) ...[
          const SizedBox(height: 12),
          _DateTile(
            label: l10n.endDate,
            date: selectedEndDate!,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedEndDate!,
                firstDate: selectedDate,
                lastDate: DateTime(2100),
                helpText: l10n.selectDate,
              );
              if (picked != null) onEndDateChanged!(picked);
            },
          ),
          const SizedBox(height: 12),
          _TimeTile(
            label: l10n.endTime,
            time: selectedEndTime!,
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: selectedEndTime!,
                helpText: l10n.selectTime,
              );
              if (picked != null) onEndTimeChanged!(picked);
            },
          ),
        ],
      ],
    );
  }
}

class _TimeKindSelector extends StatelessWidget {
  const _TimeKindSelector({
    required this.timeKind,
    required this.onChanged,
  });

  final TimeKind timeKind;
  final void Function(TimeKind) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          _TimeKindOption(
            label: l10n.timeKindStartOnly,
            selected: timeKind == TimeKind.startOnly,
            onTap: () => onChanged(TimeKind.startOnly),
          ),
          Divider(height: 1, color: Colors.grey.shade300),
          _TimeKindOption(
            label: l10n.timeKindEndOnly,
            selected: timeKind == TimeKind.endOnly,
            onTap: () => onChanged(TimeKind.endOnly),
          ),
          Divider(height: 1, color: Colors.grey.shade300),
          _TimeKindOption(
            label: l10n.timeKindBoth,
            selected: timeKind == TimeKind.both,
            onTap: () => onChanged(TimeKind.both),
          ),
        ],
      ),
    );
  }
}

class _TimeKindOption extends StatelessWidget {
  const _TimeKindOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 22,
              color: selected ? const Color(0xFF2563EB) : Colors.grey.shade600,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? Colors.black87 : Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
              Icon(Icons.calendar_today, size: 18, color: Colors.grey.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      DateTimePickerSection.formatDate(date),
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.label,
    required this.time,
    required this.onTap,
  });

  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
              Icon(Icons.access_time, size: 18, color: Colors.grey.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      DateTimePickerSection.formatTime(time),
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
            ],
          ),
        ),
      ),
    );
  }
}
