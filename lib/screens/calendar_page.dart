import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:doable_todo_list_app/l10n/app_localizations.dart';
import 'package:doable_todo_list_app/models/task_entity.dart';
import 'package:doable_todo_list_app/repositories/task_repository.dart';
import 'package:doable_todo_list_app/utils/priority_utils.dart';
import 'package:doable_todo_list_app/utils/recurrence_utils.dart';
import 'package:doable_todo_list_app/screens/home_page.dart' show Task;
import 'package:doable_todo_list_app/widgets/task_detail_sheet.dart';

/// Todoist 风格日历视图：可展开/收起的月历 + 按日期分组的任务列表
class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
    this.refreshTrigger = 0,
    this.onGoToTodayRequested,
  });

  final int refreshTrigger;
  /// 父组件请求回到今天时调用（如底部定位按钮）
  final void Function(void Function() goToToday)? onGoToTodayRequested;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  bool _calendarExpanded = false;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _overdueExpanded = true;

  List<TaskEntity> _allTasks = [];
  List<TaskEntity> _overdueTasks = [];
  Map<DateTime, List<TaskEntity>> _groupedTasks = {};
  final Set<String> _datesWithTasks = {};
  final Map<String, GlobalKey> _dateKeys = {};
  final ScrollController _scrollController = ScrollController();

  static final DateFormat _dateFmt = DateFormat('dd/MM/yy');

  double verticalPadding(BuildContext context) =>
      MediaQuery.of(context).size.height * 0.05;
  double horizontalPadding(BuildContext context) =>
      MediaQuery.of(context).size.width * 0.05;

  @override
  void initState() {
    super.initState();
    _load();
    widget.onGoToTodayRequested?.call(_goToToday);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CalendarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshTrigger != oldWidget.refreshTrigger) {
      _load();
    }
    if (widget.onGoToTodayRequested != oldWidget.onGoToTodayRequested) {
      widget.onGoToTodayRequested?.call(_goToToday);
    }
  }

  Future<void> _load() async {
    final tasks = await TaskRepository().fetchAll();
    if (!mounted) return;
    setState(() {
      _allTasks = tasks;
      _processTasksForCalendar();
    });
  }

  void _processTasksForCalendar() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    _overdueTasks = [];
    _groupedTasks = {};
    _datesWithTasks.clear();

    // 初始化未来 7 天的日期分组
    for (int i = 0; i < 7; i++) {
      final date = today.add(Duration(days: i));
      _groupedTasks[date] = [];
    }

    for (var task in _allTasks.where((t) => !t.completed)) {
      if (task.date == null || task.date!.isEmpty) continue;

      final taskDate = _parseTaskDate(task.date!);
      if (taskDate == null) continue;

      final taskDateOnly = DateTime(taskDate.year, taskDate.month, taskDate.day);

      if (taskDateOnly.isBefore(today)) {
        _overdueTasks.add(task);
        _datesWithTasks.add(_dateKey(taskDateOnly));
      } else {
        if (RecurrenceUtils.taskMatchesDate(task, taskDateOnly)) {
          _groupedTasks[taskDateOnly] ??= [];
          _groupedTasks[taskDateOnly]!.add(task);
          _datesWithTasks.add(_dateKey(taskDateOnly));
        }
      }
    }

    // 处理重复任务：可能出现在未来多天
    for (var task in _allTasks.where((t) => !t.completed)) {
      if (task.date == null || task.date!.isEmpty) continue;
      final baseDate = _parseTaskDate(task.date!);
      if (baseDate == null) continue;
      final rule = (task.repeatRule ?? '').trim().toLowerCase();
      if (rule.isEmpty || rule == 'no repeat') continue;

      for (int i = 1; i < 7; i++) {
        final d = today.add(Duration(days: i));
        if (RecurrenceUtils.taskMatchesDate(task, d) && !(_groupedTasks[d] ?? []).contains(task)) {
          _groupedTasks[d] ??= [];
          _groupedTasks[d]!.add(task);
          _datesWithTasks.add(_dateKey(d));
        }
      }
    }

    // 为日历标记扩展：过去 60 天 + 未来 90 天，检查重复任务
    for (var task in _allTasks.where((t) => !t.completed)) {
      if (task.date == null || task.date!.isEmpty) continue;
      final rule = (task.repeatRule ?? '').trim().toLowerCase();
      if (rule.isEmpty || rule == 'no repeat') continue;
      for (int i = -60; i <= 90; i++) {
        final d = today.add(Duration(days: i));
        if (RecurrenceUtils.taskMatchesDate(task, d)) {
          _datesWithTasks.add(_dateKey(d));
        }
      }
    }

    _overdueTasks.sort((a, b) {
      final pa = PriorityUtils.sortOrder(a.priority);
      final pb = PriorityUtils.sortOrder(b.priority);
      if (pa != pb) return pa.compareTo(pb);
      return _parseTaskDate(a.date!)!.compareTo(_parseTaskDate(b.date!)!);
    });
  }

  List<TaskEntity> _sortTasksByPriority(List<TaskEntity> tasks) {
    final list = List<TaskEntity>.from(tasks);
    list.sort((a, b) => PriorityUtils.sortOrder(a.priority).compareTo(PriorityUtils.sortOrder(b.priority)));
    return list;
  }

  DateTime? _parseTaskDate(String dateStr) {
    try {
      return _dateFmt.parseStrict(dateStr);
    } catch (_) {
      return null;
    }
  }

  String _formatDate(DateTime d) => _dateFmt.format(d);

  Future<void> _toggleTaskComplete(TaskEntity task) async {
    final markingComplete = !task.completed;
    await TaskRepository().toggle(task.id!, markingComplete);
    await _load();
    if (mounted && markingComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.taskCompletedMessage(task.title)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  void _scrollToDate(DateTime date) {
    final keyStr = _dateKey(date);
    final key = _dateKeys[keyStr];

    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        alignment: 0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showRescheduleOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${AppLocalizations.of(context)!.reschedule} ${_overdueTasks.length}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.today, color: Colors.blue),
                title: Text(AppLocalizations.of(context)!.today),
                onTap: () => _rescheduleTasks(DateTime.now()),
              ),
              ListTile(
                leading: const Icon(Icons.wb_sunny, color: Colors.orange),
                title: Text(AppLocalizations.of(context)!.tomorrow),
                onTap: () =>
                    _rescheduleTasks(DateTime.now().add(const Duration(days: 1))),
              ),
              ListTile(
                leading: const Icon(Icons.weekend, color: Colors.green),
                title: Text(AppLocalizations.of(context)!.thisWeekend),
                onTap: () => _rescheduleToWeekend(),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today, color: Colors.purple),
                title: Text(AppLocalizations.of(context)!.customDate),
                onTap: () {
                  Navigator.pop(context);
                  _showDatePicker();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _rescheduleTasks(DateTime newDate) async {
    Navigator.pop(context);

    for (var task in _overdueTasks) {
      final entity = task.copyWith(date: _formatDate(newDate));
      await TaskRepository().update(entity);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!
                .tasksRescheduled(_overdueTasks.length))),
      );
      await _load();
    }
  }

  void _rescheduleToWeekend() {
    final now = DateTime.now();
    final weekday = now.weekday;
    // 6=Sat, 7=Sun
    final daysUntilSat = (6 - weekday) % 7;
    final saturday = now.add(Duration(days: daysUntilSat == 0 ? 7 : daysUntilSat));
    _rescheduleTasks(saturday);
  }

  Future<void> _showDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: AppLocalizations.of(context)!.selectDate,
    );
    if (picked != null) {
      await _rescheduleTasks(picked);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _goToToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _focusedDay = today;
      _selectedDay = today;
    });
    // 延迟滚动，确保 rebuild 完成、布局就绪后再滚动
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToDate(today);
      // 若 ensureVisible 未生效，再试一次（某些情况下首帧布局未完成）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToDate(today);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final monthYearTitle = DateFormat.yMMMM(
            Localizations.localeOf(context).toString())
        .format(_focusedDay);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 月份标题（可点击展开/收起）
          InkWell(
            onTap: () {
              setState(() => _calendarExpanded = !_calendarExpanded);
            },
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding(context),
                verticalPadding(context),
                horizontalPadding(context),
                8,
              ),
              child: Row(
                children: [
                  Text(
                    monthYearTitle,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _calendarExpanded ? Colors.blue : Colors.black,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _calendarExpanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    color: _calendarExpanded ? Colors.blue : Colors.grey,
                  ),
                ],
              ),
            ),
          ),

          // 日历组件（收起时需足够高度容纳周视图：星期标题 + 一行日期）
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _calendarExpanded ? 380 : 160,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding(context)),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => _isSameDay(_selectedDay, day),
              calendarFormat:
                  _calendarExpanded ? CalendarFormat.month : CalendarFormat.week,
              startingDayOfWeek: StartingDayOfWeek.monday,
              rowHeight: 52,
              availableGestures: AvailableGestures.horizontalSwipe,
              eventLoader: (day) {
                final key = _dateKey(DateTime(day.year, day.month, day.day));
                return _datesWithTasks.contains(key) ? ['task'] : [];
              },
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, events) {
                  if (events.isEmpty) return null;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade400,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  );
                },
              ),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                _scrollToDate(selectedDay);
              },
              onPageChanged: (focusedDay) {
                setState(() => _focusedDay = focusedDay);
              },
              calendarStyle: CalendarStyle(
                markersAlignment: Alignment.bottomCenter,
                markersAnchor: 0.95,
                markerMargin: const EdgeInsets.only(top: 6),
                todayDecoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                todayTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                selectedDecoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                ),
                defaultTextStyle: const TextStyle(fontSize: 16),
                weekendTextStyle: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                outsideTextStyle: TextStyle(color: Colors.grey.shade400),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: false,
                titleTextStyle: TextStyle(fontSize: 0),
                leftChevronVisible: false,
                rightChevronVisible: false,
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: Colors.grey.shade700),
                weekendStyle: TextStyle(color: Colors.grey.shade700),
              ),
            ),
          ),

          // 任务列表
          Expanded(
            child: _allTasks.isEmpty
                ? _buildEmptyState(loc)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding(context)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_overdueTasks.isNotEmpty) ...[
                            _buildSectionHeader(
                                loc.overdue, _overdueTasks.length, loc),
                            if (_overdueExpanded)
                              ..._overdueTasks.map((t) => _buildTaskCard(t)),
                            const SizedBox(height: 24),
                          ],
                          ...(_groupedTasks.entries.toList()
                                ..sort((a, b) => a.key.compareTo(b.key)))
                              .map((entry) =>
                                  _buildDateSection(entry.key, entry.value, loc)),
                          const SizedBox(height: 96),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations loc) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            loc.noTasks,
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            loc.tapToAddTask,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      String title, int count, AppLocalizations loc) {
    return InkWell(
      onTap: () {
        setState(() => _overdueExpanded = !_overdueExpanded);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: _showRescheduleOptions,
              child: Text(loc.reschedule,
                  style: const TextStyle(color: Colors.blue)),
            ),
            Icon(
              _overdueExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSection(
      DateTime date, List<TaskEntity> tasks, AppLocalizations loc) {
    final keyStr = _dateKey(date);
    final key = _dateKeys[keyStr] ??= GlobalKey();
    final weekdayNames = [
      loc.monday,
      loc.tuesday,
      loc.wednesday,
      loc.thursday,
      loc.friday,
      loc.saturday,
      loc.sunday,
    ];
    final weekday = weekdayNames[date.weekday - 1];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    String dateLabel = '';
    if (dateOnly == today) {
      dateLabel = ' • ${loc.today}';
    } else if (dateOnly == tomorrow) {
      dateLabel = ' • ${loc.tomorrow}';
    }

    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final dateStr = isZh
        ? '${date.month}月${date.day}日'
        : '${date.month}/${date.day}';

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            '$weekday, $dateStr$dateLabel',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        if (tasks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                loc.noTasks,
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          )
        else
          ..._sortTasksByPriority(tasks).map((t) => _buildTaskCard(t)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTaskCard(TaskEntity task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () async {
          final t = Task(
            id: task.id!,
            title: task.title,
            description: task.description,
            time: task.time,
            date: task.date,
            timeKind: task.timeKind,
            endTime: task.endTime,
            endDate: task.endDate,
            hasNotification: task.hasNotification,
            reminderTime: task.reminderTime,
            useSystemAlarm: task.useSystemAlarm,
            repeatRule: task.repeatRule,
            completed: task.completed,
            priority: task.priority,
            actions: task.actions,
          );
          final result = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            barrierColor: Colors.black54,
            builder: (context) => TaskDetailSheet(task: t),
          );
          if (result == true) await _load();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: () => _toggleTaskComplete(task),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: task.completed
                          ? Colors.green
                          : Colors.grey.shade400,
                      width: 2,
                    ),
                    color: task.completed ? Colors.green : Colors.transparent,
                  ),
                  child: task.completed
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 16,
                    decoration:
                        task.completed ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 4,
                height: 32,
                decoration: BoxDecoration(
                  color: PriorityUtils.colorOf(task.priority),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
