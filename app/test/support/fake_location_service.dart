import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:petwalk/services/location_service.dart';

/// 실제 GPS 대신 원하는 좌표를 흘려 넣는 테스트용 위치 서비스.
///
/// [WalkRecorder] 가 생성자로 위치 서비스를 받도록 되어 있어서
/// 앱 코드를 건드리지 않고 이걸 끼워 넣을 수 있다.
class FakeLocationService extends LocationService {
  FakeLocationService({this.readiness = LocationReadiness.ready});

  final LocationReadiness readiness;

  /// 브로드캐스트여야 한다. 일시정지 후 재개하면 레코더가 구독을 다시 건다.
  final _controller = StreamController<Position>.broadcast();

  @override
  Future<LocationReadiness> ensurePermission() async => readiness;

  @override
  Stream<Position> positionStream() => _controller.stream;

  @override
  Future<Position?> currentPosition() async => null;

  void emit(Position position) => _controller.add(position);

  Future<void> close() => _controller.close();
}
