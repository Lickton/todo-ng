import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart'; // for DateFormat [web:146][web:156]

import 'package:doable_todo_list_app/l10n/app_localizations.dart';
import 'package:doable_todo_list_app/models/action_item.dart';
import 'package:doable_todo_list_app/models/task_entity.dart';
import 'package:doable_todo_list_app/repositories/task_repository.dart';
import 'package:doable_todo_list_app/utils/priority_utils.dart';
import 'package:doable_todo_list_app/utils/task_schedule_codec.dart';
import 'package:doable_todo_list_app/widgets/action_button.dart';
import 'package:doable_todo_list_app/widgets/task_detail_sheet.dart';

/// UI-facing model used on this page (mapped from DB rows).
class Task {
  Task({
    required this.id,
    required this.title,
    this.description,
    this.time,
    this.date,
    this.timeKind = TimeKind.startOnly,
    this.endTime,
    this.endDate,
    this.hasNotification = false,
    this.reminderTime,
    this.useSystemAlarm = false,
    this.repeatRule,
    this.completed = false,
    this.priority = TaskPriority.white,
    this.actions,
  });

  final int id;
  String title;
  String? description;
  String? time;
  String? date;
  TimeKind timeKind;
  String? endTime;
  String? endDate;
  bool hasNotification;
  String? reminderTime;
  bool useSystemAlarm;
  String? repeatRule;
  bool completed;
  TaskPriority priority;
  List<ActionItem>? actions;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.refreshTrigger = 0});

  final int refreshTrigger;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ---- Data from SQLite rendered by the UI ----
  final List<Task> _tasks = [];

  // ---- Filter state ----
  DateTime? _fltDate; // match by formatted dd/MM/yy vs task.date
  TimeOfDay? _fltTime; // match by formatted h:mm a vs task.time
  /// null=仅未完成(默认，勾选后消失), true=仅已完成, false=全部
  bool? _fltCompleted;
  String? _fltRepeat; // "Daily"|"Weekly"|"Monthly"|null=any
  bool? _fltReminder; // true=hasNotification, false=no, null=any
  TaskPriority? _fltPriority; // null=any

  String _fmtDate(DateTime d) => DateFormat('dd/MM/yy').format(d); // [web:146]
  String _fmtTime(TimeOfDay t) => DateFormat('h:mm a')
      .format(DateTime(0, 1, 1, t.hour, t.minute)); // [web:146]

  // Filtered + ordered (incomplete first, completed last)
  List<Task> get _filteredTasks {
    Iterable<Task> it = _tasks;

    if (_fltDate != null) {
      final d = _fmtDate(_fltDate!);
      it = it.where((t) => (t.date ?? '') == d);
    }
    if (_fltTime != null) {
      final tm = _fmtTime(_fltTime!);
      it = it.where((t) => (t.time ?? '') == tm);
    }
    if (_fltCompleted == null) {
      // 默认只显示未完成，勾选完成后任务直接从界面去除
      it = it.where((t) => !t.completed);
    } else if (_fltCompleted == true) {
      it = it.where((t) => t.completed);
    }
    // _fltCompleted == false 表示「任意」，不筛选
    if (_fltRepeat != null) {
      it = it.where((t) {
        final ui = RepeatSelection.fromStorage(t.repeatRule).toUiRule();
        if (ui == 'No repeat') return false;
        return ui == _fltRepeat;
      });
    }
    if (_fltReminder != null) {
      it = it.where((t) => t.hasNotification == _fltReminder);
    }
    if (_fltPriority != null) {
      it = it.where((t) => t.priority == _fltPriority);
    }

    final list = it.toList();
    list.sort((a, b) {
      final pa = PriorityUtils.sortOrder(a.priority);
      final pb = PriorityUtils.sortOrder(b.priority);
      if (pa != pb) return pa.compareTo(pb);
      if (a.completed != b.completed) return a.completed ? 1 : -1;
      return 0;
    });
    return list;
  }

  void _clearFilters() {
    setState(() {
      _fltDate = null;
      _fltTime = null;
      _fltCompleted = null;
      _fltRepeat = null;
      _fltReminder = null;
      _fltPriority = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _init(); // initial DB load
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshTrigger != oldWidget.refreshTrigger) {
      _load();
    }
  }

  Future<void> _init() async {
    // await TaskDao.seedDemo(); // optional first-run seeding
    await _load();
  }

  Future<void> _load() async {
    final rows = await TaskRepository().fetchAll();
    final mapped = rows
        .map((e) => Task(
              id: e.id!,
              title: e.title,
              description: e.description,
              time: e.time,
              date: e.date,
              timeKind: e.timeKind,
              endTime: e.endTime,
              endDate: e.endDate,
              hasNotification: e.hasNotification,
              reminderTime: e.reminderTime,
              useSystemAlarm: e.useSystemAlarm,
              repeatRule: e.repeatRule,
              completed: e.completed,
              priority: e.priority,
              actions: e.actions,
            ))
        .toList();

    if (!mounted) return;
    setState(() {
      _tasks
        ..clear()
        ..addAll(mapped);
    });
  }

  Future<void> _toggle(Task t) async {
    final markingComplete = !t.completed;
    await TaskRepository().toggle(t.id, markingComplete);
    await _load();
    if (mounted && markingComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(AppLocalizations.of(context)!.taskCompletedMessage(t.title)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _delete(Task t) async {
    await TaskRepository().delete(t.id);
    await _load();
  }

  double verticalPadding(BuildContext context) =>
      MediaQuery.of(context).size.height * 0.07;
  double horizontalPadding(BuildContext context) =>
      MediaQuery.of(context).size.width * 0.05;

  // ---- Filter bottom sheet ----
  Future<void> _openFilterSheet() async {
    await showModalBottomSheet<void>(
      // [web:146][web:148]
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          // local state inside sheet [web:145][web:154][web:158]
          builder: (context, setSheetState) {
            Future<void> pickDate() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _fltDate ?? now,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 5),
                helpText: AppLocalizations.of(context)!.selectDate,
              );
              if (picked != null) setSheetState(() => _fltDate = picked);
            }

            Future<void> pickTime() async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _fltTime ?? TimeOfDay.now(),
                helpText: AppLocalizations.of(context)!.selectTime,
              );
              if (picked != null) setSheetState(() => _fltTime = picked);
            }

            Widget priorityChip(TaskPriority p, TaskPriority? current,
                void Function(void Function()) setSheetState) {
              final selected = current == p;
              final color = PriorityUtils.colorOf(p);
              final label = p == TaskPriority.red
                  ? AppLocalizations.of(context)!.priorityRed
                  : p == TaskPriority.yellow
                      ? AppLocalizations.of(context)!.priorityYellow
                      : p == TaskPriority.blue
                          ? AppLocalizations.of(context)!.priorityBlue
                          : AppLocalizations.of(context)!.priorityWhite;
              return Material(
                color: selected ? color : Colors.white,
                shape: StadiumBorder(
                    side: BorderSide(color: color, width: selected ? 0 : 2)),
                child: InkWell(
                  onTap: () => setSheetState(() => _fltPriority = p),
                  customBorder: const StadiumBorder(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: selected ? Colors.white : color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(label,
                            style: TextStyle(
                                color: selected ? Colors.white : Colors.black,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              );
            }

            Widget chip(String label, bool selected, VoidCallback onTap) {
              final bg = selected ? Colors.black : Colors.white;
              final fg = selected ? Colors.white : Colors.black;
              return Material(
                color: bg,
                shape: StadiumBorder(
                    side: BorderSide(color: Colors.grey.shade300)),
                child: InkWell(
                  onTap: onTap,
                  customBorder: const StadiumBorder(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Text(label,
                        style:
                            TextStyle(color: fg, fontWeight: FontWeight.w700)),
                  ),
                ),
              );
            }

            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(AppLocalizations.of(context)!.dateAndTime,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.black)),
                      const SizedBox(height: 12),
                      _PickerRow(
                        icon: Icons.calendar_today,
                        label: _fltDate != null
                            ? _fmtDate(_fltDate!)
                            : AppLocalizations.of(context)!.setDate,
                        hasValue: _fltDate != null,
                        onTap: pickDate,
                        onClear: _fltDate != null
                            ? () => setSheetState(() => _fltDate = null)
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _PickerRow(
                        icon: Icons.access_time,
                        label: _fltTime != null
                            ? _fmtTime(_fltTime!)
                            : AppLocalizations.of(context)!.setTime,
                        hasValue: _fltTime != null,
                        onTap: pickTime,
                        onClear: _fltTime != null
                            ? () => setSheetState(() => _fltTime = null)
                            : null,
                      ),
                      const SizedBox(height: 20),
                      Text(AppLocalizations.of(context)!.completionStatus,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.black)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          chip(
                              AppLocalizations.of(context)!.completed,
                              _fltCompleted == true,
                              () => setSheetState(() => _fltCompleted = true)),
                          chip(
                              AppLocalizations.of(context)!.incomplete,
                              _fltCompleted == null,
                              () => setSheetState(() => _fltCompleted = null)),
                          chip(
                              AppLocalizations.of(context)!.any,
                              _fltCompleted == false,
                              () => setSheetState(() => _fltCompleted = false)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(AppLocalizations.of(context)!.repeat,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.black)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          chip(
                              AppLocalizations.of(context)!.daily,
                              _fltRepeat == 'Daily',
                              () => setSheetState(() => _fltRepeat = 'Daily')),
                          chip(
                              AppLocalizations.of(context)!.weekly,
                              _fltRepeat == 'Weekly',
                              () => setSheetState(() => _fltRepeat = 'Weekly')),
                          chip(
                              AppLocalizations.of(context)!.monthly,
                              _fltRepeat == 'Monthly',
                              () =>
                                  setSheetState(() => _fltRepeat = 'Monthly')),
                          chip(
                              AppLocalizations.of(context)!.yearly,
                              _fltRepeat == 'Yearly',
                              () => setSheetState(() => _fltRepeat = 'Yearly')),
                          chip(
                              AppLocalizations.of(context)!.noRepeat,
                              _fltRepeat == null,
                              () => setSheetState(() => _fltRepeat = null)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(AppLocalizations.of(context)!.reminders,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.black)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          chip(
                              AppLocalizations.of(context)!.on,
                              _fltReminder == true,
                              () => setSheetState(() => _fltReminder = true)),
                          chip(
                              AppLocalizations.of(context)!.off,
                              _fltReminder == false,
                              () => setSheetState(() => _fltReminder = false)),
                          chip(
                              AppLocalizations.of(context)!.any,
                              _fltReminder == null,
                              () => setSheetState(() => _fltReminder = null)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(AppLocalizations.of(context)!.priority,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.black)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          priorityChip(
                              TaskPriority.red, _fltPriority, setSheetState),
                          priorityChip(
                              TaskPriority.yellow, _fltPriority, setSheetState),
                          priorityChip(
                              TaskPriority.blue, _fltPriority, setSheetState),
                          priorityChip(
                              TaskPriority.white, _fltPriority, setSheetState),
                          chip(
                              AppLocalizations.of(context)!.any,
                              _fltPriority == null,
                              () => setSheetState(() => _fltPriority = null)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context); // close sheet
                            setState(() {}); // apply filters to list
                          },
                          child:
                              Text(AppLocalizations.of(context)!.applyFilter),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            setSheetState(() {
                              _fltDate = null;
                              _fltTime = null;
                              _fltCompleted = null;
                              _fltRepeat = null;
                              _fltReminder = null;
                              _fltPriority = null;
                            });
                          },
                          child: Text(
                              AppLocalizations.of(context)!.clearSelections),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SlidableAutoCloseBehavior(
        closeWhenOpened: true,
        closeWhenTapped: true,
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding(context),
                  verticalPadding(context),
                  horizontalPadding(context),
                  12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Today + Filter
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.today,
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w800,
                            fontSize: 24,
                            height: 1.3,
                          ),
                        ),
                        const Spacer(),
                        ConstrainedBox(
                          constraints:
                              const BoxConstraints(minWidth: 96, minHeight: 48),
                          child: _FilterChipButton(
                            label: AppLocalizations.of(context)!.filter,
                            onTap: _openFilterSheet, // open bottom sheet
                            height: 36,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Task list (uses filtered tasks)
            SliverList.separated(
              itemBuilder: (context, index) {
                final task = _filteredTasks[index];
                final tile = InkWell(
                  onTap: () async {
                    final result = await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      barrierColor: Colors.black54,
                      builder: (context) => TaskDetailSheet(task: task),
                    );
                    if (result == true) await _load();
                  },
                  child: TaskTile(task: task, onToggle: () => _toggle(task)),
                );
                return Slidable(
                  key: ValueKey(task.id),
                  groupTag: 'home_tasks',
                  endActionPane: ActionPane(
                    motion: const ScrollMotion(),
                    extentRatio: 0.25,
                    children: [
                      CustomSlidableAction(
                        onPressed: (_) => _delete(task),
                        backgroundColor: Colors.red.shade400,
                        foregroundColor: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: const Icon(Icons.delete_outline, size: 24),
                      ),
                    ],
                  ),
                  child: tile,
                );
              },
              separatorBuilder: (_, __) => const Padding(
                padding: EdgeInsets.only(left: 72, right: 16),
                child: Column(
                  children: [
                    SizedBox(height: 8),
                    Divider(height: 1),
                    SizedBox(height: 8),
                  ],
                ),
              ),
              itemCount: _filteredTasks.length,
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.onTap,
    this.height = 36,
    this.minWidth = 96,
  });

  final String label;
  final VoidCallback onTap;
  final double minWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
      child: Material(
        color: Colors.white,
        shape: StadiumBorder(side: BorderSide(color: Colors.grey.shade300)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SvgPicture.asset(
                    'assets/filter.svg',
                    height: 18,
                    width: 18,
                    colorFilter:
                        const ColorFilter.mode(Colors.black87, BlendMode.srcIn),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 任务列表项，可在 HomePage 与 CompletedTasksPage 中复用
class TaskTile extends StatelessWidget {
  const TaskTile({
    required this.task,
    required this.onToggle,
  });

  final Task task;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isDone = task.completed;

    final titleStyle = TextStyle(
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w800,
      decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none,
      color: isDone ? Colors.blueGrey : Colors.black,
    );

    final taskEntity = TaskEntity(
      id: task.id,
      title: task.title,
      description: task.description,
      time: task.time,
      date: task.date,
      hasNotification: task.hasNotification,
      repeatRule: task.repeatRule,
      completed: task.completed,
      actions: task.actions,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CircleCheck(completed: isDone, onTap: onToggle),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                isDone
                    ? Text(
                        task.title,
                        style: titleStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : _IncompleteContent(task: task, titleStyle: titleStyle),
                if (task.actions != null && task.actions!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: TaskActionButtons(
                      task: taskEntity,
                      onActionExecuted: () {},
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: PriorityUtils.colorOf(task.priority),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncompleteContent extends StatelessWidget {
  const _IncompleteContent({required this.task, required this.titleStyle});

  final Task task;
  final TextStyle titleStyle;

  @override
  Widget build(BuildContext context) {
    final metaStyle = TextStyle(
      fontSize: 12,
      height: 1.33,
      color: Colors.blueGrey.shade600,
      fontWeight: FontWeight.w600,
    );

    final List<Widget> meta = [];
    if (task.time != null) {
      meta.add(
          _Meta(icon: Icons.access_time, text: task.time!, style: metaStyle));
    }
    if (task.date != null) {
      meta.add(_Meta(icon: Icons.event, text: task.date!, style: metaStyle));
    }
    if (task.hasNotification) {
      meta.add(_Meta(icon: Icons.notifications, text: '', style: metaStyle));
    }
    if ((task.repeatRule ?? '').isNotEmpty) {
      final rule = RepeatSelection.fromStorage(task.repeatRule).toUiRule();
      if (rule != 'No repeat') {
        meta.add(_Meta(icon: Icons.repeat, text: rule, style: metaStyle));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          task.title,
          style: titleStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (meta.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Wrap(spacing: 12, runSpacing: 6, children: meta),
          ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, required this.style});
  final IconData icon;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: style.color),
        if (text.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text(text, style: style),
        ],
      ],
    );
  }
}

class _CircleCheck extends StatelessWidget {
  const _CircleCheck({required this.completed, required this.onTap});
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      customBorder: const CircleBorder(),
      radius: 24,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: completed ? Colors.blue : Colors.blueGrey.shade200,
            width: 2,
          ),
          color: completed ? Colors.blue : Colors.transparent,
        ),
        child: completed
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : null,
      ),
    );
  }
}

// Compact list-style picker row used in the filter sheet.
class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.icon,
    required this.label,
    required this.hasValue,
    required this.onTap,
    this.onClear,
  });

  final IconData icon;
  final String label;
  final bool hasValue;
  final VoidCallback onTap;
  final VoidCallback? onClear;

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
              Icon(icon, size: 18, color: Colors.black87),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: hasValue ? Colors.black : Colors.black54,
                    fontWeight: hasValue ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
              if (hasValue && onClear != null)
                IconButton(
                  tooltip: AppLocalizations.of(context)!.clear,
                  icon:
                      const Icon(Icons.close, size: 20, color: Colors.black54),
                  onPressed: onClear,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
