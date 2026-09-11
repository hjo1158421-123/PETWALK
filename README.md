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
- 반려견 프로필과 견종별 권장 산책량, 산책별 동반 반려견 기록

## 현재 상태

Flutter 3.47.3 (Dart 3.13.3) 기준으로 아래까지 확인했다.

- `flutter analyze` — 이슈 0건
- `flutter test` — 33개 전부 통과 (기기 없이 실행)
- `android/` `ios/` 네이티브 폴더 생성 및 위치 권한 설정 완료
- `flutter build apk --release` — 성공 (50.0MB, dev.petwalk.petwalk, minSdk 24 / targetSdk 36)
- Chrome 에서 실행 확인 — 지도, 기록 화면, 이력 화면(웹 sqlite) 정상 동작
- 산책 기록 전 과정 검증 — 모의 GPS 주입으로 158m 기록(실제 156m, 오차 1.3%)

**실기기 동작은 아직 확인하지 못했다.** 특히 GPS 필터는 에뮬레이터로
검증되지 않는다. 위치가 가짜라 노이즈 필터가 하는 일이 없다.

## 에디터에서 실행하기

VS Code 를 쓴다. Flutter 개발에는 사실상 표준이고 이미 설치돼 있다.
(IntelliJ IDEA Ultimate 도 Dart + Flutter 플러그인을 깔면 되지만,
VS Code 쪽이 가볍고 설정할 게 적다.)

1. VS Code 확장에서 **Flutter** 설치 (Dart 확장이 같이 딸려온다)
2. `C:\PETWALK\app` 폴더를 연다 — 최상위가 아니라 `app` 폴더여야 한다
3. 오른쪽 아래 상태바에서 기기를 **Chrome** 으로 고른다
4. `F5` 를 누른다

`.vscode/launch.json` 에 실행 구성이 들어 있어서 F5 만 누르면 된다.
코드를 저장하면 핫 리로드로 화면에 즉시 반영된다.

Flutter SDK 경로(`C:\flutter`)는 `.vscode/settings.json` 에 이미 적어 뒀다.

## 반려견 프로필

산책량을 계산하고, 나중에 산책로 추천의 개인화 입력이 되는 부분이다.
프로필에서 받는 값이 그대로 추천 가중치로 이어지도록 설계했다.

| 입력 | 지금 쓰는 곳 | 추천 단계에서 쓸 곳 |
|---|---|---|
| 견종 | 크기·활동량·단두종 자동 채움 | — |
| 단두종 여부 | 권장량 축소, 더위 주의 | 여름 낮 시간대 하드 필터 |
| 나이(생년월) | 자견·노령견 판정 | 경사도 가중치 |
| 몸집 | 권장 거리 기준선 | 목표 코스 길이 |
| 활동량 | 권장량 배율 | 코스 난이도 |
| 사교성 | — | 혼잡도 가중치 |

견종을 고르면 크기·활동량·단두종 여부가 자동으로 채워진다
(`lib/data/breed_catalog.dart`, 국내에서 흔한 48종). 목록에 없으면 직접
입력하고 값을 고르면 된다.

한 번의 산책에 여러 마리가 함께 나갈 수 있다. 다견 가정이 드물지 않아서
처음부터 다대다로 두었다. 여러 마리일 때 권장량은 **가장 체력이 약한
아이에게 맞춘다.**

프로필을 목록에서 빼도 지난 산책 기록은 남는다. 실제로 걸었던 사실까지
사라지면 통계가 어긋나기 때문이다 (`is_active` 플래그로 처리).

### 권장 산책량 계산

몸집으로 기준선을 잡고 나이·활동량·단두종 여부로 조정한다
(`lib/models/walk_goal.dart`).

- 기준: 소형 1.5km/30분, 중형 3.5km/60분, 대형 5km/75분
- 자견(12개월 미만): 월령 x 5분, 하루 두 번 — 성장판 보호
- 노령견: 0.6배 (노령 기준은 몸집이 클수록 빨리 온다)
- 활동량: 차분함 0.8배, 활발함 1.3배
- 단두종: 0.6배

어디까지나 일반적인 기준이다. 화면에도 수의사 상담을 권하는 문구를 같이
띄운다.

## 테스트

```bash
export PATH="/c/flutter/bin:$PATH" && flutter test
```

기기 없이 돌아간다. 16개가 통과해야 정상이다.

| 파일 | 무엇을 검증하나 |
|---|---|
| `test/track_filter_test.dart` | GPS 노이즈 제거 — 정지 드리프트, 실제 보행 거리, 이상치 |
| `test/course_matcher_test.dart` | geohash 인코딩, 코스 동일성 판정 |
| `test/walk_recording_flow_test.dart` | **기록 전 과정** — 좌표 수신 → 필터 → DB 저장 → 코스 묶기 |

화면까지 포함한 종단 테스트는 `integration_test/app_test.dart` 에 있다.
버튼을 실제로 눌러 화면 전환과 저장을 확인하는데, 기기나 에뮬레이터가
있어야 돌아간다.

```bash
cd /c/PETWALK/app && export PATH="/c/flutter/bin:$PATH" && flutter test integration_test
```

둘로 나눈 이유가 있다. `testWidgets` 는 가짜 시계 위에서 도는데 sqflite 는
실제 비동기 I/O 라서, 화면 테스트 안에서 DB 를 기다리면 영원히 끝나지 않는다.
그래서 DB 가 얽힌 검증은 서비스 계층으로 내리고, 화면 검증은 실제 시간이
흐르는 integration_test 로 올렸다.

## PC에서 UI 보기 (웹)

실기기나 에뮬레이터 없이 Chrome 으로 화면을 확인할 수 있다.

```bash
cd /c/PETWALK/app && export PATH="/c/flutter/bin:$PATH" && dart run sqflite_common_ffi_web:setup
```

```bash
cd /c/PETWALK/app && export PATH="/c/flutter/bin:$PATH" && flutter run -d chrome
```

첫 명령은 `web/sqlite3.wasm` 을 내려받는다. 한 번만 하면 된다.

VS Code 를 쓴다면 Flutter 확장을 깔고 F5 를 눌러 기기 목록에서 Chrome 을
고르면 된다. 핫 리로드가 붙어서 UI 다듬을 때 훨씬 빠르다.

**웹은 UI 확인용이다.** 백그라운드 위치와 포그라운드 서비스는 웹에 개념이
없어서 검증되지 않고, GPS 좌표에 노이즈가 없어서 필터도 하는 일이 없다.

## APK 설치

릴리스 APK는 빌드 후 아래 위치에 생성된다.

```
app/build/app/outputs/flutter-apk/app-release.apk
```

`--split-per-abi` 로 빌드하면 ABI별로 쪼개져 파일당 크기가 절반 이하가
된다. 요즘 안드로이드폰은 대부분 `app-arm64-v8a-release.apk` 를 쓰면 된다.

폰에서 파일을 받은 뒤 "알 수 없는 출처 앱 설치"를 허용하면 설치된다.
스토어 등록도 개발자 계정도 필요 없다.

iOS는 이 방식이 통하지 않는다. `.ipa` 는 코드 서명과 프로비저닝 프로파일이
없으면 OS가 설치를 거부하고, `.ipa` 를 만드는 데 macOS + Xcode가 필요하다.
웹에서 받아 설치하는 Ad Hoc 배포는 가능하지만 Apple Developer Program
(연 $99)이 필요하다. Mac 없이 하려면 CI(Codemagic, GitHub Actions의
macOS 러너)에서 빌드하면 된다.

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
  models/          Walk, TrackPoint, Course, Dog, WalkGoal
  data/            견종 카탈로그 (크기·활동량·단두종)
  services/
    location_service.dart   GPS 스트림 + 권한 + 플랫폼별 백그라운드 설정
    track_filter.dart       GPS 노이즈 제거 (여기가 정확도의 핵심)
    walk_recorder.dart      기록 상태 기계. 화면은 여기만 본다
    walk_repository.dart    SQLite CRUD + 코스 매칭
    course_matcher.dart     같은 길인지 판정하는 규칙
    dog_repository.dart     반려견 프로필 CRUD + 산책 연결
    db.dart, geo.dart       스키마(v2), 거리/geohash 계산
  screens/         산책 / 이력 / 상세 / 코스 / 우리 아이 / 프로필 편집
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
