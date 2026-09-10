# PETWALK

반려견 산책 기록 앱. GPS로 산책 경로를 기록하고, 같은 길을 반복해서 걸으면
자동으로 "코스"로 묶어 이력을 보여준다.

산책로 추천 기능은 이 기록 데이터가 쌓인 뒤에 붙인다. 설계는
[docs/추천-설계.md](docs/추천-설계.md) 참고.

## 현재 구현 범위 (v1)

- 산책 시작 / 일시정지 / 종료, 백그라운드 기록
- GPS 노이즈 제거 (칼만 필터 + 정지 판정 + 이상치 제거)
- 지도에 실시간 경로 표시
- 로컬 SQLite 저장 — 네트워크가 끊겨도 기록이 남는다
- 산책 이력 목록 / 상세 통계
- 같은 길을 걸으면 자동으로 코스로 묶기 (geohash 셀 + 포함 계수)

## 현재 상태

Flutter 3.47.3 (Dart 3.13.3) 기준으로 아래까지 확인했다.

- `flutter analyze` — 이슈 0건
- `flutter test` — 12개 전부 통과
- `android/` `ios/` 네이티브 폴더 생성 및 위치 권한 설정 완료

**빌드는 아직 검증하지 못했다.** 이 PC에 Android SDK가 없어서
`flutter build apk` 를 돌리지 못했다. 실기기 동작 확인도 그 다음이다.

## 개발 환경

Flutter는 `C:\flutter` 에 설치되어 있다. 시스템 PATH에는 넣지 않았으므로
아래 중 하나가 필요하다.

```bash
export PATH="/c/flutter/bin:$PATH"
```

영구적으로 쓰려면 Windows 사용자 환경변수 `Path` 에 `C:\flutter\bin` 을
추가하면 된다.

```bash
cd /c/PETWALK/app && export PATH="/c/flutter/bin:$PATH" && flutter test
```

### 실기기에서 돌리려면

Android Studio를 설치해 Android SDK를 갖춘 뒤

```bash
cd /c/PETWALK/app && export PATH="/c/flutter/bin:$PATH" && flutter doctor --android-licenses
```

```bash
cd /c/PETWALK/app && export PATH="/c/flutter/bin:$PATH" && flutter run
```

GPS 기록은 에뮬레이터에서 제대로 검증되지 않는다. 위치가 가짜라 노이즈
필터가 하는 일이 없다. 반드시 실기기로 실제 산책을 해봐야 한다.

## 네이티브 설정 (적용 완료)

아래는 이미 반영되어 있다. `flutter create` 를 다시 돌리면 날아갈 수
있으니 그때는 다시 넣어야 한다.

**android/app/src/main/AndroidManifest.xml**
`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`,
`ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE`,
`FOREGROUND_SERVICE_LOCATION`, `WAKE_LOCK` 권한과
`GeolocatorLocationService` 서비스 등록.

**ios/Runner/Info.plist**
`NSLocationWhenInUseUsageDescription`,
`NSLocationAlwaysAndWhenInUseUsageDescription`,
`UIBackgroundModes: location`.

이걸 빼먹으면 화면이 꺼지는 순간 기록이 끊긴다.
## 구조

```
app/lib/
  models/          Walk, TrackPoint, Course
  services/
    location_service.dart   GPS 스트림 + 권한 + 플랫폼별 백그라운드 설정
    track_filter.dart       GPS 노이즈 제거 (여기가 정확도의 핵심)
    walk_recorder.dart      기록 상태 기계. 화면은 여기만 본다
    walk_repository.dart    SQLite CRUD + 코스 매칭
    course_matcher.dart     같은 길인지 판정하는 규칙
    db.dart, geo.dart       스키마, 거리/geohash 계산
  screens/         산책 / 이력 / 산책 상세 / 코스 상세
  widgets/         RouteMap (지도 SDK 교체 지점), StatTile
```

## 알려진 제약

- **지도**: 지금은 OSM 타일을 쓴다. 국내 서비스로 나가려면 네이버 또는
  카카오 지도 SDK로 교체해야 한다. 국내 지도 데이터 반출 제한 때문에
  구글맵은 도보 경로 품질이 떨어진다. 교체 지점은 `widgets/route_map.dart`
  하나로 묶어 두었다.
- **필터 상수**: `track_filter.dart` 의 임계값들은 이론값 기준이다.
  실기기에서 실제 산책 로그를 받아 보정해야 한다. 특히 도심 골목과
  하천변에서 값이 크게 다르다.
- **서버 동기화 없음**: 기기를 바꾸면 기록이 사라진다. 추천 기능을 붙일 때
  백엔드(Spring Boot + PostGIS)와 함께 설계한다.
