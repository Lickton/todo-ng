import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import 'package:doable_todo_list_app/l10n/app_localizations.dart';
import 'package:doable_todo_list_app/models/task_entity.dart';
import 'package:doable_todo_list_app/repositories/task_repository.dart';
import 'package:doable_todo_list_app/utils/priority_utils.dart';
import 'package:doable_todo_list_app/widgets/task_detail_sheet.dart';

import 'home_page.dart' show Task, TaskTile;

/// 排序方式
enum CompletedSortBy {
  priority,
  startTime,
  endTime,
  duration,
}

class CompletedTasksPage extends StatefulWidget {
  const CompletedTasksPage({super.key, this.refreshTrigger = 0});

  final int refreshTrigger;

  @override
  State<CompletedTasksPage> createState() => _CompletedTasksPageState();
}

class _CompletedTasksPageState extends State<CompletedTasksPage> {
  final List<Task> _tasks = [];
  CompletedSortBy _sortBy = CompletedSortBy.priority;
  bool _ascending = true;
  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};

  double verticalPadding(BuildContext context) =>
      MediaQuery.of(context).size.height * 0.07;
  double horizontalPadding(BuildContext context) =>
      MediaQuery.of(context).size.width * 0.05;

  DateTime? _parseDate(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    try {
      return DateFormat('dd/MM/yy').parseStrict(s);
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseTime(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    try {
      return DateFormat('h:mm a').parseStrict(s);
    } catch (_) {
      return null;
    }
  }

  /// 获取任务开始时间的 DateTime（用于排序），无则返回 null
  DateTime? _startDateTime(Task t) {
    final d = _parseDate(t.date);
    final tm = _parseTime(t.time);
    if (d == null || tm == null) return null;
    return DateTime(d.year, d.month, d.day, tm.hour, tm.minute);
  }

  /// 获取任务结束时间的 DateTime（用于排序），无则返回 null
  DateTime? _endDateTime(Task t) {
    final d = _parseDate(t.endDate);
    final tm = _parseTime(t.endTime);
    if (d == null || tm == null) return null;
    return DateTime(d.year, d.month, d.day, tm.hour, tm.minute);
  }

  /// 获取持续时间（分钟），仅当 timeKind 为 both 且有开始、结束时间时有效
  int? _durationMinutes(Task t) {
    if (t.timeKind != TimeKind.both) return null;
    final start = _startDateTime(t);
    final end = _endDateTime(t);
    if (start == null || end == null) return null;
    return end.difference(start).inMinutes;
  }

  List<Task> get _sortedTasks {
    final list = List<Task>.from(_tasks);
    final asc = _ascending ? 1 : -1;

    list.sort((a, b) {
      switch (_sortBy) {
        case CompletedSortBy.priority:
          final pa = PriorityUtils.sortOrder(a.priority);
          final pb = PriorityUtils.sortOrder(b.priority);
          return (pa - pb) * asc;
        case CompletedSortBy.startTime:
          final sa = _startDateTime(a);
          final sb = _startDateTime(b);
          if (sa == null && sb == null) return 0;
          if (sa == null) return asc;
          if (sb == null) return -asc;
          return sa.compareTo(sb) * asc;
        case CompletedSortBy.endTime:
          final ea = _endDateTime(a);
          final eb = _endDateTime(b);
          if (ea == null && eb == null) return 0;
          if (ea == null) return asc;
          if (eb == null) return -asc;
          return ea.compareTo(eb) * asc;
        case CompletedSortBy.duration:
          final da = _durationMinutes(a);
          final db = _durationMinutes(b);
          if (da == null && db == null) return 0;
          if (da == null) return asc;
          if (db == null) return -asc;
          return (da - db) * asc;
      }
    });
    return list;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CompletedTasksPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshTrigger != oldWidget.refreshTrigger) {
      _load();
    }
  }

  Future<void> _load() async {
    final rows = await TaskRepository().fetchAll();
    final completed = rows.where((e) => e.completed).toList();
    final mapped = completed
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
    await TaskRepository().toggle(t.id, false);
    await _load();
  }

  Future<void> _delete(Task t) async {
    await TaskRepository().delete(t.id);
    await _load();
  }

  Future<void> _batchDelete() async {
    if (_selectedIds.isEmpty) return;
    for (final id in _selectedIds) {
      await TaskRepository().delete(id);
    }
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
    await _load();
  }

  void _toggleSelection(Task task) {
    setState(() {
      if (_selectedIds.contains(task.id)) {
        _selectedIds.remove(task.id);
      } else {
        _selectedIds.add(task.id);
      }
      if (_selectedIds.isEmpty) _isSelectionMode = false;
    });
  }

  void _enterSelectionMode(Task task) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(task.id);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _openSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final l10n = AppLocalizations.of(context)!;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 20),
                Text(
                  l10n.sortBy,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                _SortOption(
                  label: l10n.sortByPriority,
                  selected: _sortBy == CompletedSortBy.priority,
                  onTap: () {
                    setState(() => _sortBy = CompletedSortBy.priority);
                    Navigator.pop(context);
                  },
                ),
                _SortOption(
                  label: l10n.sortByStartTime,
                  selected: _sortBy == CompletedSortBy.startTime,
                  onTap: () {
                    setState(() => _sortBy = CompletedSortBy.startTime);
                    Navigator.pop(context);
                  },
                ),
                _SortOption(
                  label: l10n.sortByEndTime,
                  selected: _sortBy == CompletedSortBy.endTime,
                  onTap: () {
                    setState(() => _sortBy = CompletedSortBy.endTime);
                    Navigator.pop(context);
                  },
                ),
                _SortOption(
                  label: l10n.sortByDuration,
                  selected: _sortBy == CompletedSortBy.duration,
                  onTap: () {
                    setState(() => _sortBy = CompletedSortBy.duration);
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _ascending = !_ascending);
                          Navigator.pop(context);
                        },
                        icon: Icon(
                          _ascending ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 18,
                        ),
                        label: Text(
                          _ascending ? l10n.sortAscending : l10n.sortDescending,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SlidableAutoCloseBehavior(
        closeWhenOpened: true,
        closeWhenTapped: true,
        child: CustomScrollView(
          slivers: [
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (_isSelectionMode) ...[
                          TextButton(
                            onPressed: _exitSelectionMode,
                            child: Text(l10n.cancel),
                          ),
                          const Spacer(),
                          Text(
                            l10n.selectedCount(_selectedIds.length),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: _selectedIds.isEmpty ? null : _batchDelete,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red.shade400,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(l10n.batchDelete),
                          ),
                        ] else ...[
                          Text(
                            l10n.completedTasks,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w800,
                              fontSize: 24,
                              height: 1.3,
                            ),
                          ),
                          const Spacer(),
                          Material(
                            color: Colors.white,
                            shape: StadiumBorder(
                                side: BorderSide(color: Colors.grey.shade300)),
                            child: InkWell(
                              customBorder: const StadiumBorder(),
                              onTap: _openSortSheet,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _sortLabel(l10n),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      _ascending
                                          ? Icons.arrow_upward
                                          : Icons.arrow_downward,
                                      size: 18,
                                      color: Colors.black87,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (_sortedTasks.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      l10n.noCompletedTasks,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList.separated(
              itemBuilder: (context, index) {
                final task = _sortedTasks[index];
                final isSelected = _selectedIds.contains(task.id);
                final tile = GestureDetector(
                  onLongPress: () => _enterSelectionMode(task),
                  onTap: () {
                    if (_isSelectionMode) {
                      _toggleSelection(task);
                    } else {
                      showModalBottomSheet<bool>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        barrierColor: Colors.black54,
                        builder: (context) => TaskDetailSheet(task: task),
                      ).then((result) {
                        if (result == true) _load();
                      });
                    }
                  },
                  child: Row(
                    children: [
                      if (_isSelectionMode) ...[
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Checkbox(
                            value: isSelected,
                            onChanged: (_) => _toggleSelection(task),
                            activeColor: Colors.blue,
                          ),
                        ),
                      ],
                      Expanded(
                        child: TaskTile(task: task, onToggle: () => _toggle(task)),
                      ),
                    ],
                  ),
                );
                if (_isSelectionMode) return tile;
                return Slidable(
                  key: ValueKey(task.id),
                  groupTag: 'completed_tasks',
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
              itemCount: _sortedTasks.length,
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
        ),
      ),
    );
  }

  String _sortLabel(AppLocalizations l10n) {
    switch (_sortBy) {
      case CompletedSortBy.priority:
        return l10n.sortByPriority;
      case CompletedSortBy.startTime:
        return l10n.sortByStartTime;
      case CompletedSortBy.endTime:
        return l10n.sortByEndTime;
      case CompletedSortBy.duration:
        return l10n.sortByDuration;
    }
  }
}

class _SortOption extends StatelessWidget {
  const _SortOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: selected ? const Icon(Icons.check, color: Colors.blue) : null,
      onTap: onTap,
    );
  }
}
