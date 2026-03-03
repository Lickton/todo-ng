import 'dart:convert';

import 'package:intl/intl.dart';

enum RepeatFrequency {
  none,
  daily,
  weekly,
  monthly,
  yearly,
}

class RepeatSelection {
  const RepeatSelection({
    required this.frequency,
    this.weekdays = const <int>{},
    this.monthDays = const <int>{},
    this.yearMonthDays = const <int, Set<int>>{},
  });

  final RepeatFrequency frequency;
  final Set<int> weekdays;
  final Set<int> monthDays;
  final Map<int, Set<int>> yearMonthDays;

  bool get isRepeating => frequency != RepeatFrequency.none;

  String? toStorage() {
    if (!isRepeating) return null;
    final map = <String, dynamic>{'freq': _freqToWire(frequency)};
    if (frequency == RepeatFrequency.weekly && weekdays.isNotEmpty) {
      map['weekdays'] = weekdays.toList()..sort();
    }
    if (frequency == RepeatFrequency.monthly && monthDays.isNotEmpty) {
      map['month_days'] = monthDays.toList()..sort();
    }
    if (frequency == RepeatFrequency.yearly && yearMonthDays.isNotEmpty) {
      final parts = <String>[];
      for (final e in yearMonthDays.entries) {
        final days = e.value.toList()..sort();
        for (final d in days) {
          parts.add('${e.key}-$d');
        }
      }
      parts.sort();
      map['year_month_days'] = parts;
    }
    return 'v2:${jsonEncode(map)}';
  }

  static RepeatSelection fromStorage(String? raw, {DateTime? baseDate}) {
    if (raw == null || raw.trim().isEmpty) {
      return const RepeatSelection(frequency: RepeatFrequency.none);
    }

    final r = raw.trim();
    if (r == 'No repeat') {
      return const RepeatSelection(frequency: RepeatFrequency.none);
    }

    if (r.startsWith('v2:')) {
      try {
        final payload = jsonDecode(r.substring(3)) as Map<String, dynamic>;
        final freq = _freqFromWire(payload['freq'] as String?);
        final weekdays =
            ((payload['weekdays'] as List<dynamic>?) ?? const <dynamic>[])
                .map((e) => int.tryParse(e.toString()))
                .where((v) => v != null && v >= 1 && v <= 7)
                .cast<int>()
                .toSet();
        final monthDays =
            ((payload['month_days'] as List<dynamic>?) ?? const <dynamic>[])
                .map((e) => int.tryParse(e.toString()))
                .where((v) => v != null && v >= 1 && v <= 31)
                .cast<int>()
                .toSet();
        final yearlyRaw = ((payload['year_month_days'] as List<dynamic>?) ??
                const <dynamic>[])
            .map((e) => e.toString())
            .toList();
        final yearly = <int, Set<int>>{};
        for (final p in yearlyRaw) {
          final dash = p.indexOf('-');
          if (dash <= 0 || dash >= p.length - 1) continue;
          final m = int.tryParse(p.substring(0, dash).trim());
          final d = int.tryParse(p.substring(dash + 1).trim());
          if (m == null || d == null || m < 1 || m > 12 || d < 1 || d > 31) {
            continue;
          }
          yearly.putIfAbsent(m, () => <int>{}).add(d);
        }
        return RepeatSelection(
          frequency: freq,
          weekdays: weekdays,
          monthDays: monthDays,
          yearMonthDays: yearly,
        );
      } catch (_) {
        return const RepeatSelection(frequency: RepeatFrequency.none);
      }
    }

    return _fromLegacy(r, baseDate: baseDate);
  }

  static RepeatSelection fromUi({
    required String? rule,
    required Set<int> weekdays,
    required Set<int> monthDays,
    required Map<int, Set<int>> yearMonthDays,
  }) {
    switch (rule) {
      case 'Daily':
        return const RepeatSelection(frequency: RepeatFrequency.daily);
      case 'Weekly':
        return RepeatSelection(
          frequency: RepeatFrequency.weekly,
          weekdays: Set<int>.from(weekdays),
        );
      case 'Monthly':
        return RepeatSelection(
          frequency: RepeatFrequency.monthly,
          monthDays: Set<int>.from(monthDays),
        );
      case 'Yearly':
        return RepeatSelection(
          frequency: RepeatFrequency.yearly,
          yearMonthDays: Map<int, Set<int>>.from(
            yearMonthDays.map((k, v) => MapEntry(k, Set<int>.from(v))),
          ),
        );
      default:
        return const RepeatSelection(frequency: RepeatFrequency.none);
    }
  }

  bool matchesDate(DateTime date, DateTime baseDate) {
    switch (frequency) {
      case RepeatFrequency.none:
        return _sameDay(date, baseDate);
      case RepeatFrequency.daily:
        return true;
      case RepeatFrequency.weekly:
        final weekdaysToUse =
            weekdays.isEmpty ? <int>{baseDate.weekday} : weekdays;
        return weekdaysToUse.contains(date.weekday);
      case RepeatFrequency.monthly:
        final daysToUse = monthDays.isEmpty ? <int>{baseDate.day} : monthDays;
        return daysToUse.contains(date.day);
      case RepeatFrequency.yearly:
        if (yearMonthDays.isEmpty) {
          return date.month == baseDate.month && date.day == baseDate.day;
        }
        return yearMonthDays[date.month]?.contains(date.day) == true;
    }
  }

  String toUiRule() {
    switch (frequency) {
      case RepeatFrequency.daily:
        return 'Daily';
      case RepeatFrequency.weekly:
        return 'Weekly';
      case RepeatFrequency.monthly:
        return 'Monthly';
      case RepeatFrequency.yearly:
        return 'Yearly';
      case RepeatFrequency.none:
        return 'No repeat';
    }
  }

  static RepeatSelection _fromLegacy(String raw, {DateTime? baseDate}) {
    final lower = raw.toLowerCase();
    if (lower == 'daily') {
      return const RepeatSelection(frequency: RepeatFrequency.daily);
    }

    if (lower.startsWith('weekly')) {
      final weekdays = <int>{};
      final colon = raw.indexOf(':');
      if (colon >= 0 && colon + 1 < raw.length) {
        final parts = raw.substring(colon + 1).split(RegExp(r'[,\s\[\]]+'));
        for (final p in parts) {
          final v = int.tryParse(p.trim());
          if (v != null && v >= 1 && v <= 7) weekdays.add(v);
        }
      }
      if (weekdays.isEmpty && baseDate != null) {
        weekdays.add(baseDate.weekday);
      }
      return RepeatSelection(
        frequency: RepeatFrequency.weekly,
        weekdays: weekdays,
      );
    }

    if (lower.startsWith('monthly')) {
      final monthDays = <int>{};
      final colon = raw.indexOf(':');
      if (colon >= 0 && colon + 1 < raw.length) {
        final parts = raw.substring(colon + 1).split(RegExp(r'[,\s\[\]]+'));
        for (final p in parts) {
          final v = int.tryParse(p.trim());
          if (v != null && v >= 1 && v <= 31) monthDays.add(v);
        }
      }
      if (monthDays.isEmpty && baseDate != null) {
        monthDays.add(baseDate.day);
      }
      return RepeatSelection(
        frequency: RepeatFrequency.monthly,
        monthDays: monthDays,
      );
    }

    if (lower.startsWith('yearly')) {
      final yearly = <int, Set<int>>{};
      final colon = raw.indexOf(':');
      if (colon >= 0 && colon + 1 < raw.length) {
        final parts = raw.substring(colon + 1).split(',');
        for (final part in parts) {
          final dash = part.indexOf('-');
          if (dash <= 0 || dash >= part.length - 1) continue;
          final m = int.tryParse(part.substring(0, dash).trim());
          final d = int.tryParse(part.substring(dash + 1).trim());
          if (m == null || d == null || m < 1 || m > 12 || d < 1 || d > 31) {
            continue;
          }
          yearly.putIfAbsent(m, () => <int>{}).add(d);
        }
      }
      if (yearly.isEmpty && baseDate != null) {
        yearly.putIfAbsent(baseDate.month, () => <int>{}).add(baseDate.day);
      }
      return RepeatSelection(
        frequency: RepeatFrequency.yearly,
        yearMonthDays: yearly,
      );
    }

    return const RepeatSelection(frequency: RepeatFrequency.none);
  }

  static String _freqToWire(RepeatFrequency f) {
    switch (f) {
      case RepeatFrequency.daily:
        return 'daily';
      case RepeatFrequency.weekly:
        return 'weekly';
      case RepeatFrequency.monthly:
        return 'monthly';
      case RepeatFrequency.yearly:
        return 'yearly';
      case RepeatFrequency.none:
        return 'none';
    }
  }

  static RepeatFrequency _freqFromWire(String? f) {
    switch ((f ?? '').toLowerCase()) {
      case 'daily':
        return RepeatFrequency.daily;
      case 'weekly':
        return RepeatFrequency.weekly;
      case 'monthly':
        return RepeatFrequency.monthly;
      case 'yearly':
        return RepeatFrequency.yearly;
      default:
        return RepeatFrequency.none;
    }
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

enum ReminderType {
  relative,
  absolute,
}

class ReminderRule {
  const ReminderRule.relative(this.minutesBefore)
      : type = ReminderType.relative,
        absoluteAt = null;

  const ReminderRule.absolute(this.absoluteAt)
      : type = ReminderType.absolute,
        minutesBefore = null;

  final ReminderType type;
  final int? minutesBefore;
  final DateTime? absoluteAt;

  String toStorage() {
    if (type == ReminderType.relative) {
      return 'v2:${jsonEncode({
            'type': 'relative',
            'minutes_before': minutesBefore ?? 0
          })}';
    }
    return 'v2:${jsonEncode({
          'type': 'absolute',
          'at': absoluteAt?.toIso8601String()
        })}';
  }

  DateTime? scheduleAt(DateTime occurrenceDateTime) {
    if (type == ReminderType.relative) {
      return occurrenceDateTime.subtract(Duration(minutes: minutesBefore ?? 0));
    }
    return absoluteAt;
  }

  static ReminderRule? fromStorage(
    String? raw, {
    DateTime? occurrenceDateTime,
  }) {
    if (raw == null || raw.trim().isEmpty) return null;
    final r = raw.trim();

    if (r.startsWith('v2:')) {
      try {
        final payload = jsonDecode(r.substring(3)) as Map<String, dynamic>;
        final type = (payload['type'] as String? ?? '').toLowerCase();
        if (type == 'relative') {
          final mins = int.tryParse(payload['minutes_before'].toString()) ?? 0;
          return ReminderRule.relative(mins < 0 ? 0 : mins);
        }
        if (type == 'absolute') {
          final atStr = payload['at'] as String?;
          if (atStr == null || atStr.isEmpty) return null;
          return ReminderRule.absolute(DateTime.tryParse(atStr));
        }
      } catch (_) {
        return null;
      }
    }

    return _fromLegacy(r, occurrenceDateTime: occurrenceDateTime);
  }

  static ReminderRule? fromUi(
    String? uiRaw, {
    required DateTime? occurrenceDateTime,
  }) {
    if (uiRaw == null || uiRaw.trim().isEmpty) return null;
    final r = uiRaw.trim();
    if (r.startsWith('v2:')) {
      return fromStorage(r, occurrenceDateTime: occurrenceDateTime);
    }
    return _fromLegacy(r, occurrenceDateTime: occurrenceDateTime);
  }

  static ReminderRule? _fromLegacy(
    String raw, {
    DateTime? occurrenceDateTime,
  }) {
    final legacyFmt = DateFormat('dd/MM/yy h:mm a');
    if (raw.startsWith('offset:')) {
      final mins = int.tryParse(raw.substring(7)) ?? 5;
      return ReminderRule.relative(mins < 0 ? 0 : mins);
    }
    if (raw.startsWith('days_before:')) {
      if (occurrenceDateTime == null) return null;
      final rest = raw.substring(12);
      final comma = rest.indexOf(',');
      if (comma <= 0) return null;
      final n = int.tryParse(rest.substring(0, comma).trim());
      final timeStr = rest.substring(comma + 1).trim();
      if (n == null || n < 1) return null;
      try {
        final t = DateFormat('h:mm a').parseStrict(timeStr);
        final reminderDate = occurrenceDateTime.subtract(Duration(days: n));
        final reminderDt = DateTime(
          reminderDate.year,
          reminderDate.month,
          reminderDate.day,
          t.hour,
          t.minute,
        );
        final minutes = occurrenceDateTime.difference(reminderDt).inMinutes;
        return ReminderRule.relative(minutes < 0 ? 0 : minutes);
      } catch (_) {
        return null;
      }
    }
    if (raw.startsWith('custom:')) {
      try {
        return ReminderRule.absolute(legacyFmt.parse(raw.substring(7)));
      } catch (_) {
        return null;
      }
    }
    try {
      return ReminderRule.absolute(legacyFmt.parse(raw));
    } catch (_) {
      return null;
    }
  }

  static String? toLegacyUi(
    String? raw, {
    DateTime? occurrenceDateTime,
  }) {
    final rule = fromStorage(raw, occurrenceDateTime: occurrenceDateTime);
    if (rule == null) return null;
    final legacyFmt = DateFormat('dd/MM/yy h:mm a');
    if (rule.type == ReminderType.relative) {
      return 'offset:${rule.minutesBefore ?? 0}';
    }
    if (rule.absoluteAt == null) return null;
    return legacyFmt.format(rule.absoluteAt!);
  }
}
