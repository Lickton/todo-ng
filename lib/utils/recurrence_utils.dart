import 'package:intl/intl.dart';

import '../models/task_entity.dart';
import 'task_schedule_codec.dart';

/// 重复任务发生时间计算工具
class RecurrenceUtils {
  static final DateFormat _dateFmt = DateFormat('dd/MM/yy');
  static final DateFormat _timeFmt = DateFormat('h:mm a');

  /// 获取任务在指定日期的发生时刻（用于提醒）
  /// 使用 onDate 的日期 + task 的时间部分
  static DateTime? getOccurrenceDateTime(TaskEntity task, DateTime onDate) {
    final timeStr = task.time;
    if (timeStr == null || timeStr.isEmpty) return null;
    try {
      final t = _timeFmt.parseStrict(timeStr);
      return DateTime(
        onDate.year,
        onDate.month,
        onDate.day,
        t.hour,
        t.minute,
      );
    } catch (_) {
      return null;
    }
  }

  /// 获取任务基准发生时刻（单次任务或重复的首次）
  static DateTime? getBaseOccurrenceDateTime(TaskEntity task) {
    final dateStr = task.date;
    final timeStr = task.time;
    if (dateStr == null || dateStr.isEmpty) return null;
    if (timeStr == null || timeStr.isEmpty) return null;
    try {
      final d = _dateFmt.parseStrict(dateStr);
      final t = _timeFmt.parseStrict(timeStr);
      return DateTime(d.year, d.month, d.day, t.hour, t.minute);
    } catch (_) {
      return null;
    }
  }

  /// 任务在指定日期是否发生（考虑重复规则）
  static bool taskMatchesDate(TaskEntity t, DateTime d) {
    final dateStr = t.date;
    if (dateStr == null || dateStr.isEmpty) return false;
    DateTime baseDate;
    try {
      baseDate = _dateFmt.parseStrict(dateStr);
    } catch (_) {
      return false;
    }
    final repeat = RepeatSelection.fromStorage(
      t.repeatRule,
      baseDate: baseDate,
    );
    return repeat.matchesDate(d, baseDate);
  }

  /// 获取未来 N 天内任务的所有发生日期（用于调度提醒）
  static List<DateTime> getOccurrenceDatesInRange(
    TaskEntity task,
    DateTime from,
    int daysAhead,
  ) {
    final result = <DateTime>[];
    for (int i = 0; i < daysAhead; i++) {
      final d =
          DateTime(from.year, from.month, from.day).add(Duration(days: i));
      if (taskMatchesDate(task, d)) {
        result.add(d);
      }
    }
    return result;
  }
}
