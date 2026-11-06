import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._(this.database);
  final Database database;
  static const schemaVersion = 2;

  static Future<LocalDatabase> open({String? path}) async {
    final dbPath = path ?? p.join(await getDatabasesPath(), 'ascend_local_v1.db');
    final database = await openDatabase(
      dbPath,
      version: schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.execute('PRAGMA busy_timeout = 5000');
      },
      onCreate: (db, version) async {
        await _createVersionOne(db);
        await _migrateOneToTwo(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 1) await _createVersionOne(db);
        if (oldVersion < 2) await _migrateOneToTwo(db);
      },
      onDowngrade: (db, oldVersion, newVersion) async {
        throw StateError('Database downgrade from $oldVersion to $newVersion is not supported; data was preserved.');
      },
    );
    return LocalDatabase._(database);
  }

  static Future<void> _createVersionOne(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS user_preferences (
      id TEXT PRIMARY KEY NOT NULL,
      payload TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS scan_records (
      id TEXT PRIMARY KEY NOT NULL,
      payload TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS scan_measurements (
      id TEXT PRIMARY KEY NOT NULL,
      scan_id TEXT NOT NULL REFERENCES scan_records(id) ON DELETE CASCADE,
      payload TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS photo_records (
      id TEXT PRIMARY KEY NOT NULL,
      scan_id TEXT NOT NULL UNIQUE REFERENCES scan_records(id) ON DELETE CASCADE,
      payload TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS coaching_plans (
      id TEXT PRIMARY KEY NOT NULL,
      payload TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS plan_phases (
      id TEXT PRIMARY KEY NOT NULL,
      plan_id TEXT NOT NULL REFERENCES coaching_plans(id) ON DELETE CASCADE,
      phase_order INTEGER NOT NULL,
      payload TEXT NOT NULL,
      UNIQUE(plan_id, phase_order)
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS routines (
      id TEXT PRIMARY KEY NOT NULL,
      plan_id TEXT NOT NULL REFERENCES coaching_plans(id) ON DELETE CASCADE,
      day_index INTEGER NOT NULL,
      payload TEXT NOT NULL,
      UNIQUE(plan_id, day_index)
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS routine_tasks (
      id TEXT PRIMARY KEY NOT NULL,
      routine_id TEXT NOT NULL REFERENCES routines(id) ON DELETE CASCADE,
      payload TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS task_completions (
      id TEXT PRIMARY KEY NOT NULL,
      task_id TEXT NOT NULL REFERENCES routine_tasks(id) ON DELETE CASCADE,
      payload TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS progress_entries (
      id TEXT PRIMARY KEY NOT NULL,
      scan_id TEXT REFERENCES scan_records(id) ON DELETE SET NULL,
      payload TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS subscription_state (
      id TEXT PRIMARY KEY NOT NULL,
      payload TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS app_settings (
      id TEXT PRIMARY KEY NOT NULL,
      payload TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS migration_log (
      version INTEGER PRIMARY KEY NOT NULL,
      applied_at_utc TEXT NOT NULL
    )''');
    await db.insert('migration_log', {
      'version': 1,
      'applied_at_utc': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<void> _migrateOneToTwo(DatabaseExecutor db) async {
    // Add query indexes only. This migration preserves all existing payloads and IDs.
    await db.execute('CREATE INDEX IF NOT EXISTS idx_measurements_scan ON scan_measurements(scan_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_progress_scan ON progress_entries(scan_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_routines_plan_day ON routines(plan_id, day_index)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_routine ON routine_tasks(routine_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_completion_task ON task_completions(task_id)');
    await db.insert('migration_log', {
      'version': 2,
      'applied_at_utc': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<bool> get hasEncryptedRecords async {
    final tables = <String>[
      'user_preferences', 'scan_records', 'scan_measurements', 'photo_records',
      'coaching_plans', 'plan_phases', 'routines', 'routine_tasks',
      'task_completions', 'progress_entries', 'subscription_state', 'app_settings',
    ];
    for (final table in tables) {
      final rows = await database.rawQuery('SELECT 1 FROM $table LIMIT 1');
      if (rows.isNotEmpty) return true;
    }
    return false;
  }

  Future<void> close() => database.close();
}
