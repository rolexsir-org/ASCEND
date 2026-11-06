import 'dart:io';

import 'package:ascend/data/local_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDirectory;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('ascend-db-test-');
  });

  tearDown(() async {
    if (await tempDirectory.exists()) await tempDirectory.delete(recursive: true);
  });

  test('creates current schema, records migrations, and enables cascading foreign keys', () async {
    final local = await LocalDatabase.open(path: '${tempDirectory.path}/current.db');
    addTearDown(local.close);
    final database = local.database;

    expect(await database.getVersion(), LocalDatabase.schemaVersion);
    final versions = await database.query('migration_log', columns: ['version'], orderBy: 'version');
    expect(versions.map((row) => row['version']), [1, 2]);
    expect(await database.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    final indexes = await database.rawQuery("PRAGMA index_list('routine_tasks')");
    expect(indexes.map((row) => row['name']), contains('idx_tasks_routine'));
  });

  test('upgrades a version-one database without dropping its existing rows', () async {
    final path = '${tempDirectory.path}/legacy.db';
    final legacy = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('CREATE TABLE migration_log (version INTEGER PRIMARY KEY NOT NULL, applied_at_utc TEXT NOT NULL)');
          await db.execute('CREATE TABLE scan_measurements (id TEXT PRIMARY KEY, scan_id TEXT NOT NULL, payload TEXT NOT NULL)');
          await db.execute('CREATE TABLE progress_entries (id TEXT PRIMARY KEY, scan_id TEXT, payload TEXT NOT NULL)');
          await db.execute('CREATE TABLE routines (id TEXT PRIMARY KEY, plan_id TEXT NOT NULL, day_index INTEGER NOT NULL, payload TEXT NOT NULL)');
          await db.execute('CREATE TABLE routine_tasks (id TEXT PRIMARY KEY, routine_id TEXT NOT NULL, payload TEXT NOT NULL)');
          await db.execute('CREATE TABLE task_completions (id TEXT PRIMARY KEY, task_id TEXT NOT NULL, payload TEXT NOT NULL)');
          await db.insert('migration_log', {'version': 1, 'applied_at_utc': '2025-01-01T00:00:00Z'});
          await db.insert('scan_measurements', {'id': 'm1', 'scan_id': 'scan1', 'payload': 'ciphertext'});
        },
      ),
    );
    await legacy.close();

    final local = await LocalDatabase.open(path: path);
    addTearDown(local.close);

    expect(await local.database.getVersion(), 2);
    final preserved = await local.database.query('scan_measurements', where: 'id = ?', whereArgs: ['m1']);
    expect(preserved.single['payload'], 'ciphertext');
    final versions = await local.database.query('migration_log', columns: ['version'], orderBy: 'version');
    expect(versions.map((row) => row['version']), [1, 2]);
  });
}
