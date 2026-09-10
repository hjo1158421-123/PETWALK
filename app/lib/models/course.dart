/// 여러 번의 산책이 "같은 길"로 묶인 코스.
class Course {
  final int? id;
  final String name;
  final String geohashSig;
  final double distanceM;
  final int walkCount;
  final DateTime? firstWalkedAt;
  final DateTime? lastWalkedAt;

  const Course({
    this.id,
    required this.name,
    required this.geohashSig,
    required this.distanceM,
    this.walkCount = 0,
    this.firstWalkedAt,
    this.lastWalkedAt,
  });

  Set<String> get cells =>
      geohashSig.isEmpty ? const {} : geohashSig.split(',').toSet();

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'geohash_sig': geohashSig,
        'distance_m': distanceM,
        'walk_count': walkCount,
        'first_walked_at': firstWalkedAt?.millisecondsSinceEpoch,
        'last_walked_at': lastWalkedAt?.millisecondsSinceEpoch,
      };

  factory Course.fromMap(Map<String, Object?> m) => Course(
        id: m['id'] as int?,
        name: m['name'] as String? ?? '',
        geohashSig: m['geohash_sig'] as String? ?? '',
        distanceM: (m['distance_m'] as num?)?.toDouble() ?? 0,
        walkCount: (m['walk_count'] as int?) ?? 0,
        firstWalkedAt: m['first_walked_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['first_walked_at'] as int),
        lastWalkedAt: m['last_walked_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['last_walked_at'] as int),
      );
}
