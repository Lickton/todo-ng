import 'package:flutter/foundation.dart';
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
    // 统一出口：日期与重复互斥，但允许二者都关闭。
    var nextRepeatEnabled = repeatEnabled;
    if (dateEnabled && repeatEnabled) {
      nextRepeatEnabled = false;
    }

    return DateTimeSectionState(
      dateEnabled: dateEnabled,
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

  /// 日期标题文案。
  String _dateLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return l10n.date;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1) 日期开关 + 日期选择器
        _SwitchTile(
          icon: Icons.calendar_today,
          label: _dateLabel(context),
          value: state.dateEnabled,
          onChanged: (v) {
            _emit(context, l10n, state.copyWith(dateEnabled: v, repeatEnabled: v ? false : state.repeatEnabled));
          },
        ),
        if (state.dateEnabled) ...[
          const SizedBox(height: 12),
          _DateTile(
            label: _dateLabel(context),
            date: state.date,
            onTap: () async {
              // 点击链路调试日志：用于定位“点了没反应”。
              if (kDebugMode) {
                debugPrint(
                    '[DateTimePickerSection] dateTile onTap entered, date=${state.date.toIso8601String()}');
              }
              FocusScope.of(context).unfocus();
              // 先收起键盘，避免某些机型/弹层场景手势冲突。
              if (kDebugMode) {
                debugPrint(
                    '[DateTimePickerSection] showDatePicker opening (useRootNavigator=true)');
              }
              try {
                // 使用 root navigator，避免在局部 Navigator（如底部弹层）里弹不出来。
                final picked = await showDatePicker(
                  context: context,
                  useRootNavigator: true,
                  initialDate: state.date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  helpText: l10n.selectDate,
                );
                if (kDebugMode) {
                  debugPrint(
                      '[DateTimePickerSection] showDatePicker returned: ${picked?.toIso8601String() ?? 'null'}');
                }
                if (picked != null) {
                  // 用户确认后才更新状态；取消返回 null，不做状态变更。
                  _emit(context, l10n, state.copyWith(date: picked));
                }
              } catch (e, st) {
                // 仅 debug 打印异常，生产环境保持静默。
                if (kDebugMode) {
                  debugPrint(
                      '[DateTimePickerSection] showDatePicker threw: $e');
                  debugPrint('$st');
                }
              }
            },
          ),
        ],
        const SizedBox(height: 12),
        // 2) 时间开关 + 时间选择器
        _SwitchTile(
          icon: Icons.access_time,
          label: l10n.time,
          value: state.timeEnabled,
          onChanged: (v) {
            _emit(context, l10n, state.copyWith(timeEnabled: v));
          },
        ),
        if (state.timeEnabled) ...[
          const SizedBox(height: 12),
          _TimeTile(
            label: l10n.time,
            time: state.time,
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: state.time,
                helpText: l10n.selectTime,
              );
              if (picked != null) {
                _emit(context, l10n, state.copyWith(time: picked));
              }
            },
          ),
        ],
        const SizedBox(height: 12),
        // 3) 重复开关 + 重复细项
        _SwitchTile(
          icon: Icons.repeat,
          label: l10n.repeat,
          value: state.repeatEnabled,
          onChanged: (v) {
            _emit(context, l10n, state.copyWith(repeatEnabled: v, dateEnabled: v ? false : state.dateEnabled));
          },
        ),
        if (state.repeatEnabled) ...[
          const SizedBox(height: 12),
          _RepeatPicker(
            repeat: state.repeat,
            onChanged: (next) =>
                _emit(context, l10n, state.copyWith(repeat: next)),
          ),
        ],
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    // 开关行仅负责渲染，不接管业务约束。
    // 约束由外层 DateTimeSectionState.normalized() 统一处理。
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _RepeatPicker extends StatelessWidget {
  const _RepeatPicker({
    required this.repeat,
    required this.onChanged,
  });

  final RepeatUiConfig repeat;
  final ValueChanged<RepeatUiConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final weekly = repeat.type == RepeatUiType.weekly;
    final monthly = repeat.type == RepeatUiType.monthly;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 重复类型选择：每天 / 每周 / 每月。
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<RepeatUiType>(
                value: repeat.type,
                isExpanded: true,
                items: [
                  DropdownMenuItem(
                    value: RepeatUiType.daily,
                    child: Text(l10n.daily),
                  ),
                  DropdownMenuItem(
                    value: RepeatUiType.weekly,
                    child: Text(l10n.weekly),
                  ),
                  DropdownMenuItem(
                    value: RepeatUiType.monthly,
                    child: Text(l10n.monthly),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  // 切换类型时不强行清空其它字段，便于用户来回切换时保留输入。
                  onChanged(repeat.copyWith(type: v));
                },
              ),
            ),
          ),
        ),
        if (weekly) ...[
          const SizedBox(height: 12),
          _WeeklyDaysPicker(
            selected: repeat.weekdays,
            onChanged: (days) => onChanged(repeat.copyWith(weekdays: days)),
          ),
        ],
        if (monthly) ...[
          const SizedBox(height: 12),
          _MonthlyDaysInput(
            selected: repeat.monthDays,
            onChanged: (days) => onChanged(repeat.copyWith(monthDays: days)),
          ),
        ],
      ],
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
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
        ),
      ),
      // 每次输入即时回传解析结果，外层状态保持单一事实来源。
      onChanged: (v) => widget.onChanged(_parse(v)),
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
        onTap: () {
          // 点击命中日志：用于区分“未命中 InkWell”与“命中后弹窗失败”。
          if (kDebugMode) {
            debugPrint('[DateTimePickerSection] _DateTile InkWell tapped');
          }
          onTap();
        },
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
    // 时间选择展示组件，逻辑由外层回调处理。
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
