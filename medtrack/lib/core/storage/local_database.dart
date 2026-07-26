import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Local SQLite store backing the offline-first behaviour described in
/// the architecture doc: dose confirmations and symptom entries are
/// always written here first, then drained into `sync_queue` for the
/// background sync worker to push once connectivity is back.
class LocalDatabase {
  LocalDatabase._(this._db);

  final Database _db;

  static Future<LocalDatabase> open({String fileName = 'medtrack.db'}) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, fileName);
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE dose_schedule_cache (
            id TEXT PRIMARY KEY,
            prescription_id TEXT NOT NULL,
            medication_name TEXT NOT NULL,
            dosage TEXT NOT NULL,
            scheduled_time TEXT NOT NULL,
            is_prn INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE dose_logs (
            id TEXT PRIMARY KEY,
            schedule_id TEXT NOT NULL,
            scheduled_at TEXT NOT NULL,
            actioned_at TEXT,
            status TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE symptom_logs (
            id TEXT PRIMARY KEY,
            patient_id TEXT NOT NULL,
            recorded_at TEXT NOT NULL,
            pain_score INTEGER,
            custom_fields TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_queue (
            id TEXT PRIMARY KEY,
            entity_type TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
    return LocalDatabase._(db);
  }

  Database get raw => _db;

  Future<void> close() => _db.close();
}
