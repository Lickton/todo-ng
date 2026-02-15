import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static const _dbName = 'doable.db';
  static const _dbVersion = 5;

  static Database? _db;

  static Future<Database> instance() async {
    if (_db != null) return _db!;
    final base = await getDatabasesPath();
    final path = p.join(base, _dbName);
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            description TEXT,
            time TEXT,
            date TEXT,
            has_notification INTEGER NOT NULL DEFAULT 0,
            reminder_time TEXT,
            use_system_alarm INTEGER NOT NULL DEFAULT 0,
            repeat_rule TEXT,
            completed INTEGER NOT NULL DEFAULT 0,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT,
            action_type TEXT,
            action_data TEXT,
            action_target TEXT,
            actions TEXT
          )
        ''');
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          await db.execute('ALTER TABLE tasks ADD COLUMN action_type TEXT');
          await db.execute('ALTER TABLE tasks ADD COLUMN action_data TEXT');
          await db.execute('ALTER TABLE tasks ADD COLUMN action_target TEXT');
        }
        if (oldV < 4) {
          await db.execute('ALTER TABLE tasks ADD COLUMN reminder_time TEXT');
        }
        if (oldV < 5) {
          await db.execute('ALTER TABLE tasks ADD COLUMN use_system_alarm INTEGER NOT NULL DEFAULT 0');
        }
        if (oldV < 3) {
          await db.execute('ALTER TABLE tasks ADD COLUMN actions TEXT');
          // 将旧版单动作迁移到 actions JSON
          final rows = await db.query('tasks',
              columns: ['id', 'action_type', 'action_data', 'action_target']);
          for (final r in rows) {
            final t = r['action_type'] as String?;
            if (t != null && t.toString().trim().isNotEmpty) {
              final list = [
                {
                  'type': t,
                  'data': r['action_data'],
                  'target': r['action_target'],
                }
              ];
              await db.update(
                'tasks',
                {'actions': jsonEncode(list)},
                where: 'id = ?',
                whereArgs: [r['id']],
              );
            }
          }
        }
      },
    );
    return _db!;
  }
}
