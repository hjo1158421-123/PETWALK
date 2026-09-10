/// 산책 1회 기록.
class Walk {
  final int? id;
  final DateTime startedAt;
  final DateTime? endedAt;

  /// 정지 구간을 제외하고 누적한 이동 거리 (m)
  final double distanceM;

  /// 실제로 움직인 시간 (초)
  final int movingSec;

  /// 시작~종료 전체 경과 시간, 일시정지 제외 (초)
  final int totalSec;

  /// GPS 고도 기반 누적 상승고도 (m). 기압계가 없으면 오차가 크다.
  final double elevGainM;

  /// 같은 코스로 묶인 course 행의 id
  final int? courseId;

  /// 코스 매칭용 geohash 셀 시그니처 (정렬 후 콤마 결합)
  final String? geohashSig;

  final String? memo;

  const Walk({
    this.id,
    required this.startedAt,
    this.endedAt,
    this.distanceM = 0,
    this.movingSec = 0,
    this.totalSec = 0,
    this.elevGainM = 0,
    this.courseId,
    this.geohashSig,
    this.memo,
  });

  double get avgSpeedMps => movingSec > 0 ? distanceM / movingSec : 0;

  /// 전체 시간 중 멈춰 있던 비율.
  /// 강아지가 냄새를 맡느라 자주 멈춘 산책일수록 높다 — 만족도 신호로 쓸 값.
  double get sniffRatio =>
      totalSec > 0 ? (totalSec - movingSec) / totalSec : 0;

  Set<String> get cells =>
      (geohashSig == null || geohashSig!.isEmpty)
          ? const {}
          : geohashSig!.split(',').toSet();

  Walk copyWith({
    int? id,
    DateTime? endedAt,
    double? distanceM,
    int? movingSec,
    int? totalSec,
    double? elevGainM,
    int? courseId,
    String? geohashSig,
    String? memo,
  }) =>
      Walk(
        id: id ?? this.id,
        startedAt: startedAt,
        endedAt: endedAt ?? this.endedAt,
        distanceM: distanceM ?? this.distanceM,
        movingSec: movingSec ?? this.movingSec,
        totalSec: totalSec ?? this.totalSec,
        elevGainM: elevGainM ?? this.elevGainM,
        courseId: courseId ?? this.courseId,
        geohashSig: geohashSig ?? this.geohashSig,
        memo: memo ?? this.memo,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'started_at': startedAt.millisecondsSinceEpoch,
        'ended_at': endedAt?.millisecondsSinceEpoch,
        'distance_m': distanceM,
        'moving_sec': movingSec,
        'total_sec': totalSec,
        'elev_gain_m': elevGainM,
        'course_id': courseId,
        'geohash_sig': geohashSig,
        'memo': memo,
      };

  factory Walk.fromMap(Map<String, Object?> m) => Walk(
        id: m['id'] as int?,
        startedAt: DateTime.fromMillisecondsSinceEpoch(m['started_at'] as int),
        endedAt: m['ended_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['ended_at'] as int),
        distanceM: (m['distance_m'] as num?)?.toDouble() ?? 0,
        movingSec: (m['moving_sec'] as int?) ?? 0,
        totalSec: (m['total_sec'] as int?) ?? 0,
        elevGainM: (m['elev_gain_m'] as num?)?.toDouble() ?? 0,
        courseId: m['course_id'] as int?,
        geohashSig: m['geohash_sig'] as String?,
        memo: m['memo'] as String?,
      );
}
