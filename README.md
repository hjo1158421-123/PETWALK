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
- 같은 길을 걸으면 자동으로 코스로 묶기 (geohash + Jaccard 유사도)

## 시작하기

Flutter가 아직 설치돼 있지 않다. 먼저 SDK를 설치한다.

```bash
flutter --version
```

`app/` 에는 Dart 소스와 pubspec만 있고 `android/` `ios/` 네이티브 폴더는
아직 없다. 아래 순서로 생성한다.

```bash
cd C:/PETWALK/app && git init && git add -A && git commit -m "소스 백업"
```

```bash
cd C:/PETWALK/app && flutter create --platforms=android,ios --org dev.petwalk --project-name petwalk .
```

`flutter create` 가 `lib/main.dart` 를 덮어쓸 수 있으니, 실행 후 `git status`
로 확인하고 덮였으면 `git checkout lib/` 로 되돌린다.

```bash
cd C:/PETWALK/app && flutter pub get && flutter test
```

## 네이티브 설정 (직접 넣어야 함)

`flutter create` 로 생성된 파일에 아래를 추가한다. 이걸 빼먹으면 화면이
꺼진 뒤 기록이 끊긴다.

### android/app/src/main/AndroidManifest.xml

`<manifest>` 바로 아래:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
```

`<application>` 안:

```xml
<service
    android:name="com.baseflow.geolocator.GeolocatorLocationService"
    android:foregroundServiceType="location"
    android:enabled="true"
    android:exported="false"/>
```

`compileSdk` 는 34 이상이어야 한다 (`FOREGROUND_SERVICE_LOCATION` 요구사항).

### ios/Runner/Info.plist

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>산책 경로를 기록하기 위해 위치 정보를 사용합니다.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>화면이 꺼진 상태에서도 산책 경로를 이어서 기록하기 위해 위치 정보를 사용합니다.</string>
<key>UIBackgroundModes</key>
<array>
  <string>location</string>
</array>
```

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
