import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Local SQLite store backing offline-first behavior (docs/architecture.md §10):
/// today's schedule is cached ahead of time, and dose/symptom actions are
/// written here first, then drained to the API by a sync queue.
class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'medtrack.db');
    return openDatabase(
      path,
      version: 3,
      // Existing installs already carry a v1 database, so the reminders table
      // has to arrive through an upgrade as well as through a fresh create —
      // otherwise anyone who had the app before this feature would hit
      // "no such table" instead of an empty list.
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createReminders(db);
        if (oldVersion < 3) await _addPrescriptionColumns(db);
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cached_schedule (
            schedule_id TEXT PRIMARY KEY,
            medication_name TEXT NOT NULL,
            dosage TEXT NOT NULL,
            scheduled_time TEXT NOT NULL,
            is_prn INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_queue (
            id TEXT PRIMARY KEY,
            entity_type TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await _createReminders(db);
      },
    );
  }

  /// Medication reminders — local alarms, see MedicationReminder for why they
  /// do not live in Supabase.
  ///
  /// `source` says who put the row here: 'self' for one the patient typed,
  /// 'prescription' for one mirrored from a doctor's dose schedule.
  /// `schedule_ids` are the dose_schedules rows a prescription reminder stands
  /// for — comma separated, because several medications can share one time and
  /// answering "กินแล้ว" at that time answers for all of them.
  static Future<void> _createReminders(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS medication_reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT NOT NULL,
        hour INTEGER NOT NULL,
        minute INTEGER NOT NULL,
        days TEXT NOT NULL DEFAULT '',
        enabled INTEGER NOT NULL DEFAULT 1,
        source TEXT NOT NULL DEFAULT 'self',
        schedule_ids TEXT NOT NULL DEFAULT ''
      )
    ''');
  }

  /// Adds the two columns above to a reminders table created by v2.
  ///
  /// Guarded per column rather than wrapped in one try: a half-applied upgrade
  /// would otherwise leave the second column missing for good, since the
  /// version is bumped either way.
  static Future<void> _addPrescriptionColumns(Database db) async {
    // The table may not exist yet on a v1 database, where _createReminders
    // above has just built it with both columns already in place.
    await _createReminders(db);
    final columns = await db.rawQuery('PRAGMA table_info(medication_reminders)');
    final names = columns.map((row) => row['name'] as String?).toSet();
    if (!names.contains('source')) {
      await db.execute(
        "ALTER TABLE medication_reminders ADD COLUMN source TEXT NOT NULL DEFAULT 'self'",
      );
    }
    if (!names.contains('schedule_ids')) {
      await db.execute(
        "ALTER TABLE medication_reminders ADD COLUMN schedule_ids TEXT NOT NULL DEFAULT ''",
      );
    }
  }

  Future<void> enqueue(String id, String entityType, String jsonPayload) async {
    final db = await database;
    await db.insert(
      'sync_queue',
      {
        'id': id,
        'entity_type': entityType,
        'payload': jsonPayload,
        'created_at': DateTime.now().toIso8601String(),
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> pendingSyncItems() async {
    final db = await database;
    return db.query('sync_queue', where: 'synced = 0', orderBy: 'created_at ASC');
  }

  Future<void> markSynced(String id) async {
    final db = await database;
    await db.update('sync_queue', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }
}
