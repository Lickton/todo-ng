import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:doable_todo_list_app/l10n/app_localizations.dart';

/// 重复选择器：每天/每周/每月/每年/不重复
/// - 每周：周一到周五
/// - 每月：1-31 网格，每行 7 天
/// - 每年：月份滑动 + 日期选择，切换月份保留已选
class RepeatPickerField extends StatefulWidget {
  const RepeatPickerField({
    super.key,
    required this.repeatRule,
    required this.repeatWeekdays,
    required this.repeatMonthDays,
    required this.repeatYearMonthDays,
    this.selectedTime,
    required this.onTimeChanged,
    required this.onChanged,
    this.showTimePicker = true,
  });

  final String? repeatRule;
  final Set<int> repeatWeekdays;
  final Set<int> repeatMonthDays;
  final Map<int, Set<int>> repeatYearMonthDays;
  final TimeOfDay? selectedTime;
  final void Function(TimeOfDay?) onTimeChanged;
  final void Function(
    String? rule, {
    Set<int>? weekdays,
    Set<int>? monthDays,
    Map<int, Set<int>>? yearMonthDays,
  }) onChanged;
  /// 是否显示时间选择行（当日期时间在别处选择时为 false）
  final bool showTimePicker;

  @override
  State<RepeatPickerField> createState() => _RepeatPickerFieldState();
}

class _RepeatPickerFieldState extends State<RepeatPickerField> {
  int _yearlyViewMonth = DateTime.now().month;

  /// 从存储的规则中提取基础类型（如 "Weekly:[1,2,3]" -> "Weekly"）
  String? get _baseRule {
    final r = widget.repeatRule;
    if (r == null || r.isEmpty || r == 'No repeat') return r;
    final colon = r.indexOf(':');
    if (colon > 0) return r.substring(0, colon);
    return r;
  }

  String _displayText(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final base = _baseRule;
    if (base == null || base == 'No repeat') return l10n.noRepeat;
    if (base == 'Daily') return l10n.daily;
    if (base == 'Weekly') return l10n.weekly;
    if (base == 'Monthly') return l10n.monthly;
    if (base == 'Yearly') return l10n.yearly;
    return l10n.noRepeat;
  }

  Future<void> _showPicker(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final options = [
      l10n.daily,
      l10n.weekly,
      l10n.monthly,
      l10n.yearly,
      l10n.noRepeat,
    ];
    final ruleMap = {
      l10n.daily: 'Daily',
      l10n.weekly: 'Weekly',
      l10n.monthly: 'Monthly',
      l10n.yearly: 'Yearly',
      l10n.noRepeat: 'No repeat',
    };

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    l10n.repeat,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...options.map((opt) {
                  final rule = ruleMap[opt]!;
                  final base = _baseRule;
                  final isSelected = (base == rule) ||
                      (base == null && rule == 'No repeat');
                  return ListTile(
                    title: Text(opt),
                    selected: isSelected,
                    onTap: () => Navigator.pop(ctx, rule),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      final weekdays = selected == 'Weekly'
          ? Set<int>.from(widget.repeatWeekdays)
          : <int>{};
      final monthDays =
          selected == 'Monthly' ? Set<int>.from(widget.repeatMonthDays) : <int>{};
      final yearMonthDays = selected == 'Yearly'
          ? Map<int, Set<int>>.from(
              widget.repeatYearMonthDays.map((k, v) => MapEntry(k, Set<int>.from(v))))
          : <int, Set<int>>{};
      widget.onChanged(selected == 'No repeat' ? null : selected,
          weekdays: weekdays,
          monthDays: monthDays,
          yearMonthDays: yearMonthDays);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final base = _baseRule;
    final showWeekdays = base == 'Weekly';
    final showMonthDays = base == 'Monthly';
    final showYearly = base == 'Yearly';

    final shortLabels = [
      (1, l10n.mondayShort),
      (2, l10n.tuesdayShort),
      (3, l10n.wednesdayShort),
      (4, l10n.thursdayShort),
      (5, l10n.fridayShort),
      (6, l10n.saturdayShort),
      (7, l10n.sundayShort),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showPicker(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.repeat, size: 18, color: Colors.grey.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _displayText(context),
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                ],
              ),
            ),
          ),
        ),
        if (showWeekdays) ...[
          const SizedBox(height: 12),
          Row(
            children: shortLabels.map((e) {
              final wd = e.$1;
              final label = e.$2;
              final selected = widget.repeatWeekdays.contains(wd);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _DayChip(
                    label: label,
                    selected: selected,
                    onTap: () {
                      final next = Set<int>.from(widget.repeatWeekdays);
                      if (selected) {
                        next.remove(wd);
                      } else {
                        next.add(wd);
                      }
                      widget.onChanged('Weekly', weekdays: next);
                    },
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        if (showMonthDays) ...[
          const SizedBox(height: 12),
          _MonthDaysGrid(
            selectedDays: widget.repeatMonthDays,
            onChanged: (next) => widget.onChanged('Monthly', monthDays: next),
          ),
        ],
        if (showYearly) ...[
          const SizedBox(height: 12),
          _YearlyPicker(
            yearMonthDays: widget.repeatYearMonthDays,
            viewMonth: _yearlyViewMonth,
            onViewMonthChanged: (m) =>
                setState(() => _yearlyViewMonth = m),
            onChanged: (next) =>
                widget.onChanged('Yearly', yearMonthDays: next),
          ),
        ],
        if (widget.showTimePicker) ...[
          const SizedBox(height: 12),
          _TimePickerRow(
            selectedTime: widget.selectedTime,
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: widget.selectedTime ?? TimeOfDay.now(),
                helpText: AppLocalizations.of(context)!.selectTime,
              );
              if (picked != null) widget.onTimeChanged(picked);
            },
            onClear: widget.selectedTime != null
                ? () => widget.onTimeChanged(null)
                : null,
          ),
        ],
      ],
    );
  }
}

class _TimePickerRow extends StatelessWidget {
  const _TimePickerRow({
    required this.selectedTime,
    required this.onTap,
    this.onClear,
  });

  final TimeOfDay? selectedTime;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final hasValue = selectedTime != null;
    final valueText = hasValue
        ? DateFormat('h:mm a')
            .format(DateTime(0, 1, 1, selectedTime!.hour, selectedTime!.minute))
        : null;

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
                child: Text(
                  hasValue ? valueText! : AppLocalizations.of(context)!.setTime,
                  style: TextStyle(
                    color: hasValue ? Colors.black87 : Colors.black54,
                    fontWeight: hasValue ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
              if (hasValue && onClear != null)
                IconButton(
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

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.black : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthDaysGrid extends StatelessWidget {
  const _MonthDaysGrid({
    required this.selectedDays,
    required this.onChanged,
  });

  final Set<int> selectedDays;
  final void Function(Set<int>) onChanged;

  @override
  Widget build(BuildContext context) {
    const days = 31;
    const cols = 7;
    final rows = (days / cols).ceil();

    return Column(
      children: List.generate(rows, (row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: List.generate(cols, (col) {
              final day = row * cols + col + 1;
              if (day > days) return const Expanded(child: SizedBox());
              final selected = selectedDays.contains(day);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _DayChip(
                    label: '$day',
                    selected: selected,
                    onTap: () {
                      final next = Set<int>.from(selectedDays);
                      if (selected) {
                        next.remove(day);
                      } else {
                        next.add(day);
                      }
                      onChanged(next);
                    },
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

class _YearlyPicker extends StatelessWidget {
  const _YearlyPicker({
    required this.yearMonthDays,
    required this.viewMonth,
    required this.onViewMonthChanged,
    required this.onChanged,
  });

  final Map<int, Set<int>> yearMonthDays;
  final int viewMonth;
  final void Function(int) onViewMonthChanged;
  final void Function(Map<int, Set<int>>) onChanged;

  static const List<int> _daysInMonth = [
    31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
  ];

  int _daysForMonth(int month) => _daysInMonth[month - 1];

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final monthNames = List.generate(
        12,
        (i) => DateFormat.MMM(locale).format(DateTime(2000, i + 1, 1)));
    final daysInView = _daysForMonth(viewMonth);
    const cols = 7;
    final rows = (daysInView / cols).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 12,
            itemBuilder: (context, i) {
              final m = i + 1;
              final isSelected = viewMonth == m;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: isSelected ? Colors.black : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onViewMonthChanged(m),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Text(
                          monthNames[i],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: List.generate(rows, (row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: List.generate(cols, (col) {
                  final day = row * cols + col + 1;
                  if (day > daysInView) return const Expanded(child: SizedBox());
                  final selected =
                      (yearMonthDays[viewMonth] ?? {}).contains(day);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _DayChip(
                        label: '$day',
                        selected: selected,
                        onTap: () {
                          final next = <int, Set<int>>{};
                          for (final e in yearMonthDays.entries) {
                            next[e.key] = Set<int>.from(e.value);
                          }
                          next.putIfAbsent(viewMonth, () => <int>{});
                          if (selected) {
                            next[viewMonth]!.remove(day);
                            if (next[viewMonth]!.isEmpty) next.remove(viewMonth);
                          } else {
                            next[viewMonth]!.add(day);
                          }
                          onChanged(next);
                        },
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ),
      ],
    );
  }
}
