# PETWALK

반려견 산책 기록 + 산책로 추천 앱. Flutter.

이 파일은 세션 시작 시 자동으로 읽힌다. 작업 전에 아래를 한 번 훑고 시작할 것.
더 깊은 맥락은 [docs/](docs/) 안의 문서들에 있다.

## 무엇을 만드는가

두 축이다.

1. **산책 기록** — GPS로 경로를 기록하고, 같은 길을 반복하면 "코스"로 묶어
   이력을 보여 준다. **v1 완료.**
2. **산책로 추천** — "이 길이 강아지 산책로로 괜찮은가"를 점수화해서 코스를
   제안한다. **아직 시작 안 함.** 설계는 [docs/추천-설계.md](docs/추천-설계.md).

추천이 이 앱의 차별점이다. 기록 기능은 그 기반이자 데이터 공급원이다.

## 지금 어디까지 왔나

| 항목 | 상태 |
|---|---|
| GPS 기록 + 노이즈 필터 | 완료, 테스트됨 |
| 로컬 SQLite (v2) | 완료, 마이그레이션 테스트 있음 |
| 코스 자동 묶기 | 완료 |
| 반려견 프로필 + 권장 산책량 | 완료 |
| Android APK 빌드 | 성공 확인 |
| 웹(Chrome) 실행 | 동작 확인 |
| **실기기 검증** | **안 됨 — 아래 참조** |
| **산책로 추천** | **미착수 — 다음 작업** |

`flutter analyze` 0건, `flutter test` 33개 통과 상태를 유지할 것.

## 다음 작업: 추천 엔진

착수 전에 갈림길이 하나 남아 있다. 사용자에게 확인하고 시작할 것.

- **①  백엔드부터** — PostgreSQL + PostGIS + pgRouting, Spring Boot API.
  설계대로지만 설치와 OSM 데이터 처리가 무겁다. 이 PC에 Postgres도
  Docker도 없다.
- **② 앱에서 프로토타입 먼저** — Overpass API로 주변 보행로를 받아 앱에서
  점수화. 서버 없이 화면으로 바로 검증할 수 있다. 공식이 자리 잡으면
  그대로 백엔드로 옮긴다.

②를 권한 상태다. 점수 가중치가 실제로 좋은 길을 골라내는지는 눈으로 봐야
알 수 있고, 백엔드를 다 세운 뒤 "공식이 별로였다"를 발견하면 비용이 크다.

## 절대 건드리면 안 되는 것

- **`JAVA_HOME`** — 시스템 레벨에 `C:\Program Files\Java\jdk1.6.0_21` 로
  잡혀 있다. 이 PC에서 레거시 자바 프로젝트(`C:\shinsungDev\ssts`)가 그
  JDK로 실제 돌아간다. 바꾸면 그 프로젝트가 깨진다.
  Flutter 는 `flutter config --jdk-dir` 로 JDK 17 을 따로 알고 있어서
  JAVA_HOME 과 무관하게 빌드된다.
- **User PATH 정리** — 중복 8건과 깨진 항목(`C`)이 있지만 사용자가 그대로
  두기로 했다. 손대지 말 것.
- **`lib/services/track_filter.dart` 의 임계값** — 실기기 로그로 보정해야
  하는 값이다. 근거 없이 바꾸면 과거 기록과 어긋난다.

## 개발 환경

| 도구 | 경로 | 비고 |
|---|---|---|
| Flutter 3.47.3 | `C:\flutter` | 시스템 PATH 에 등록됨 |
| JDK 17 | `C:\jdk17` | Flutter 전용. JAVA_HOME 아님 |
| Android SDK | `C:\Android\Sdk` | `ANDROID_HOME` 설정됨 |

- **에뮬레이터를 쓸 수 없다.** BIOS 에서 AMD-V(SVM)가 꺼져 있다.
  사용자가 직접 켜야 한다.
- **iOS 빌드를 할 수 없다.** Windows 에 Xcode 가 없다. 사용자 폰은 iOS 라
  실기기 확인이 막혀 있다.
- 그래서 **PC 확인은 Chrome(웹)으로 한다.**

## 자주 쓰는 명령

```bash
cd /c/PETWALK/app && export PATH="/c/flutter/bin:$PATH" && flutter test
```

```bash
cd /c/PETWALK/app && export PATH="/c/flutter/bin:$PATH" && flutter analyze
```

```bash
cd /c/PETWALK/app && export PATH="/c/flutter/bin:$PATH" && flutter run -d chrome
```

`flutter run` 이 떠 있으면 프로젝트 락 때문에 `flutter test` 가 멈춘다.
테스트 전에 dev 서버를 내릴 것.

## 코드 구조

`app/lib/` 아래.

```
models/      Walk, TrackPoint, Course, Dog, WalkGoal
data/        breed_catalog.dart  견종 48종 (크기/활동량/단두종)
services/
  track_filter.dart     GPS 노이즈 제거. 정확도의 핵심
  walk_recorder.dart    기록 상태 기계. 화면은 여기만 본다
  walk_repository.dart  산책 CRUD + 코스 매칭
  dog_repository.dart   반려견 CRUD + 산책 연결
  course_matcher.dart   같은 길인지 판정하는 규칙
  location_service.dart GPS 스트림 + 권한 + 플랫폼별 설정
  db.dart               스키마 v2 + 마이그레이션
  db_platform*.dart     웹/네이티브 sqflite 분기
screens/     산책 / 이력 / 상세 / 코스 / 우리 아이 / 프로필 편집
widgets/     route_map.dart  지도 SDK 교체 지점
```

## 지켜야 할 규칙

- **주석은 한국어로.** "무엇"이 아니라 **"왜"** 를 쓴다. 기존 주석 톤을
  따를 것 — 특히 왜 이 방식이어야 했는지, 다른 방식은 왜 안 되는지.
- **동작을 바꾸면 테스트를 함께 쓴다.** 특히 GPS 필터와 코스 매칭.
- **DB 스키마를 바꾸면 `onUpgrade` 와 마이그레이션 테스트를 같이 쓴다.**
  이미 기록이 쌓인 기기에서 데이터가 날아가면 안 된다.
  (`test/db_migration_test.dart` 가 본보기)
- **커밋 메시지에 "왜"를 남긴다.** 지금까지의 커밋들이 그 형식이다.
- 화면을 고쳤으면 Chrome 에서 실제로 열어 확인할 것. 오버플로우처럼
  눈으로만 보이는 문제가 있다.

## 더 읽을 것

- [docs/추천-설계.md](docs/추천-설계.md) — 추천 엔진 설계. 다음 작업의 기반
- [docs/의사결정-기록.md](docs/의사결정-기록.md) — 왜 이렇게 만들었는지.
  되돌리기 전에 반드시 읽을 것
- [docs/개발환경-함정.md](docs/개발환경-함정.md) — 이 환경에서 시간을
  잡아먹었던 것들. 같은 함정을 다시 밟지 않기 위한 기록
- [README.md](README.md) — 실행 방법, 빌드, 설치, 현재 상태
