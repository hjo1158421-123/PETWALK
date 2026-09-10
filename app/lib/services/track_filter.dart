import 'geo.dart';

/// 원시 GPS 픽스.
class RawFix {
  final double lat;
  final double lng;
  final double accuracy;
  final double? alt;
  final DateTime ts;

  /// GPS 칩이 직접 준 속도 (m/s). 대부분의 기기에서 도플러로 계산되어
  /// 좌표 차이로 구한 속도보다 정지 판정에 훨씬 정확하다. 없으면 null.
  final double? deviceSpeedMps;

  const RawFix({
    required this.lat,
    required this.lng,
    required this.accuracy,
    required this.ts,
    this.alt,
    this.deviceSpeedMps,
  });
}

/// 필터를 통과한 픽스와 그 시점의 증분값.
class FilteredFix {
  final double lat;
  final double lng;
  final double accuracy;
  final double? alt;
  final DateTime ts;

  /// 직전 채택 지점으로부터의 이동 거리 (m). 정지로 판정되면 0.
  final double deltaM;

  /// 직전 채택 지점 대비 순간 속도 (m/s)
  final double speedMps;

  /// 누적 상승고도 증분 (m)
  final double deltaElevM;

  /// 정지가 아닌 실제 이동 상태인지
  final bool moving;

  const FilteredFix({
    required this.lat,
    required this.lng,
    required this.accuracy,
    required this.ts,
    required this.deltaM,
    required this.speedMps,
    required this.deltaElevM,
    required this.moving,
    this.alt,
  });
}

/// GPS 노이즈 제거기.
///
/// 이 단계를 건너뛰면 거리가 실제보다 20~30% 부풀려진다. 특히 신호가 약한
/// 골목이나 건물 사이에서는 가만히 서 있어도 좌표가 계속 흔들려서
/// 분당 100m씩 유령 거리가 쌓인다.
///
/// 5단계로 거른다:
///  1. 정확도가 나쁜 픽스 버리기
///  2. 측위가 안정되기 전 초반 픽스 버리기
///  3. 칼만 필터로 좌표 평활화
///  4. 사람이 낼 수 없는 속도로 튄 픽스 버리기
///  5. 정지 판정 - 측정 오차보다 작은 움직임은 거리로 세지 않기
class GpsFilter {
  /// 이보다 정확도가 나쁜 픽스는 채택하지 않는다 (m)
  static const double maxAccuracyM = 30;

  /// 강아지 산책에서 나올 수 있는 최대 속도 (m/s). 약 20km/h.
  /// 이보다 빠르면 측위가 튄 것으로 본다.
  static const double maxSpeedMps = 5.5;

  /// 이 속도 미만은 정지로 본다 (m/s)
  static const double stopSpeedMps = 0.35;

  /// 노이즈 게이트 계수.
  ///
  /// 정확도가 ±8m인 상태에서 3m 움직인 것처럼 보이는 값은 실제 이동인지
  /// 측정 오차인지 구분할 방법이 없다. 그래서 정확도에 이 계수를 곱한
  /// 값보다 작은 변위는 거리로 세지 않는다. 정지 중 드리프트 누적을
  /// 막는 가장 효과적인 방어선이다.
  static const double noiseGateFactor = 0.5;

  /// 노이즈 게이트 상한 (m). 정확도가 나쁠 때 게이트가 무한정 커지면
  /// 실제 보행까지 잘라 버린다. distanceFilter가 5m라 그보다 작게 잡는다.
  static const double maxNoiseGateM = 4.0;

  /// 측위 안정화 전 버릴 픽스 수
  static const int warmupSkip = 3;

  /// 고도 노이즈 임계값 (m). GPS 고도는 ±10m씩 흔들려서 크게 잡아야 한다.
  static const double elevThresholdM = 3.0;

  final _kalman = _KalmanLatLng(processNoiseMps: 3.0);
  int _seen = 0;
  double? _lastLat, _lastLng, _lastElevAnchor;
  DateTime? _lastTs;

  /// 일시정지 후 재개할 때 호출. 끊긴 구간이 직선으로 이어지는 걸 막는다.
  void breakSegment() {
    _lastLat = null;
    _lastLng = null;
    _lastTs = null;
  }

  /// 픽스를 하나 넣는다. 버려지면 null.
  FilteredFix? add(RawFix fix) {
    if (fix.accuracy <= 0 || fix.accuracy > maxAccuracyM) return null;

    _kalman.process(fix.lat, fix.lng, fix.accuracy, fix.ts);
    _seen++;
    if (_seen <= warmupSkip) return null;

    final lat = _kalman.lat!;
    final lng = _kalman.lng!;

    if (_lastLat == null || _lastTs == null) {
      _lastLat = lat;
      _lastLng = lng;
      _lastTs = fix.ts;
      _lastElevAnchor ??= fix.alt;
      return FilteredFix(
        lat: lat,
        lng: lng,
        accuracy: fix.accuracy,
        alt: fix.alt,
        ts: fix.ts,
        deltaM: 0,
        speedMps: 0,
        deltaElevM: 0,
        moving: false,
      );
    }

    final dtSec = fix.ts.difference(_lastTs!).inMilliseconds / 1000.0;
    if (dtSec <= 0) return null;

    final d = haversineM(_lastLat!, _lastLng!, lat, lng);
    final v = d / dtSec;
    if (v > maxSpeedMps) return null; // 튄 좌표

    final moving = _isMoving(fix, d, v);

    var deltaElev = 0.0;
    if (fix.alt != null) {
      if (_lastElevAnchor == null) {
        _lastElevAnchor = fix.alt;
      } else {
        final diff = fix.alt! - _lastElevAnchor!;
        // 임계값을 넘을 때만 앵커를 옮겨서 노이즈가 누적되지 않게 한다.
        if (diff.abs() >= elevThresholdM) {
          if (diff > 0) deltaElev = diff;
          _lastElevAnchor = fix.alt;
        }
      }
    }

    // 정지로 판정해도 좌표는 갱신한다. 그래야 다음 변위가 누적 오차가
    // 아니라 직전 위치 기준으로 계산된다.
    _lastLat = lat;
    _lastLng = lng;
    _lastTs = fix.ts;

    return FilteredFix(
      lat: lat,
      lng: lng,
      accuracy: fix.accuracy,
      alt: fix.alt,
      ts: fix.ts,
      deltaM: moving ? d : 0,
      speedMps: v,
      deltaElevM: moving ? deltaElev : 0,
      moving: moving,
    );
  }

  bool _isMoving(RawFix fix, double d, double v) {
    final chip = fix.deviceSpeedMps;

    // 도플러 속도가 이동을 확인해 주면 그것만으로 충분하다.
    // 좌표 차이와 달리 위치 오차의 영향을 받지 않는다.
    if (chip != null && chip >= stopSpeedMps) return true;

    // 칩 속도가 0으로 오는 경우는 "정말 멈춤"과 "속도 미지원"이 구분되지
    // 않는다. 그래서 변위로 한 번 더 확인한다.
    final gate = (fix.accuracy * noiseGateFactor).clamp(0.0, maxNoiseGateM);
    if (d < gate) return false;

    return v >= stopSpeedMps;
  }
}

/// 위경도용 1차원 칼만 필터.
///
/// 상태는 위치뿐이고 속도는 모델링하지 않는다. 도보 속도에서는 이 정도로
/// 충분하고, 이동평균과 달리 정확도(accuracy)를 신뢰도로 반영해서
/// 신호가 좋을 땐 즉시 따라가고 나쁠 땐 천천히 따라간다.
class _KalmanLatLng {
  /// 프로세스 노이즈 (m/s). 도보는 3.0 정도가 무난하다.
  final double processNoiseMps;

  double? lat, lng;
  double _variance = -1; // m^2
  DateTime? _ts;

  _KalmanLatLng({required this.processNoiseMps});

  void process(double newLat, double newLng, double accuracy, DateTime ts) {
    final acc = accuracy < 1 ? 1.0 : accuracy;

    if (_variance < 0) {
      lat = newLat;
      lng = newLng;
      _variance = acc * acc;
      _ts = ts;
      return;
    }

    final dtSec = ts.difference(_ts!).inMilliseconds / 1000.0;
    if (dtSec > 0) {
      // 시간이 흐른 만큼 위치 불확실성이 커진다
      _variance += dtSec * processNoiseMps * processNoiseMps;
      _ts = ts;
    }

    final k = _variance / (_variance + acc * acc);
    lat = lat! + k * (newLat - lat!);
    lng = lng! + k * (newLng - lng!);
    _variance = (1 - k) * _variance;
  }
}
