/// 산책 트랙의 한 지점. 필터를 통과한 좌표만 여기까지 올라온다.
class TrackPoint {
  final int? id;
  final int walkId;
  final DateTime ts;
  final double lat;
  final double lng;
  final double? alt;
  final double? accuracy;

  /// 직전 지점 대비 순간 속도 (m/s)
  final double speedMps;

  const TrackPoint({
    this.id,
    required this.walkId,
    required this.ts,
    required this.lat,
    required this.lng,
    this.alt,
    this.accuracy,
    this.speedMps = 0,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'walk_id': walkId,
        'ts': ts.millisecondsSinceEpoch,
        'lat': lat,
        'lng': lng,
        'alt': alt,
        'accuracy': accuracy,
        'speed_mps': speedMps,
      };

  factory TrackPoint.fromMap(Map<String, Object?> m) => TrackPoint(
        id: m['id'] as int?,
        walkId: m['walk_id'] as int,
        ts: DateTime.fromMillisecondsSinceEpoch(m['ts'] as int),
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        alt: (m['alt'] as num?)?.toDouble(),
        accuracy: (m['accuracy'] as num?)?.toDouble(),
        speedMps: (m['speed_mps'] as num?)?.toDouble() ?? 0,
      );
}
