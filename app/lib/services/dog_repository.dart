import 'package:sqflite/sqflite.dart';

import '../models/dog.dart';
import 'db.dart';

class DogRepository {
  Future<Database> get _db async => AppDb.instance;

  Future<List<Dog>> listDogs({bool includeInactive = false}) async {
    final db = await _db;
    final rows = await db.query(
      'dogs',
      where: includeInactive ? null : 'is_active = 1',
      orderBy: 'created_at ASC',
    );
    return rows.map(Dog.fromMap).toList();
  }

  Future<Dog?> findDog(int id) async {
    final db = await _db;
    final rows = await db.query('dogs', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Dog.fromMap(rows.first);
  }

  Future<int> insertDog(Dog dog) async {
    final db = await _db;
    return db.insert('dogs', dog.toMap());
  }

  Future<void> updateDog(Dog dog) async {
    final db = await _db;
    await db.update('dogs', dog.toMap(), where: 'id = ?', whereArgs: [dog.id]);
  }

  /// 프로필을 지워도 지난 산책 기록은 남겨 둔다.
  /// 실제로 걸었던 사실까지 사라지면 통계가 어긋난다.
  Future<void> deactivateDog(int id) async {
    final db = await _db;
    await db.update('dogs', {'is_active': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  /// 기록까지 전부 지운다. 되돌릴 수 없다.
  Future<void> deleteDogPermanently(int id) async {
    final db = await _db;
    await db.delete('dogs', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------- 산책과의 연결

  Future<void> linkWalk(int walkId, List<int> dogIds) async {
    if (dogIds.isEmpty) return;
    final db = await _db;
    final batch = db.batch();
    for (final dogId in dogIds) {
      batch.insert(
        'walk_dogs',
        {'walk_id': walkId, 'dog_id': dogId},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Dog>> dogsForWalk(int walkId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT d.* FROM dogs d
      JOIN walk_dogs wd ON wd.dog_id = d.id
      WHERE wd.walk_id = ?
      ORDER BY d.created_at ASC
    ''', [walkId]);
    return rows.map(Dog.fromMap).toList();
  }

  /// 여러 산책의 동반 반려견을 한 번에 가져온다.
  /// 목록 화면에서 산책마다 쿼리를 날리면 N+1 이 된다.
  Future<Map<int, List<Dog>>> dogsForWalks(List<int> walkIds) async {
    if (walkIds.isEmpty) return {};
    final db = await _db;
    final placeholders = List.filled(walkIds.length, '?').join(',');
    final rows = await db.rawQuery('''
      SELECT wd.walk_id AS wid, d.* FROM dogs d
      JOIN walk_dogs wd ON wd.dog_id = d.id
      WHERE wd.walk_id IN ($placeholders)
      ORDER BY d.created_at ASC
    ''', walkIds);

    final result = <int, List<Dog>>{};
    for (final row in rows) {
      final wid = row['wid'] as int;
      (result[wid] ??= []).add(Dog.fromMap(row));
    }
    return result;
  }

  /// 이 반려견과 함께한 산책의 총 거리와 횟수.
  Future<({int count, double distanceM, int totalSec})> statsFor(
    int dogId, {
    DateTime? since,
  }) async {
    final db = await _db;
    final args = <Object?>[dogId];
    var where = 'wd.dog_id = ? AND w.ended_at IS NOT NULL';
    if (since != null) {
      where += ' AND w.started_at >= ?';
      args.add(since.millisecondsSinceEpoch);
    }

    final rows = await db.rawQuery('''
      SELECT COUNT(*) AS c,
             COALESCE(SUM(w.distance_m), 0) AS d,
             COALESCE(SUM(w.total_sec), 0)  AS t
      FROM walks w
      JOIN walk_dogs wd ON wd.walk_id = w.id
      WHERE $where
    ''', args);

    final row = rows.first;
    return (
      count: (row['c'] as int?) ?? 0,
      distanceM: ((row['d'] as num?) ?? 0).toDouble(),
      totalSec: (row['t'] as int?) ?? 0,
    );
  }
}
