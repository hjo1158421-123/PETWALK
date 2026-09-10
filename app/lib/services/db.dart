import 'package:sqflite/sqflite.dart';

import 'db_platform.dart';

/// 로컬 SQLite. 산책 기록은 항상 여기에 먼저 쓴다.
///
/// 지하도나 신호 약한 골목에서 네트워크가 끊겨도 기록이 살아남아야 해서
/// 서버 동기화는 나중에 별도 단계로 붙인다.
class AppDb {
  static const _fileName = 'petwalk.db';
  static const _version = 1;

  static Database? _db;

  static Future<Database> get instance async => _db ??= await _open();

  static Future<Database> _open() async {
    // 웹에서는 여기서 팩토리가 IndexedDB 구현으로 교체된다.
    await initDatabaseFactory();
    final path = await databasePathFor(_fileName);
    return openDatabase(
      path,
      version: _version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, v) async {
        final batch = db.batch();

        batch.execute('''
          CREATE TABLE walks (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            started_at    INTEGER NOT NULL,
            ended_at      INTEGER,
            distance_m    REAL    NOT NULL DEFAULT 0,
            moving_sec    INTEGER NOT NULL DEFAULT 0,
            total_sec     INTEGER NOT NULL DEFAULT 0,
            elev_gain_m   REAL    NOT NULL DEFAULT 0,
            course_id     INTEGER,
            geohash_sig   TEXT,
            memo          TEXT,
            synced        INTEGER NOT NULL DEFAULT 0
          )
        ''');
        batch.execute(
            'CREATE INDEX idx_walks_started ON walks(started_at DESC)');
        batch.execute('CREATE INDEX idx_walks_course ON walks(course_id)');

        batch.execute('''
          CREATE TABLE track_points (
            id        INTEGER PRIMARY KEY AUTOINCREMENT,
            walk_id   INTEGER NOT NULL,
            ts        INTEGER NOT NULL,
            lat       REAL    NOT NULL,
            lng       REAL    NOT NULL,
            alt       REAL,
            accuracy  REAL,
            speed_mps REAL,
            FOREIGN KEY (walk_id) REFERENCES walks(id) ON DELETE CASCADE
          )
        ''');
        batch.execute(
            'CREATE INDEX idx_points_walk ON track_points(walk_id, ts)');

        batch.execute('''
          CREATE TABLE courses (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            name            TEXT    NOT NULL,
            geohash_sig     TEXT    NOT NULL,
            distance_m      REAL    NOT NULL,
            walk_count      INTEGER NOT NULL DEFAULT 0,
            first_walked_at INTEGER,
            last_walked_at  INTEGER
          )
        ''');

        // 후보 코스를 빠르게 좁히기 위한 역색인.
        // 겹치는 셀이 하나도 없는 코스는 유사도 계산조차 하지 않는다.
        batch.execute('''
          CREATE TABLE course_cells (
            course_id INTEGER NOT NULL,
            cell      TEXT    NOT NULL,
            PRIMARY KEY (course_id, cell),
            FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE CASCADE
          )
        ''');
        batch.execute('CREATE INDEX idx_course_cells ON course_cells(cell)');

        await batch.commit(noResult: true);
      },
    );
  }
}
