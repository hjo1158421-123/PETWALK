import 'package:sqflite/sqflite.dart';

import '../models/course.dart';
import '../models/track_point.dart';
import '../models/walk.dart';
import 'course_matcher.dart';
import 'db.dart';
import 'geo.dart';
import 'track_filter.dart';

class WalkRepository {
  Future<Database> get _db async => AppDb.instance;

  // ---------------------------------------------------------------- 산책

  Future<int> createWalk(DateTime startedAt) async {
    final db = await _db;
    return db.insert('walks', Walk(startedAt: startedAt).toMap());
  }

  /// 기록 중 버퍼링된 지점들을 한 번에 flush 한다.
  /// 지점마다 insert 하면 IO가 과해서 배터리를 잡아먹는다.
  Future<void> appendPoints(List<TrackPoint> points) async {
    if (points.isEmpty) return;
    final db = await _db;
    final batch = db.batch();
    for (final pt in points) {
      batch.insert('track_points', pt.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateWalk(Walk walk) async {
    final db = await _db;
    await db.update('walks', walk.toMap(),
        where: 'id = ?', whereArgs: [walk.id]);
  }

  Future<List<Walk>> listWalks({int limit = 100, int offset = 0}) async {
    final db = await _db;
    final rows = await db.query('walks',
        where: 'ended_at IS NOT NULL',
        orderBy: 'started_at DESC',
        limit: limit,
        offset: offset);
    return rows.map(Walk.fromMap).toList();
  }

  Future<Walk?> findWalk(int id) async {
    final db = await _db;
    final rows = await db.query('walks', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Walk.fromMap(rows.first);
  }

  Future<List<TrackPoint>> pointsFor(int walkId) async {
    final db = await _db;
    final rows = await db.query('track_points',
        where: 'walk_id = ?', whereArgs: [walkId], orderBy: 'ts ASC');
    return rows.map(TrackPoint.fromMap).toList();
  }

  Future<void> deleteWalk(int id) async {
    final db = await _db;
    final walk = await findWalk(id);
    await db.delete('walks', where: 'id = ?', whereArgs: [id]);

    // 코스에 딸린 마지막 산책이 지워지면 코스도 정리한다.
    if (walk?.courseId != null) {
      final remaining = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM walks WHERE course_id = ?', [walk!.courseId]));
      if (remaining == null || remaining == 0) {
        await db.delete('courses', where: 'id = ?', whereArgs: [walk.courseId]);
      } else {
        await db.rawUpdate(
            'UPDATE courses SET walk_count = ? WHERE id = ?',
            [remaining, walk.courseId]);
      }
    }
  }

  /// 종료되지 않은 채 남은 기록을 복구한다. 앱이 강제 종료되면 생긴다.
  ///
  /// 기록 중 통계(거리·이동시간)는 메모리에만 있다가 종료 시점에 한 번
  /// 저장되므로, 앱이 죽으면 통계는 날아가고 지점만 남는다. 지점은 이미
  /// 필터를 통과한 값이라 그것만으로 통계를 다시 계산할 수 있다.
  /// 사용자가 실제로 걸은 기록을 지우는 것보다 복원하는 편이 낫다.
  ///
  /// 고도는 복원하지 않는다. 원본 고도가 노이즈 그대로라 다시 계산하면
  /// 오히려 부정확한 값이 나온다.
  Future<int> recoverUnfinished() async {
    final db = await _db;
    final rows = await db.query('walks', where: 'ended_at IS NULL');
    var recovered = 0;

    for (final row in rows) {
      final walk = Walk.fromMap(row);
      final points = await pointsFor(walk.id!);

      final stats = _recompute(walk, points);
      if (stats == null) {
        await deleteWalk(walk.id!);
        continue;
      }

      await updateWalk(stats);
      final courseId = await attachToCourse(stats);
      if (courseId != null) {
        await updateWalk(stats.copyWith(courseId: courseId));
      }
      recovered++;
    }

    return recovered;
  }

  /// 저장된 지점으로 산책 통계를 다시 계산한다.
  /// 남길 가치가 없을 만큼 짧으면 null.
  Walk? _recompute(Walk walk, List<TrackPoint> points) {
    if (points.length < 10) return null;

    var distanceM = 0.0;
    var movingMs = 0;
    final cells = <String>{};

    for (var i = 0; i < points.length; i++) {
      final cur = points[i];
      cells.add(geohashEncode(cur.lat, cur.lng));
      if (i == 0) continue;

      final prev = points[i - 1];
      final dtMs = cur.ts.difference(prev.ts).inMilliseconds;

      // 30초 넘게 끊긴 구간은 잇지 않는다. 일시정지든 신호 두절이든,
      // 지나지 않은 길을 직선으로 그어 거리를 부풀리면 안 된다.
      if (dtMs <= 0 || dtMs > 30000) continue;
      if (cur.speedMps < GpsFilter.stopSpeedMps) continue;

      distanceM += haversineM(prev.lat, prev.lng, cur.lat, cur.lng);
      movingMs += dtMs;
    }

    if (distanceM < 30) return null;

    final endedAt = points.last.ts;
    return walk.copyWith(
      endedAt: endedAt,
      distanceM: distanceM,
      movingSec: movingMs ~/ 1000,
      totalSec: endedAt.difference(walk.startedAt).inSeconds,
      geohashSig: (cells.toList()..sort()).join(','),
    );
  }

  // ---------------------------------------------------------------- 코스

  Future<List<Course>> listCourses() async {
    final db = await _db;
    final rows =
        await db.query('courses', orderBy: 'walk_count DESC, last_walked_at DESC');
    return rows.map(Course.fromMap).toList();
  }

  Future<Course?> findCourse(int id) async {
    final db = await _db;
    final rows = await db.query('courses', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Course.fromMap(rows.first);
  }

  Future<List<Walk>> walksOfCourse(int courseId) async {
    final db = await _db;
    final rows = await db.query('walks',
        where: 'course_id = ? AND ended_at IS NOT NULL',
        whereArgs: [courseId],
        orderBy: 'started_at DESC');
    return rows.map(Walk.fromMap).toList();
  }

  /// 방금 끝난 산책을 기존 코스에 붙이거나, 없으면 새 코스를 만든다.
  /// 반환값은 연결된 course id (매칭을 시도하지 않았으면 null).
  Future<int?> attachToCourse(Walk walk) async {
    final cells = walk.cells;
    if (cells.length < CourseMatcher.minCells) return null;

    final db = await _db;
    final match = await _bestMatch(db, cells, walk.distanceM);

    if (match != null) {
      final now = walk.endedAt ?? DateTime.now();
      final newCount = match.walkCount + 1;

      // 거리는 누적 평균으로 갱신 — 매번 GPS 오차가 다르니 평균이 안정적이다.
      final newDistance =
          (match.distanceM * match.walkCount + walk.distanceM) / newCount;

      await db.update(
        'courses',
        {
          'walk_count': newCount,
          'distance_m': newDistance,
          'last_walked_at': now.millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [match.id],
      );

      // 이번에 새로 지난 셀을 코스에 흡수시킨다. 같은 길이라도 매번
      // 정확히 같은 셀을 밟지는 않으므로 코스가 조금씩 완성되어 간다.
      final batch = db.batch();
      for (final cell in cells) {
        batch.insert('course_cells', {'course_id': match.id, 'cell': cell},
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);

      // 흡수한 셀을 시그니처에도 반영한다. 이걸 빼먹으면 코스의 셀 집합이
      // 첫 산책 상태로 굳어서 매칭이 갈수록 부정확해진다.
      await _refreshSignature(db, match.id!);

      return match.id;
    }

    return _createCourse(db, walk, cells);
  }

  Future<void> _refreshSignature(Database db, int courseId) async {
    final rows = await db.query('course_cells',
        columns: ['cell'], where: 'course_id = ?', whereArgs: [courseId]);
    final cells = rows.map((r) => r['cell'] as String).toList()..sort();
    await db.update('courses', {'geohash_sig': cells.join(',')},
        where: 'id = ?', whereArgs: [courseId]);
  }

  Future<Course?> _bestMatch(
      Database db, Set<String> cells, double distanceM) async {
    // 겹치는 셀이 하나라도 있는 코스만 후보로 가져온다.
    final placeholders = List.filled(cells.length, '?').join(',');
    final rows = await db.rawQuery('''
      SELECT c.* FROM courses c
      WHERE c.id IN (
        SELECT DISTINCT course_id FROM course_cells WHERE cell IN ($placeholders)
      )
    ''', cells.toList());

    Course? best;
    var bestSim = 0.0;

    for (final row in rows) {
      final course = Course.fromMap(row);
      if (!CourseMatcher.distanceCompatible(distanceM, course.distanceM)) {
        continue;
      }
      final sim = CourseMatcher.jaccard(cells, course.cells);
      if (sim > bestSim) {
        bestSim = sim;
        best = course;
      }
    }

    return bestSim >= CourseMatcher.threshold ? best : null;
  }

  Future<int> _createCourse(
      Database db, Walk walk, Set<String> cells) async {
    final seq = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM courses')) ??
        0;
    final now = walk.endedAt ?? DateTime.now();

    final courseId = await db.insert('courses', {
      'name': '코스 ${seq + 1}',
      'geohash_sig': (cells.toList()..sort()).join(','),
      'distance_m': walk.distanceM,
      'walk_count': 1,
      'first_walked_at': now.millisecondsSinceEpoch,
      'last_walked_at': now.millisecondsSinceEpoch,
    });

    final batch = db.batch();
    for (final cell in cells) {
      batch.insert('course_cells', {'course_id': courseId, 'cell': cell});
    }
    await batch.commit(noResult: true);

    return courseId;
  }

  Future<void> renameCourse(int courseId, String name) async {
    final db = await _db;
    await db.update('courses', {'name': name},
        where: 'id = ?', whereArgs: [courseId]);
  }
}
