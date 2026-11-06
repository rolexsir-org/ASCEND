import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../core/security/secure_vault.dart';
import '../domain/models.dart';
import 'local_database.dart';

class LocalRepository {
  LocalRepository({required this.localDatabase, required this.vault, required this.photos});

  final LocalDatabase localDatabase;
  final SecureVault vault;
  final PrivatePhotoStore photos;
  Database get _db => localDatabase.database;

  Future<void> initialize() async {
    await vault.initialize(encryptedRecordsExist: await localDatabase.hasEncryptedRecords);
    await photos.removeTemporaryArtifacts();
    await _removeOrphanPhotoFiles();
  }

  Future<UserPreferences> getPreferences() async {
    final rows = await _db.query('user_preferences', where: 'id = ?', whereArgs: ['primary'], limit: 1);
    if (rows.isEmpty) return const UserPreferences();
    final json = jsonDecode(await vault.decryptText(rows.single['payload']! as String));
    return UserPreferences.fromJson(Map<String, Object?>.from(json as Map));
  }

  Future<void> savePreferences(UserPreferences preferences) async {
    _validatePreferences(preferences);
    final payload = await vault.encryptText(jsonEncode(preferences.toJson()));
    await _db.insert('user_preferences', {'id': 'primary', 'payload': payload},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Atomically commits the completed consent record and its initial local plan.
  Future<void> saveOnboarding(UserPreferences preferences, CoachingPlan plan) async {
    _validatePreferences(preferences);
    if (!preferences.onboardingComplete) {
      throw ArgumentError('Onboarding preferences must be complete before a plan is committed.');
    }
    final preferencePayload = await vault.encryptText(jsonEncode(preferences.toJson()));
    await _db.transaction((txn) async {
      await txn.insert('user_preferences', {
        'id': 'primary', 'payload': preferencePayload,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await _savePlanInTransaction(txn, plan);
    });
  }

  void _validatePreferences(UserPreferences preferences) {
    if (preferences.dailyMinutes < 5 || preferences.dailyMinutes > 90) {
      throw ArgumentError.value(preferences.dailyMinutes, 'dailyMinutes', 'Must be between 5 and 90.');
    }
    if (preferences.onboardingComplete &&
        (!preferences.ageConfirmed || !preferences.privacyConsent || preferences.goals.isEmpty)) {
      throw ArgumentError('Completed onboarding requires 18+ confirmation, at least one goal, and consent.');
    }
  }

  Future<int> completedScanCount() async => Sqflite.firstIntValue(
      await _db.rawQuery('SELECT COUNT(*) FROM scan_records')) ?? 0;

  Future<void> saveScan(ScanRecord record, Uint8List photoBytes) async {
    if (!record.quality.accepted || !record.measurements.measurementsReliable) {
      throw ArgumentError('Only a quality-accepted, reliable scan may be persisted.');
    }
    final photoId = newLocalId();
    final fileName = await photos.save(photoBytes, photoId: photoId);
    final persisted = ScanRecord(
      id: record.id,
      createdAt: record.createdAt,
      quality: record.quality,
      measurements: record.measurements,
      photoFileName: fileName,
      userNote: record.userNote,
    );
    try {
      final recordPayload = await vault.encryptText(jsonEncode(persisted.toJson()));
      final measurementPayload = await vault.encryptText(jsonEncode(record.measurements.toJson()));
      final photoPayload = await vault.encryptText(jsonEncode({'fileName': fileName}));
      await _db.transaction((txn) async {
        await txn.insert('scan_records', {'id': persisted.id, 'payload': recordPayload});
        await txn.insert('scan_measurements', {
          'id': newLocalId(), 'scan_id': persisted.id, 'payload': measurementPayload,
        });
        await txn.insert('photo_records', {
          'id': photoId, 'scan_id': persisted.id, 'payload': photoPayload,
        });
      });
    } on Object {
      await photos.delete(fileName);
      rethrow;
    }
  }

  Future<List<ScanRecord>> getScans() async {
    final rows = await _db.query('scan_records', orderBy: 'rowid DESC');
    final records = <ScanRecord>[];
    for (final row in rows) {
      final decoded = jsonDecode(await vault.decryptText(row['payload']! as String));
      records.add(ScanRecord.fromJson(Map<String, Object?>.from(decoded as Map)));
    }
    return records;
  }

  Future<Uint8List> readPhotoForScan(ScanRecord scan) => photos.read(scan.photoFileName);

  Future<void> deleteScan(String scanId) async {
    final rows = await _db.query('scan_records', columns: ['payload'], where: 'id = ?', whereArgs: [scanId]);
    if (rows.isEmpty) return;
    final decoded = jsonDecode(await vault.decryptText(rows.single['payload']! as String));
    final record = ScanRecord.fromJson(Map<String, Object?>.from(decoded as Map));
    await _db.transaction((txn) async => txn.delete('scan_records', where: 'id = ?', whereArgs: [scanId]));
    await photos.delete(record.photoFileName);
  }

  Future<void> savePlan(CoachingPlan plan) async {
    if (plan.tasks.isEmpty) throw ArgumentError('Cannot save an empty coaching plan.');
    await _db.transaction((txn) => _savePlanInTransaction(txn, plan));
  }

  Future<void> _savePlanInTransaction(DatabaseExecutor txn, CoachingPlan plan) async {
    if (plan.tasks.isEmpty) throw ArgumentError('Cannot save an empty coaching plan.');
    final planPayload = await vault.encryptText(jsonEncode(plan.toJson()));
    const phaseSpecs = [
      {'id': 'foundation', 'order': 0, 'start': 1, 'end': 30},
      {'id': 'development', 'order': 1, 'start': 31, 'end': 60},
      {'id': 'consistency', 'order': 2, 'start': 61, 'end': 90},
    ];
    final phasePayloads = <String>[];
    for (final phase in phaseSpecs) {
      phasePayloads.add(await vault.encryptText(jsonEncode(phase)));
    }
    final taskPayloads = <String, String>{};
    for (final task in plan.tasks) {
      taskPayloads[task.id] = await vault.encryptText(jsonEncode(task.toJson()));
    }
    await txn.insert('coaching_plans', {'id': plan.id, 'payload': planPayload},
        conflictAlgorithm: ConflictAlgorithm.replace);
    for (var i = 0; i < phaseSpecs.length; i++) {
      final phase = phaseSpecs[i];
      await txn.insert('plan_phases', {
        'id': '${plan.id}-${phase['id']}', 'plan_id': plan.id,
        'phase_order': phase['order'], 'payload': phasePayloads[i],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    final byDay = <int, List<DailyTask>>{};
    for (final task in plan.tasks) {
      byDay.putIfAbsent(task.dayIndex, () => []).add(task);
    }
    for (final entry in byDay.entries) {
      final routineId = '${plan.id}-day-${entry.key}';
      final payload = await vault.encryptText(jsonEncode({'dayIndex': entry.key}));
      await txn.insert('routines', {
        'id': routineId, 'plan_id': plan.id, 'day_index': entry.key, 'payload': payload,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      for (final task in entry.value) {
        await txn.insert('routine_tasks', {
          'id': task.id, 'routine_id': routineId, 'payload': taskPayloads[task.id],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
  }

  Future<CoachingPlan?> getLatestPlan() async {
    final rows = await _db.query('coaching_plans', orderBy: 'rowid DESC', limit: 1);
    if (rows.isEmpty) return null;
    final decoded = jsonDecode(await vault.decryptText(rows.single['payload']! as String));
    return CoachingPlan.fromJson(Map<String, Object?>.from(decoded as Map));
  }

  Future<void> updateTaskState(String taskId, TaskState state) async {
    await _updateTask(taskId, (task) => task.copyWith(state: state), completionState: state);
  }

  Future<void> editTask(String taskId, {required String title, required String instruction}) async {
    final cleanTitle = title.trim();
    final cleanInstruction = instruction.trim();
    if (cleanTitle.isEmpty || cleanTitle.length > 100 || cleanInstruction.isEmpty || cleanInstruction.length > 500) {
      throw ArgumentError('Task title or instruction is outside the allowed length.');
    }
    await _updateTask(taskId, (task) => task.copyWith(title: cleanTitle, instruction: cleanInstruction));
  }

  Future<void> _updateTask(String taskId, DailyTask Function(DailyTask) transform, {TaskState? completionState}) async {
    final rows = await _db.rawQuery('''
      SELECT p.id, p.payload FROM coaching_plans p
      JOIN routines r ON r.plan_id = p.id
      JOIN routine_tasks t ON t.routine_id = r.id
      WHERE t.id = ? LIMIT 1
    ''', [taskId]);
    if (rows.isEmpty) throw StateError('Routine task no longer exists.');
    final planJson = jsonDecode(await vault.decryptText(rows.single['payload']! as String));
    final plan = CoachingPlan.fromJson(Map<String, Object?>.from(planJson as Map));
    final taskIndex = plan.tasks.indexWhere((task) => task.id == taskId);
    if (taskIndex < 0) throw StateError('Task payload is inconsistent with its plan.');
    final updatedTask = transform(plan.tasks[taskIndex]);
    final updatedTasks = [...plan.tasks]..[taskIndex] = updatedTask;
    final updatedPlan = CoachingPlan(
      id: plan.id, createdAt: plan.createdAt, startDate: plan.startDate,
      tasks: updatedTasks, version: plan.version, isProPlan: plan.isProPlan, feedback: plan.feedback,
    );
    final planPayload = await vault.encryptText(jsonEncode(updatedPlan.toJson()));
    final taskPayload = await vault.encryptText(jsonEncode(updatedTask.toJson()));
    final completionPayload = completionState == null || completionState == TaskState.pending
        ? null
        : await vault.encryptText(jsonEncode({
            'taskId': taskId, 'state': enumName(completionState),
            'changedAt': DateTime.now().toUtc().toIso8601String(),
          }));
    await _db.transaction((txn) async {
      await txn.update('coaching_plans', {'payload': planPayload}, where: 'id = ?', whereArgs: [plan.id]);
      await txn.update('routine_tasks', {'payload': taskPayload}, where: 'id = ?', whereArgs: [taskId]);
      if (completionState != null) {
        await txn.delete('task_completions', where: 'task_id = ?', whereArgs: [taskId]);
        if (completionPayload != null) {
          await txn.insert('task_completions', {'id': taskId, 'task_id': taskId, 'payload': completionPayload});
        }
      }
    });
  }

  Future<double> completionRate() async {
    final plan = await getLatestPlan();
    if (plan == null || plan.tasks.isEmpty) return 0;
    return plan.tasks.where((task) => task.state == TaskState.completed).length / plan.tasks.length;
  }

  Future<int> totalTaskCount() async => (await getLatestPlan())?.tasks.length ?? 0;

  Future<int> completedTaskCount() async {
    final plan = await getLatestPlan();
    return plan?.tasks.where((task) => task.state == TaskState.completed).length ?? 0;
  }

  Future<void> addCheckIn(ProgressCheckIn checkIn) async {
    final payload = await vault.encryptText(jsonEncode(checkIn.toJson()));
    await _db.insert('progress_entries', {'id': checkIn.id, 'scan_id': null, 'payload': payload});
  }

  Future<List<ProgressCheckIn>> getCheckIns() async {
    final rows = await _db.query('progress_entries', orderBy: 'rowid DESC');
    final result = <ProgressCheckIn>[];
    for (final row in rows) {
      final decoded = jsonDecode(await vault.decryptText(row['payload']! as String));
      result.add(ProgressCheckIn.fromJson(Map<String, Object?>.from(decoded as Map)));
    }
    return result;
  }

  Future<void> deleteCheckIn(String id) async {
    await _db.delete('progress_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllCheckIns() async {
    await _db.delete('progress_entries');
  }

  Future<void> deleteProgressHistory() async {
    final scanRecords = await getScans();
    await _db.transaction((txn) async {
      await txn.delete('progress_entries');
      await txn.delete('scan_records');
    });
    for (final scan in scanRecords) { await photos.delete(scan.photoFileName); }
  }

  Future<void> saveSubscriptionSnapshot(Map<String, Object?> snapshot) async {
    final payload = await vault.encryptText(jsonEncode(snapshot));
    await _db.insert('subscription_state', {'id': 'entitlement', 'payload': payload}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, Object?>?> readSubscriptionSnapshot() async {
    final rows = await _db.query('subscription_state', where: 'id = ?', whereArgs: ['entitlement'], limit: 1);
    if (rows.isEmpty) return null;
    final decoded = jsonDecode(await vault.decryptText(rows.single['payload']! as String));
    return Map<String, Object?>.from(decoded as Map);
  }

  Future<void> saveSetting(String key, Map<String, Object?> value) async {
    final payload = await vault.encryptText(jsonEncode(value));
    await _db.insert('app_settings', {'id': key, 'payload': payload}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, Object?>?> readSetting(String key) async {
    final rows = await _db.query('app_settings', where: 'id = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    final decoded = jsonDecode(await vault.decryptText(rows.single['payload']! as String));
    return Map<String, Object?>.from(decoded as Map);
  }

  Future<void> deleteAllLocalData() async {
    await _db.transaction((txn) async {
      for (final table in [
        'task_completions', 'routine_tasks', 'routines', 'plan_phases', 'coaching_plans',
        'photo_records', 'scan_measurements', 'scan_records', 'progress_entries',
        'user_preferences', 'subscription_state', 'app_settings',
      ]) { await txn.delete(table); }
    });
    await photos.deleteAll();
    await vault.destroyKeyAfterDataPurge();
    await vault.initialize(encryptedRecordsExist: false);
  }

  Future<void> _removeOrphanPhotoFiles() async {
    final referenced = <String>{};
    for (final scan in await getScans()) { referenced.add(scan.photoFileName); }
    await photos.removeUnreferencedFiles(referenced);
  }

  Future<void> close() => localDatabase.close();
}
