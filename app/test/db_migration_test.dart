import 'package:flutter_test/flutter_test.dart';
import 'package:petwalk/models/dog.dart';
import 'package:petwalk/services/db.dart';
import 'package:petwalk/services/dog_repository.dart';
import 'package:petwalk/services/walk_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// v1 스키마 그대로. 이미 배포된 기기에 들어 있는 모양이다.
const _v1Schema = [
  '''
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
  )''',
  '''
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
  )''',
  '''
  CREATE TABLE courses (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    name            TEXT    NOT NULL,
    geohash_sig     TEXT    NOT NULL,
    distance_m      REAL    NOT NULL,
    walk_count      INTEGER NOT NULL DEFAULT 0,
    first_walked_at INTEGER,
    last_walked_at  INTEGER
  )''',
  '''
  CREATE TABLE course_cells (
    course_id INTEGER NOT NULL,
    cell      TEXT    NOT NULL,
    PRIMARY KEY (course_id, cell),
    FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE CASCADE
  )''',
];

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async => AppDb.resetForTesting());

  test('v1 기기의 산책 기록이 v2 로 올려도 남아 있다', () async {
    final path = '${await databaseFactory.getDatabasesPath()}/migrate_test.db';
    await databaseFactory.deleteDatabase(path);

    // --- v1 상태의 DB 를 만들고 기록을 하나 넣는다 ---
    final v1 = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          for (final sql in _v1Schema) {
            await db.execute(sql);
          }
        },
      ),
    );
    await v1.insert('walks', {
      'started_at': DateTime(2026, 9, 1, 8).millisecondsSinceEpoch,
      'ended_at': DateTime(2026, 9, 1, 9).millisecondsSinceEpoch,
      'distance_m': 2400.0,
      'moving_sec': 3000,
      'total_sec': 3600,
    });
    await v1.close();

    // --- 앱을 새 버전으로 올린 상황 ---
    await AppDb.resetForTesting();
    AppDb.pathOverride = path;

    final walks = await WalkRepository().listWalks();
    expect(walks, hasLength(1), reason: '기존 기록이 살아 있어야 한다');
    expect(walks.single.distanceM, 2400.0);

    // 새 테이블도 쓸 수 있어야 한다
    final dogRepo = DogRepository();
    final id = await dogRepo.insertDog(Dog.fromBreed('콩이', '말티즈'));
    await dogRepo.linkWalk(walks.single.id!, [id]);

    expect(await dogRepo.dogsForWalk(walks.single.id!), hasLength(1));

    await AppDb.resetForTesting();
    await databaseFactory.deleteDatabase(path);
  });
}
