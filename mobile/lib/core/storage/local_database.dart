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
      version: 2,
      // Existing installs already carry a v1 database, so the reminders table
      // has to arrive through an upgrade as well as through a fresh create —
      // otherwise anyone who had the app before this feature would hit
      // "no such table" instead of an empty list.
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createReminders(db);
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
  static Future<void> _createReminders(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS medication_reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT NOT NULL,
        hour INTEGER NOT NULL,
        minute INTEGER NOT NULL,
        days TEXT NOT NULL DEFAULT '',
        enabled INTEGER NOT NULL DEFAULT 1
      )
    ''');
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
