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
      version: 1,
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
      },
    );
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
