import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../models/task_entity.dart';
import 'database_service.dart';

class TaskDao {
  static const table = 'tasks';

  static Future<int> insert(TaskEntity t) async {
    final db = await DatabaseService.instance();
    t.updatedAt = DateTime.now().toIso8601String();
    return db.insert(table, t.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<int> update(TaskEntity t) async {
    final db = await DatabaseService.instance();
    t.updatedAt = DateTime.now().toIso8601String();
    final m = Map<String, dynamic>.from(t.toMap());
    m.remove('id'); // 不更新主键
    if (kDebugMode) {
      final d = m['description'] as String?;
      debugPrint('[TaskDao.update] id=${t.id}, description长度=${d?.length ?? 0}, '
          'rowsUpdated将返回...');
    }
    final rows = await db.update(table, m, where: 'id = ?', whereArgs: [t.id]);
    if (kDebugMode) {
      debugPrint('[TaskDao.update] 实际更新行数=$rows');
    }
    return rows;
  }

  static Future<int> toggleCompleted(int id, bool value) async {
    final db = await DatabaseService.instance();
    return db.update(
      table,
      {'completed': value ? 1 : 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<int> delete(int id) async {
    final db = await DatabaseService.instance();
    return db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<TaskEntity>> getAll() async {
    final db = await DatabaseService.instance();
    final rows = await db.query(
      table,
      orderBy: 'completed ASC, updated_at DESC, id DESC',
    );
    return rows.map(TaskEntity.fromMap).toList();
  }

  static Future<TaskEntity?> getById(int id) async {
    final db = await DatabaseService.instance();
    final rows = await db.query(table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return TaskEntity.fromMap(rows.first);
  }

  /// 获取所有设置了动作的任务（actions 非空或兼容旧 action_type）。
  static Future<List<TaskEntity>> getTasksWithActions() async {
    final db = await DatabaseService.instance();
    final rows = await db.query(
      table,
      where: "(actions IS NOT NULL AND actions != '' AND actions != '[]') "
          "OR (action_type IS NOT NULL AND action_type != '')",
      orderBy: 'completed ASC, updated_at DESC, id DESC',
    );
    return rows.map(TaskEntity.fromMap).toList();
  }

  /// 按动作类型筛选任务（检查 actions JSON 或旧 action_type）。
  static Future<List<TaskEntity>> getTasksByActionType(String type) async {
    final db = await DatabaseService.instance();
    final rows = await db.query(
      table,
      where: "actions LIKE ? OR action_type = ?",
      whereArgs: ['%"type":"$type"%', type],
      orderBy: 'completed ASC, updated_at DESC, id DESC',
    );
    return rows.map(TaskEntity.fromMap).toList();
  }

  static Future<int> clearAll() async {
    final db = await DatabaseService.instance();
    return db.delete('tasks');
  }

  // Optional convenience for seeding demo data
  static Future<void> seedDemo() async {
    final db = await DatabaseService.instance();
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $table'),
    ) ??
        0;
    if (count > 0) return;
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    batch.insert(table, {
      'title': 'Return library books',
      'description': 'Gather overdue library books and return…',
      'time': '11:30 AM',
      'date': '26/11/24',
      'has_notification': 1,
      'repeat_rule': 'Weekly',
      'completed': 0,
      'created_at': now,
      'updated_at': now,
    });
    batch.insert(table, {
      'title': 'Schedule car maintenance',
      'description': "Check your car's maintenance schedule",
      'time': '3:30 PM',
      'date': '26/11/24',
      'has_notification': 1,
      'repeat_rule': null,
      'completed': 0,
      'created_at': now,
      'updated_at': now,
    });
    batch.insert(table, {
      'title': 'Go for grocery shop',
      'description': 'Buy milk, eggs, bread, fruits, and veggies',
      'time': '7:00 PM',
      'date': '26/11/24',
      'has_notification': 0,
      'repeat_rule': 'Daily',
      'completed': 1,
      'created_at': now,
      'updated_at': now,
    });
    batch.insert(table, {
      'title': 'Donate unwanted items',
      'description': 'Sort clothes and books; drop off at local charity',
      'time': '5:30 PM',
      'date': '27/11/24',
      'has_notification': 1,
      'repeat_rule': 'monthly',
      'completed': 1,
      'created_at': now,
      'updated_at': now,
    });
    await batch.commit(noResult: true);
  }
}
