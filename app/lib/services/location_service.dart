import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart';

enum LocationReadiness {
  ready,

  /// 기기의 위치 서비스 자체가 꺼져 있음
  serviceDisabled,

  /// 사용자가 이번에 거부함 — 다시 물어볼 수 있음
  denied,

  /// 영구 거부 — 설정 앱으로 보내야 함
  deniedForever,
}

/// GPS 스트림과 권한을 감싸는 계층.
///
/// 화면이 꺼진 상태에서도 기록이 이어져야 하므로 플랫폼별로 백그라운드
/// 설정을 다르게 준다. Android는 포그라운드 서비스 알림이 떠 있어야 하고,
/// iOS는 Always 권한과 백그라운드 업데이트 허용이 둘 다 필요하다.
class LocationService {
  /// 이 거리 이상 움직였을 때만 새 픽스를 받는다 (m).
  /// 시간 기반 고정 샘플링보다 배터리에 훨씬 유리하다.
  static const int distanceFilterM = 5;

  Future<LocationReadiness> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationReadiness.serviceDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationReadiness.ready;
      case LocationPermission.deniedForever:
        return LocationReadiness.deniedForever;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationReadiness.denied;
    }
  }

  Future<void> openSettings() => Geolocator.openAppSettings();

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  Future<Position?> currentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (_) {
      return null;
    }
  }

  Stream<Position> positionStream() =>
      Geolocator.getPositionStream(locationSettings: _settings());

  LocationSettings _settings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: distanceFilterM,
        intervalDuration: const Duration(seconds: 2),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: '산책 기록 중',
          notificationText: 'PETWALK가 산책 경로를 기록하고 있어요',
          notificationIcon:
              AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
          enableWakeLock: true,
        ),
      );
    }

    if (Platform.isIOS || Platform.isMacOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: distanceFilterM,
        activityType: ActivityType.fitness,
        // iOS가 알아서 위치 갱신을 멈추면 산책 중간이 통째로 비어버린다.
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: distanceFilterM,
    );
  }
}
