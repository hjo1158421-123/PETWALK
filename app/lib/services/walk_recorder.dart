import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/track_point.dart';
import '../models/walk.dart';
import 'geo.dart';
import 'location_service.dart';
import 'track_filter.dart';
import 'walk_repository.dart';

enum RecorderState { idle, starting, recording, paused, saving }

/// 산책 기록의 상태 기계. 화면은 여기만 바라본다.
class WalkRecorder extends ChangeNotifier {
  WalkRecorder({
    LocationService? location,
    WalkRepository? repository,
  })  : _location = location ?? LocationService(),
        _repo = repository ?? WalkRepository();

  final LocationService _location;
  final WalkRepository _repo;

  /// 지점 몇 개마다 DB에 flush 할지. 매 지점 insert 하면 IO가 과하다.
  static const int _flushEvery = 10;

  var _state = RecorderState.idle;
  RecorderState get state => _state;
  bool get isActive =>
      _state == RecorderState.recording || _state == RecorderState.paused;

  int? _walkId;
  DateTime? _startedAt;

  GpsFilter _filter = GpsFilter();
  StreamSubscription<Position>? _sub;
  Timer? _ticker;

  /// 일시정지로 끊긴 구간을 따로 담는다. 끊긴 자리를 직선으로 잇지 않으려면
  /// 폴리라인도 세그먼트별로 그려야 한다.
  final List<List<TrackPoint>> _segments = [];
  List<List<TrackPoint>> get segments => List.unmodifiable(_segments);

  final List<TrackPoint> _pending = [];
  final Set<String> _cells = {};

  double _distanceM = 0;
  double _elevGainM = 0;
  int _movingMs = 0;
  int _elapsedSec = 0;
  DateTime? _lastFixTs;
  double _currentSpeedMps = 0;
  double? _lastAccuracy;

  double get distanceM => _distanceM;
  double get elevGainM => _elevGainM;
  int get elapsedSec => _elapsedSec;
  int get movingSec => _movingMs ~/ 1000;
  double get currentSpeedMps => _currentSpeedMps;
  double? get lastAccuracy => _lastAccuracy;

  /// 이동 시간 기준 평균 속도 (m/s)
  double get avgSpeedMps => movingSec > 0 ? _distanceM / movingSec : 0;

  TrackPoint? get lastPoint {
    for (final seg in _segments.reversed) {
      if (seg.isNotEmpty) return seg.last;
    }
    return null;
  }

  String? _error;
  String? get error => _error;

  // ------------------------------------------------------------- 시작/종료

  /// 기록을 시작한다. 권한 문제가 있으면 [LocationReadiness]를 돌려주고
  /// 상태는 idle로 되돌린다.
  Future<LocationReadiness> start() async {
    if (isActive) return LocationReadiness.ready;

    _state = RecorderState.starting;
    _error = null;
    notifyListeners();

    final readiness = await _location.ensurePermission();
    if (readiness != LocationReadiness.ready) {
      _state = RecorderState.idle;
      notifyListeners();
      return readiness;
    }

    _reset();
    _startedAt = DateTime.now();
    _walkId = await _repo.createWalk(_startedAt!);
    _segments.add([]);

    _subscribe();
    _startTicker();

    _state = RecorderState.recording;
    notifyListeners();
    return LocationReadiness.ready;
  }

  void pause() {
    if (_state != RecorderState.recording) return;

    // 스트림을 pause 하면 GPS는 계속 돌면서 이벤트만 쌓인다. 배터리도
    // 낭비되고, 재개할 때 옛날 타임스탬프가 한꺼번에 밀려든다. 끊는다.
    unawaited(_sub?.cancel());
    _sub = null;
    _ticker?.cancel();
    _filter.breakSegment();
    _lastFixTs = null;
    _currentSpeedMps = 0;
    _state = RecorderState.paused;
    notifyListeners();
  }

  void resume() {
    if (_state != RecorderState.paused) return;
    _segments.add([]);
    _subscribe();
    _startTicker();
    _state = RecorderState.recording;
    notifyListeners();
  }

  /// 기록을 끝내고 저장한다. 저장된 [Walk]를 돌려준다.
  /// 이동 거리가 너무 짧으면 기록을 버리고 null을 돌려준다.
  Future<Walk?> stop({double minDistanceM = 30}) async {
    if (!isActive || _walkId == null) return null;

    _state = RecorderState.saving;
    notifyListeners();

    await _sub?.cancel();
    _sub = null;
    _ticker?.cancel();
    _ticker = null;

    await _flush();

    final walkId = _walkId!;

    if (_distanceM < minDistanceM) {
      await _repo.deleteWalk(walkId);
      _reset();
      _state = RecorderState.idle;
      notifyListeners();
      return null;
    }

    final endedAt = DateTime.now();
    var walk = Walk(
      id: walkId,
      startedAt: _startedAt!,
      endedAt: endedAt,
      distanceM: _distanceM,
      movingSec: movingSec,
      totalSec: _elapsedSec,
      elevGainM: _elevGainM,
      geohashSig: (_cells.toList()..sort()).join(','),
    );

    await _repo.updateWalk(walk);

    final courseId = await _repo.attachToCourse(walk);
    if (courseId != null) {
      walk = walk.copyWith(courseId: courseId);
      await _repo.updateWalk(walk);
    }

    _reset();
    _state = RecorderState.idle;
    notifyListeners();
    return walk;
  }

  /// 저장하지 않고 버린다.
  Future<void> discard() async {
    await _sub?.cancel();
    _sub = null;
    _ticker?.cancel();
    _ticker = null;
    if (_walkId != null) await _repo.deleteWalk(_walkId!);
    _reset();
    _state = RecorderState.idle;
    notifyListeners();
  }

  // --------------------------------------------------------------- 내부

  void _subscribe() {
    _sub = _location.positionStream().listen(
      _onPosition,
      onError: (Object e) {
        _error = '위치 수신 오류: $e';
        notifyListeners();
      },
      cancelOnError: false,
    );
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSec++;
      notifyListeners();
    });
  }

  void _onPosition(Position pos) {
    if (_state != RecorderState.recording || _walkId == null) return;

    final fix = _filter.add(RawFix(
      lat: pos.latitude,
      lng: pos.longitude,
      accuracy: pos.accuracy,
      alt: pos.altitude,
      ts: pos.timestamp,
      deviceSpeedMps: pos.speed,
    ));
    if (fix == null) return;

    if (_lastFixTs != null && fix.moving) {
      final dtMs = fix.ts.difference(_lastFixTs!).inMilliseconds;
      if (dtMs > 0) _movingMs += dtMs;
    }
    _lastFixTs = fix.ts;

    _distanceM += fix.deltaM;
    _elevGainM += fix.deltaElevM;
    _currentSpeedMps = fix.moving ? fix.speedMps : 0;
    _lastAccuracy = fix.accuracy;
    _cells.add(geohashEncode(fix.lat, fix.lng));

    final point = TrackPoint(
      walkId: _walkId!,
      ts: fix.ts,
      lat: fix.lat,
      lng: fix.lng,
      alt: fix.alt,
      accuracy: fix.accuracy,
      speedMps: fix.speedMps,
    );

    _segments.last.add(point);
    _pending.add(point);
    if (_pending.length >= _flushEvery) {
      // 화면을 막지 않도록 결과를 기다리지 않는다.
      unawaited(_flush());
    }

    notifyListeners();
  }

  Future<void> _flush() async {
    if (_pending.isEmpty) return;
    final batch = List<TrackPoint>.from(_pending);
    _pending.clear();
    await _repo.appendPoints(batch);
  }

  void _reset() {
    _walkId = null;
    _startedAt = null;
    _filter = GpsFilter();
    _segments.clear();
    _pending.clear();
    _cells.clear();
    _distanceM = 0;
    _elevGainM = 0;
    _movingMs = 0;
    _elapsedSec = 0;
    _lastFixTs = null;
    _currentSpeedMps = 0;
    _lastAccuracy = null;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }
}
