import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static const _dbName = 'doable.db';
  static const _dbVersion = 2;

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
            repeat_rule TEXT,
            completed INTEGER NOT NULL DEFAULT 0,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT,
            action_type TEXT,
            action_data TEXT,
            action_target TEXT
          )
        ''');
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          await db.execute('ALTER TABLE tasks ADD COLUMN action_type TEXT');
          await db.execute('ALTER TABLE tasks ADD COLUMN action_data TEXT');
          await db.execute('ALTER TABLE tasks ADD COLUMN action_target TEXT');
        }
      },
    );
    return _db!;
  }
}
