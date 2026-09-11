import 'dart:async';
import 'dart:math';

import 'package:geolocator/geolocator.dart';

import 'location_service.dart';

/// 실제로 걷지 않고 산책 기록 흐름을 확인하기 위한 가짜 GPS.
///
/// **개발용이다.** 이 PC 에서는 에뮬레이터도 iOS 실기기도 쓸 수 없어서
/// "시작 → 거리·시간 누적 → 종료 → 이력 저장 → 코스 묶기"가 실제로
/// 이어지는지 눈으로 볼 방법이 없었다. 그래서 좌표를 만들어 흘려 넣는다.
///
/// 테스트의 `walk_simulator.dart` 와 목적이 다르다. 그쪽은 정해진 좌표
/// 배열을 한 번에 밀어 넣어 결과만 확인하고, 이쪽은 **실시간으로** 한
/// 점씩 내보내 화면이 살아 움직이는 걸 보기 위한 것이다.
///
/// 노이즈를 일부러 섞는다. 깨끗한 좌표만 넣으면 `track_filter` 가 하는 일이
/// 없어서, 실제로 쓰일 때와 다른 그림을 보게 된다.
class SimulatedLocationService extends LocationService {
  SimulatedLocationService({
    this.startLat = 37.5665, // 서울시청
    this.startLng = 126.9780,
    this.stepM = 4,
    this.tick = const Duration(seconds: 1),
    this.turnAfter = 60,
    this.jitterM = 1,
    this.accuracyM = 8,
    this.speedMps = 1.4,
    int seed = 7,
  }) : _rnd = Random(seed);

  final double startLat;
  final double startLng;

  /// 한 번에 나아가는 거리. [tick] 과 묶여 실제 이동 속도를 정한다.
  ///
  /// **여기를 올려 시간을 더 압축할 수는 없다.** `GpsFilter.maxSpeedMps`
  /// (5.5 m/s)를 넘는 좌표는 튄 것으로 보고 통째로 버려져서, 빠르게
  /// 만들수록 거리가 아예 쌓이지 않는다. 실제로 6m/0.5초(12 m/s)로 만들었다가
  /// 거리가 0 에서 움직이지 않는 걸 보고 낮췄다.
  ///
  /// 기본값은 4m/1초 = 4 m/s 다. 사람이 뛰는 속도라 현실적이면서 필터를
  /// 통과한다. 코스로 묶이려면 geohash 셀 4개(약 600m)가 필요하므로
  /// 2~3분쯤 두면 저장할 만한 산책이 된다.
  ///
  /// 필터 임계값을 시뮬레이터 편의로 바꾸면 안 된다 — 실기기 로그로
  /// 보정해야 하는 값이다.
  final double stepM;

  /// 좌표를 내보내는 간격.
  final Duration tick;

  /// 몇 점 뒤에 동쪽으로 꺾을지. L자로 꺾어야 경로가 직선 하나로 보이지 않는다.
  final int turnAfter;

  final double jitterM;
  final double accuracyM;
  final double speedMps;

  final Random _rnd;

  static const double _mPerDegLat = 111320;

  StreamController<Position>? _controller;
  Timer? _timer;
  int _emitted = 0;

  /// 지금 가짜 좌표를 내보내고 있는지. 화면이 경고를 띄우는 데 쓴다.
  bool get isRunning => _timer?.isActive ?? false;

  /// 권한을 묻지 않는다. 가짜 좌표라 GPS 가 꺼져 있어도 상관없고,
  /// 웹에서 위치 권한 팝업이 뜨는 것도 피할 수 있다.
  @override
  Future<LocationReadiness> ensurePermission() async => LocationReadiness.ready;

  @override
  Future<Position?> currentPosition() async => _positionAt(_emitted);

  /// 브로드캐스트여야 한다. 일시정지 후 재개하면 레코더가 구독을 다시 건다.
  @override
  Stream<Position> positionStream() {
    // 이미 돌고 있으면 같은 스트림을 준다. 재개할 때마다 좌표가 처음으로
    // 돌아가면 경로가 출발점으로 순간이동한다.
    final existing = _controller;
    if (existing != null && !existing.isClosed) return existing.stream;

    final controller = StreamController<Position>.broadcast();
    _controller = controller;

    _timer = Timer.periodic(tick, (_) {
      if (controller.isClosed) return;
      controller.add(_positionAt(_emitted));
      _emitted++;
    });

    return controller.stream;
  }

  Position _positionAt(int i) {
    final north = i < turnAfter ? i * stepM : turnAfter * stepM;
    final east = i < turnAfter ? 0.0 : (i - turnAfter) * stepM;

    final mPerDegLng = _mPerDegLat * cos(startLat * pi / 180);
    final jLat = (_rnd.nextDouble() - 0.5) * 2 * jitterM;
    final jLng = (_rnd.nextDouble() - 0.5) * 2 * jitterM;

    return Position(
      latitude: startLat + (north + jLat) / _mPerDegLat,
      longitude: startLng + (east + jLng) / mPerDegLng,
      // 기기 시계를 그대로 쓴다. 레코더가 지점 간 시간차로 이동 시간을
      // 재므로, 지어낸 시각을 넣으면 통계가 어긋난다.
      timestamp: DateTime.now(),
      accuracy: accuracyM,
      altitude: 30,
      altitudeAccuracy: 5,
      heading: i < turnAfter ? 0 : 90,
      headingAccuracy: 5,
      speed: speedMps,
      speedAccuracy: 0.5,
    );
  }

  /// 좌표 내보내기를 멈춘다. 다음에 다시 시작하면 이어서 걷는다.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> dispose() async {
    stop();
    final c = _controller;
    _controller = null;
    if (c != null && !c.isClosed) await c.close();
  }
}
