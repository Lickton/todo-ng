import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:doable_todo_list_app/l10n/app_localizations.dart';

/// 重复类型（仅包含当前产品需求）：
/// - daily: 每天
/// - weekly: 每周（可多选周几）
/// - monthly: 每月（逗号输入日期 1~31）
enum RepeatUiType { daily, weekly, monthly }

/// 重复规则的 UI 配置（仅保留每天/每周/每月）。
///
/// 说明：
/// - `daily` 时，`weekdays` / `monthDays` 会被忽略
/// - `weekly` 时，仅 `weekdays` 生效
/// - `monthly` 时，仅 `monthDays` 生效
class RepeatUiConfig {
  const RepeatUiConfig({
    this.type = RepeatUiType.daily,
    this.weekdays = const <int>{},
    this.monthDays = const <int>{},
  });

  final RepeatUiType type;
  final Set<int> weekdays;
  final Set<int> monthDays;

  /// 不可变对象惯用写法：通过 copyWith 派生新状态。
  RepeatUiConfig copyWith({
    RepeatUiType? type,
    Set<int>? weekdays,
    Set<int>? monthDays,
  }) {
    return RepeatUiConfig(
      type: type ?? this.type,
      weekdays: weekdays ?? this.weekdays,
      monthDays: monthDays ?? this.monthDays,
    );
  }
}

/// 日期时间区域的统一状态模型。
///
/// 设计目标：
/// 1. 用一个对象承载 UI 所有可编辑值，避免页面层拆成多份状态。
/// 2. 通过 `normalized()` 强制业务约束，禁止非法组合透传到外层。
/// 3. 保持组件“可控”：外部传入 state，内部只通过 onChanged 回传。
class DateTimeSectionState {
  const DateTimeSectionState({
    required this.dateEnabled,
    required this.timeEnabled,
    required this.repeatEnabled,
    required this.date,
    required this.time,
    required this.repeat,
  });

  final bool dateEnabled;
  final bool timeEnabled;
  final bool repeatEnabled;
  final DateTime date;
  final TimeOfDay time;
  final RepeatUiConfig repeat;

  /// 统一的状态更新入口。更新后会立即做 `normalized()`。
  DateTimeSectionState copyWith({
    bool? dateEnabled,
    bool? timeEnabled,
    bool? repeatEnabled,
    DateTime? date,
    TimeOfDay? time,
    RepeatUiConfig? repeat,
  }) {
    return DateTimeSectionState(
      dateEnabled: dateEnabled ?? this.dateEnabled,
      timeEnabled: timeEnabled ?? this.timeEnabled,
      repeatEnabled: repeatEnabled ?? this.repeatEnabled,
      date: date ?? this.date,
      time: time ?? this.time,
      repeat: repeat ?? this.repeat,
    );
  }

  DateTimeSectionState normalized({
    BuildContext? context,
    AppLocalizations? l10n,
  }) {
    // 统一业务约束（单一出口，所有状态回传都走这里）：
    // 1) dateEnabled 与 repeatEnabled 互斥（不允许同时开启）。
    // 2) timeEnabled == true 时，dateEnabled / repeatEnabled 至少开启一个。
    // 3) 若 timeEnabled == true 且二者都为 false，则默认回退为 dateEnabled = true。
    var nextDateEnabled = dateEnabled;
    var nextRepeatEnabled = repeatEnabled;
    if (dateEnabled && repeatEnabled) {
      nextRepeatEnabled = false;
    }
    // 时间启用时，日期/重复至少开启一个；若都关闭，默认回退为日期开启。
    if (timeEnabled && !nextDateEnabled && !nextRepeatEnabled) {
      nextDateEnabled = true;
    }

    return DateTimeSectionState(
      dateEnabled: nextDateEnabled,
      timeEnabled: timeEnabled,
      repeatEnabled: nextRepeatEnabled,
      date: date,
      time: time,
      repeat: repeat,
    );
  }

  static DateTimeSectionState initial() {
    // 初始默认值：日期+时间开启，重复关闭。
    // 时间默认为 09:00，避免 00:00 对大多数场景过于激进。
    return DateTimeSectionState(
      dateEnabled: true,
      timeEnabled: true,
      repeatEnabled: false,
      date: DateTime.now(),
      time: const TimeOfDay(hour: 9, minute: 0),
      repeat: const RepeatUiConfig(type: RepeatUiType.daily),
    );
  }
}

class DateTimePickerSection extends StatelessWidget {
  const DateTimePickerSection({
    super.key,
    required this.state,
    required this.onChanged,
  });

  final DateTimeSectionState state;
  final ValueChanged<DateTimeSectionState> onChanged;

  /// 存储层使用 `dd/MM/yy`，这里保持一致，避免显示/存储格式漂移。
  static String formatDate(DateTime d) => DateFormat('dd/MM/yy').format(d);

  /// 统一 12 小时制展示（如 9:05 AM），与现有任务时间格式保持一致。
  static String formatTime(TimeOfDay t) {
    final dt = DateTime(0, 1, 1, t.hour, t.minute);
    return DateFormat('h:mm a').format(dt);
  }

  void _emit(
    BuildContext context,
    AppLocalizations l10n,
    DateTimeSectionState next,
  ) {
    // 所有状态输出统一经过 normalized，避免 UI 进入非法态。
    onChanged(next.normalized(context: context, l10n: l10n));
  }

  String repeatSummary(RepeatUiConfig repeat, AppLocalizations l10n) {
    switch (repeat.type) {
      case RepeatUiType.daily:
        return l10n.daily;
      case RepeatUiType.weekly:
        if (repeat.weekdays.isEmpty) return l10n.weekly;
        final sorted = repeat.weekdays.toList()..sort();
        final labels = sorted.map((day) => _weekdayShortLabel(day, l10n)).toList();
        return '${l10n.weekly}${labels.join('、')}';
      case RepeatUiType.monthly:
        if (repeat.monthDays.isEmpty) return l10n.monthly;
        final sorted = repeat.monthDays.toList()..sort();
        return '${l10n.monthly} ${sorted.join(',')}';
    }
  }

  String _weekdayShortLabel(int day, AppLocalizations l10n) {
    switch (day) {
      case 1:
        return l10n.mondayShort;
      case 2:
        return l10n.tuesdayShort;
      case 3:
        return l10n.wednesdayShort;
      case 4:
        return l10n.thursdayShort;
      case 5:
        return l10n.fridayShort;
      case 6:
        return l10n.saturdayShort;
      case 7:
        return l10n.sundayShort;
      default:
        return '';
    }
  }

  Future<void> _pickDate(BuildContext context, AppLocalizations l10n) async {
    FocusScope.of(context).unfocus();
    final picked = await showDatePicker(
      context: context,
      useRootNavigator: true,
      initialDate: state.date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: l10n.selectDate,
    );
    if (!context.mounted) return;
    if (picked != null) {
      _emit(context, l10n, state.copyWith(date: picked));
    }
  }

  Future<void> _pickTime(BuildContext context, AppLocalizations l10n) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: state.time,
      helpText: l10n.selectTime,
    );
    if (!context.mounted) return;
    if (picked != null) {
      _emit(context, l10n, state.copyWith(time: picked));
    }
  }

  Future<void> _pickRepeat(BuildContext context, AppLocalizations l10n) async {
    final result = await showModalBottomSheet<RepeatUiConfig>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => RepeatBottomSheet(initial: state.repeat),
    );
    if (!context.mounted) return;
    if (result != null) {
      _emit(context, l10n, state.copyWith(repeat: result));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const disabledText = '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ToggleRow(
          icon: Icons.calendar_today,
          enabled: state.dateEnabled,
          valueText:
              state.dateEnabled ? formatDate(state.date) : disabledText,
          onToggle: () {
            final nextEnabled = !state.dateEnabled;
            // 规则：日期与重复互斥；若时间已开启且关闭日期会导致二者都关，
            // 则自动开启重复，保证“时间开启时二选一至少开启”。
            final shouldEnableRepeat = !nextEnabled &&
                state.timeEnabled &&
                !state.repeatEnabled;
            _emit(
              context,
              l10n,
              state.copyWith(
                dateEnabled: nextEnabled,
                repeatEnabled: nextEnabled
                    ? false
                    : (shouldEnableRepeat ? true : state.repeatEnabled),
              ),
            );
          },
          onTapValue: state.dateEnabled ? () => _pickDate(context, l10n) : null,
          trailingIcon: Icons.chevron_right,
          borderRadius: 16,
        ),
        const SizedBox(height: 12),
        _ToggleRow(
          icon: Icons.access_time,
          enabled: state.timeEnabled,
          valueText:
              state.timeEnabled ? formatTime(state.time) : disabledText,
          onToggle: () {
            final nextTimeEnabled = !state.timeEnabled;
            // 规则：当三者全关时，点击时间开启会自动开启日期，
            // 避免出现“仅时间开启、日期/重复都关闭”的非法组合。
            final shouldEnableDate = nextTimeEnabled &&
                !state.dateEnabled &&
                !state.timeEnabled &&
                !state.repeatEnabled;
            _emit(
              context,
              l10n,
              state.copyWith(
                timeEnabled: nextTimeEnabled,
                dateEnabled:
                    shouldEnableDate ? true : state.dateEnabled,
              ),
            );
          },
          onTapValue: state.timeEnabled ? () => _pickTime(context, l10n) : null,
          trailingIcon: Icons.chevron_right,
          borderRadius: 16,
        ),
        const SizedBox(height: 12),
        _ToggleRow(
          icon: Icons.repeat,
          enabled: state.repeatEnabled,
          valueText:
              state.repeatEnabled ? repeatSummary(state.repeat, l10n) : disabledText,
          onToggle: () {
            final nextEnabled = !state.repeatEnabled;
            // 规则：重复与日期互斥；若时间已开启且关闭重复会导致二者都关，
            // 则自动开启日期，保证“时间开启时二选一至少开启”。
            final shouldEnableDate =
                !nextEnabled && state.timeEnabled && !state.dateEnabled;
            _emit(
              context,
              l10n,
              state.copyWith(
                repeatEnabled: nextEnabled,
                dateEnabled: nextEnabled
                    ? false
                    : (shouldEnableDate ? true : state.dateEnabled),
              ),
            );
          },
          onTapValue:
              state.repeatEnabled ? () => _pickRepeat(context, l10n) : null,
          trailingIcon: Icons.chevron_right,
          borderRadius: 16,
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.enabled,
    required this.valueText,
    required this.onToggle,
    required this.onTapValue,
    required this.trailingIcon,
    this.borderRadius = 16,
  });

  final IconData icon;
  final bool enabled;
  final String valueText;
  final VoidCallback onToggle;
  final VoidCallback? onTapValue;
  final IconData trailingIcon;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final dividerColor = Colors.grey.shade200;
    final borderColor = Colors.grey.shade300;
    final iconColor = enabled
        ? const Color(0xFF4E8EF6)
        // ignore: deprecated_member_use
        : const Color(0xFF4E8EF6).withOpacity(0.35);
    final valueTapEnabled = enabled && onTapValue != null;

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: BorderSide(color: borderColor),
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(borderRadius),
              bottomLeft: Radius.circular(borderRadius),
            ),
            onTap: onToggle,
            child: SizedBox(
              width: 56,
              height: 56,
              child: Center(
                child: Icon(icon, size: 22, color: iconColor),
              ),
            ),
          ),
          Container(width: 1, height: 56, color: dividerColor),
          Expanded(
            child: Opacity(
              opacity: enabled ? 1 : 0.5,
              child: InkWell(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(borderRadius),
                  bottomRight: Radius.circular(borderRadius),
                ),
                onTap: valueTapEnabled ? onTapValue : null,
                child: SizedBox(
                  height: 56,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            valueText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Icon(
                          trailingIcon,
                          size: 20,
                          color: valueTapEnabled
                              ? Colors.grey.shade600
                              : Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RepeatBottomSheet extends StatefulWidget {
  const RepeatBottomSheet({
    super.key,
    required this.initial,
  });

  final RepeatUiConfig initial;

  @override
  State<RepeatBottomSheet> createState() => _RepeatBottomSheetState();
}

class _RepeatBottomSheetState extends State<RepeatBottomSheet> {
  late RepeatUiConfig _draftRepeat;

  @override
  void initState() {
    super.initState();
    _draftRepeat = widget.initial;
  }

  void _showSelectAtLeastOneDayDialog(AppLocalizations l10n) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          content: Text(l10n.selectAtLeastOneDay),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.done),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final weekly = _draftRepeat.type == RepeatUiType.weekly;
    final monthly = _draftRepeat.type == RepeatUiType.monthly;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.repeat,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SegmentedButton<RepeatUiType>(
              segments: [
                ButtonSegment<RepeatUiType>(
                  value: RepeatUiType.daily,
                  label: Text(l10n.daily),
                ),
                ButtonSegment<RepeatUiType>(
                  value: RepeatUiType.weekly,
                  label: Text(l10n.weekly),
                ),
                ButtonSegment<RepeatUiType>(
                  value: RepeatUiType.monthly,
                  label: Text(l10n.monthly),
                ),
              ],
              selected: {_draftRepeat.type},
              showSelectedIcon: false,
              onSelectionChanged: (next) {
                if (next.isEmpty) return;
                setState(() {
                  _draftRepeat = _draftRepeat.copyWith(type: next.first);
                });
              },
            ),
            const SizedBox(height: 12),
            if (_draftRepeat.type == RepeatUiType.daily)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  l10n.daily,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            if (weekly)
              _WeeklyDaysPicker(
                selected: _draftRepeat.weekdays,
                onChanged: (days) {
                  setState(() {
                    _draftRepeat = _draftRepeat.copyWith(weekdays: days);
                  });
                },
              ),
            if (monthly)
              _MonthlyDaysInput(
                selected: _draftRepeat.monthDays,
                onChanged: (days) {
                  setState(() {
                    _draftRepeat = _draftRepeat.copyWith(monthDays: days);
                  });
                },
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                      const RepeatUiConfig(type: RepeatUiType.daily),
                    );
                  },
                  child: Text(l10n.clear),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    final needAtLeastOneDay =
                        (_draftRepeat.type == RepeatUiType.weekly &&
                                _draftRepeat.weekdays.isEmpty) ||
                            (_draftRepeat.type == RepeatUiType.monthly &&
                                _draftRepeat.monthDays.isEmpty);
                    if (needAtLeastOneDay) {
                      _showSelectAtLeastOneDayDialog(l10n);
                      return;
                    }
                    Navigator.of(context).pop(_draftRepeat);
                  },
                  child: Text(l10n.done),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyDaysPicker extends StatelessWidget {
  const _WeeklyDaysPicker({
    required this.selected,
    required this.onChanged,
  });

  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labels = [
      (1, l10n.mondayShort),
      (2, l10n.tuesdayShort),
      (3, l10n.wednesdayShort),
      (4, l10n.thursdayShort),
      (5, l10n.fridayShort),
      (6, l10n.saturdayShort),
      (7, l10n.sundayShort),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        // 动态计算 7 列宽度，保证周选择始终单行展示。
        final itemWidth = (constraints.maxWidth - gap * 6) / 7;
        return Row(
          children: labels.map((e) {
            final day = e.$1;
            final isSelected = selected.contains(day);
            return Padding(
              padding: EdgeInsets.only(right: day == 7 ? 0 : gap),
              child: SizedBox(
                width: itemWidth,
                child: _WeekdayCell(
                  label: e.$2,
                  selected: isSelected,
                  onTap: () {
                    // 周选择为多选：点击同一项可切换选中/取消。
                    final next = Set<int>.from(selected);
                    if (isSelected) {
                      next.remove(day);
                    } else {
                      next.add(day);
                    }
                    onChanged(next);
                  },
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _WeekdayCell extends StatelessWidget {
  const _WeekdayCell({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 这里用自定义 cell，而不是 FilterChip，目的是可控宽度并稳定单行布局。
    return Material(
      color: selected ? Colors.black87 : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthlyDaysInput extends StatefulWidget {
  const _MonthlyDaysInput({
    required this.selected,
    required this.onChanged,
  });

  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  State<_MonthlyDaysInput> createState() => _MonthlyDaysInputState();
}

class _MonthlyDaysInputState extends State<_MonthlyDaysInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // 初始将选中集合序列化到输入框，便于编辑。
    _controller = TextEditingController(text: _toText(widget.selected));
  }

  @override
  void didUpdateWidget(covariant _MonthlyDaysInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外层状态变化时，同步刷新输入框文本，避免显示与状态不一致。
    if (!_sameSet(oldWidget.selected, widget.selected)) {
      _controller.text = _toText(widget.selected);
    }
  }

  @override
  void dispose() {
    // Stateful input 持有 controller，必须释放。
    _controller.dispose();
    super.dispose();
  }

  /// 比较两个集合是否等价（忽略顺序）。
  bool _sameSet(Set<int> a, Set<int> b) {
    if (a.length != b.length) return false;
    for (final x in a) {
      if (!b.contains(x)) return false;
    }
    return true;
  }

  String _toText(Set<int> days) {
    // 序列化规则：升序 + 逗号拼接（例如 1,15,31）。
    final sorted = days.toList()..sort();
    return sorted.join(',');
  }

  Set<int> _parse(String raw) {
    // 月重复输入格式：逗号分隔，仅接受 1~31 的整数。
    // 非法值会被自动忽略（例如 0, 32, 非数字）。
    final parts = raw.split(',');
    final result = <int>{};
    for (final p in parts) {
      final v = int.tryParse(p.trim());
      if (v != null && v >= 1 && v <= 31) {
        result.add(v);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        hintText: '1,15,31',
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
          // borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
          borderSide: const BorderSide(color: Color(0xFF89B4F9), width: 2),
        ),
      ),
      // 每次输入即时回传解析结果，外层状态保持单一事实来源。
      onChanged: (v) => widget.onChanged(_parse(v)),
    );
  }
}
