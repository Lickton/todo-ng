import 'package:intl/intl.dart';

import '../models/task_entity.dart';

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
    String? dateStr;
    String? timeStr;
    switch (task.timeKind) {
      case TimeKind.startOnly:
      case TimeKind.both:
        dateStr = task.date;
        timeStr = task.time;
        break;
      case TimeKind.endOnly:
        dateStr = task.date;
        timeStr = task.time;
        break;
    }
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
    String? dateStr;
    switch (t.timeKind) {
      case TimeKind.startOnly:
      case TimeKind.both:
        dateStr = t.date;
        break;
      case TimeKind.endOnly:
        dateStr = t.date;
        break;
    }
    if (dateStr == null || dateStr.isEmpty) return false;
    DateTime baseDate;
    try {
      baseDate = _dateFmt.parseStrict(dateStr);
    } catch (_) {
      return false;
    }
    final dateStrD = _dateFmt.format(d);
    final rule = (t.repeatRule ?? '').trim().toLowerCase();

    if (rule.isEmpty || rule == 'no repeat') {
      return dateStr == dateStrD;
    }
    if (rule == 'daily') return true;
    if (rule.startsWith('monthly')) {
      Set<int> monthDays = {baseDate.day};
      final colon = rule.indexOf(':');
      if (colon >= 0 && colon + 1 < rule.length) {
        final parts = rule.substring(colon + 1).split(RegExp(r'[,\s\[\]]+'));
        monthDays = parts
            .map((s) => int.tryParse(s.trim()))
            .where((v) => v != null && v >= 1 && v <= 31)
            .cast<int>()
            .toSet();
        if (monthDays.isEmpty) monthDays = {baseDate.day};
      }
      return monthDays.contains(d.day);
    }
    if (rule.startsWith('yearly')) {
      final colon = rule.indexOf(':');
      if (colon < 0 || colon + 1 >= rule.length) {
        return baseDate.month == d.month && baseDate.day == d.day;
      }
      for (final part in rule.substring(colon + 1).split(',')) {
        final dash = part.indexOf('-');
        if (dash > 0 && dash < part.length - 1) {
          final m = int.tryParse(part.substring(0, dash).trim());
          final day = int.tryParse(part.substring(dash + 1).trim());
          if (m == d.month && day == d.day) return true;
        }
      }
      return false;
    }
    if (rule.startsWith('weekly')) {
      Set<int> weekdays = {baseDate.weekday};
      final colon = rule.indexOf(':');
      if (colon >= 0 && colon + 1 < rule.length) {
        final parts = rule.substring(colon + 1).split(',');
        weekdays = parts
            .map((s) => int.tryParse(s.trim()))
            .where((v) => v != null && v >= 1 && v <= 7)
            .cast<int>()
            .toSet();
        if (weekdays.isEmpty) weekdays = {baseDate.weekday};
      }
      return weekdays.contains(d.weekday);
    }
    return dateStr == dateStrD;
  }

  /// 获取未来 N 天内任务的所有发生日期（用于调度提醒）
  static List<DateTime> getOccurrenceDatesInRange(
    TaskEntity task,
    DateTime from,
    int daysAhead,
  ) {
    final result = <DateTime>[];
    for (int i = 0; i < daysAhead; i++) {
      final d = DateTime(from.year, from.month, from.day).add(Duration(days: i));
      if (taskMatchesDate(task, d)) {
        result.add(d);
      }
    }
    return result;
  }
}
