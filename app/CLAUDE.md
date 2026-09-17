# PETWALK

반려견 산책 기록 + 산책로 추천 앱. Flutter.

이 파일은 세션 시작 시 자동으로 읽힌다. 작업 전에 아래를 한 번 훑고 시작할 것.
더 깊은 맥락은 [docs/](docs/) 안의 문서들에 있다.

## 무엇을 만드는가

두 축이다.

1. **산책 기록** — GPS로 경로를 기록하고, 같은 길을 반복하면 "코스"로 묶어
   이력을 보여 준다. **v1 완료.**
2. **산책로 추천** — "이 길이 강아지 산책로로 괜찮은가"를 점수화해서 코스를
   제안한다. **v2(규칙 기반, 앱 프로토타입) 완료.** 설계는
   [docs/추천-설계.md](docs/추천-설계.md).

추천이 이 앱의 차별점이다. 기록 기능은 그 기반이자 데이터 공급원이다.

## 지금 어디까지 왔나

| 항목 | 상태 |
|---|---|
| GPS 기록 + 노이즈 필터 | 완료, 테스트됨 |
| 로컬 SQLite (v2) | 완료, 마이그레이션 테스트 있음 |
| 코스 자동 묶기 | 완료 |
| 반려견 프로필 + 권장 산책량 | 완료 (근거 보강은 아래 TODO) |
| Android APK 빌드 | 성공 확인 |
| 웹(Chrome) 실행 | 동작 확인 |
| 실기기 GPS 기록 | Android 태블릿에서 확인됨 (release APK) |
| 산책로 추천 (앱 프로토타입) | 엔진 완료. **실제 OSM 연동은 이 PC에서 미확인** — 아래 참조 |

### TODO

- [ ] **48종 중 28종은 아직 견종별 근거가 없다 — 계속 보강할 것.**
      Carter & Farnworth(2021) 논문 표에 이름이 나온 20종만 UK 켄넬클럽
      실측치(`BreedCatalog.recommendedMinutes`)로 채웠다. 나머지는 여전히
      몸집 추정(근거 없음)이다. 다른 1차 자료(각국 켄넬클럽 공식 문서,
      견종 표준)를 찾으면 채울 자리. 활동량 배수(0.8/1.0/1.3)·단두종
      감축(×0.7)·걸음 속도(55m/분)도 몸집 추정 경로에서는 여전히 근거
      없음 — 견종 기준값이 있을 때는 이제 이 배수들을 곱하지 않는다.
      상세는 [docs/권장산책량-근거.md](docs/권장산책량-근거.md).

- [ ] **추천 엔진을 실기기(회사 와이파이 아닌 곳)에서 확인할 것.**
      Overpass API(OSM 도로망)가 이 PC 의 회사 네트워크에서 막혀 있어
      "산책" 탭 → "오늘 코스 추천받기"를 이 PC에서 끝까지 확인할 수
      없었다. 파싱·점수화·경로탐색 로직은 fixture 로 테스트했고, 실제
      화면에서 에러 처리(로딩 → "OSM 서버가 요청을 거부했어요" → 재시도
      가능 상태 복귀)까지는 확인했다. 실기기에서 진짜 좌표로 코스가
      나오는지가 아직 안 봤다. 자세한 사정은
      `lib/services/overpass_service.dart` 상단 주석과
      [docs/추천-설계.md](docs/추천-설계.md) v2 항목 참조.

- [ ] **편의시설·혼잡소음 지표(가중치 25%)가 아직 없다.** 국내
      공공데이터포털 신청이 필요해 이번 v2 에서는 뺐다 — 지금은 노면·
      차도분리도·그늘·경사(75%)만 반영한다. `docs/추천-설계.md`
      "가중 점수" 표 참조.

- [ ] **코스 생성 알고리즘이 최적해가 아니다.** Dijkstra 기반 휴리스틱
      이라 항상 "가장 산책하기 좋은" 루프를 찾는다고 보장 못 한다.
      백엔드(pgRouting)로 옮길 때 정식 경로 탐색으로 교체해야 하는
      자리다. `lib/services/route_recommender.dart` 상단 주석 참조.

`flutter analyze` 0건, `flutter test` 119개 통과 상태를 유지할 것.

## 절대 건드리면 안 되는 것

- **`JAVA_HOME`** — 시스템 레벨에 `C:\Program Files\Java\jdk1.6.0_21` 로
  잡혀 있다. 이 PC에서 레거시 자바 프로젝트(`C:\shinsungDev\ssts`)가 그
  JDK로 실제 돌아간다. 바꾸면 그 프로젝트가 깨진다.
  Flutter 는 `flutter config --jdk-dir` 로 JDK 17 을 따로 알고 있어서
  JAVA_HOME 과 무관하게 빌드된다.
  **이 설정이 풀리면 Gradle 이 JAVA_HOME(JDK 1.6)을 집어 든다.**
  `UnsupportedClassVersionError ... version 52.0` 이 그 증상이다.
  고치는 법은 시스템 JAVA_HOME 이 아니라 이 설정이다:

  ```powershell
  flutter config --jdk-dir='C:\jdk17'
  ```

  Git Bash 에서는 백슬래시가 먹혀 `C:jdk17` 로 잘못 저장되니
  PowerShell 에서 작은따옴표로 줄 것. `flutter config --list` 로 확인한다.
- **User PATH 정리** — 중복 8건과 깨진 항목(`C`)이 있지만 사용자가 그대로
  두기로 했다. 손대지 말 것.
- **`lib/services/track_filter.dart` 의 임계값** — 실기기 로그로 보정해야
  하는 값이다. 근거 없이 바꾸면 과거 기록과 어긋난다.
- **`lib/models/walk_goal.dart` 의 수치와 문구, `lib/data/breed_catalog.dart`
  의 `recommendedMinutes`** — 살아 있는 동물의 건강에 관한 조언이다. 각 값
  옆에 근거를 적어 두었고 근거 없는 값은 "근거 없음"이라고 명시했다.
  **출처 없이 숫자를 바꾸거나 새 문구를 추가하지 말 것.**
  특히 되돌리기 쉬운 것들: 노령견 총량을 깎지 않는다, 거리가 아니라
  시간이 목표다, **견종 기준값(`hasBreedEvidence`)이 있으면 활동량·단두종
  배수를 곱하지 않는다** — 근거 있는 값에 근거 없는 배수를 다시 덮어쓰게
  된다. 이유는 [docs/권장산책량-근거.md](docs/권장산책량-근거.md).

## 개발 환경

| 도구 | 경로 | 비고 |
|---|---|---|
| Flutter 3.47.3 | `C:\flutter` | 시스템 PATH 에 등록됨 |
| JDK 17 | `C:\jdk17` | Flutter 전용. JAVA_HOME 아님 |
| Android SDK | `C:\Android\Sdk` | `ANDROID_HOME` 설정됨 |

- **에뮬레이터를 쓸 수 없다.** BIOS 에서 AMD-V(SVM)가 꺼져 있다.
  사용자가 직접 켜야 한다.
- 그래서 **가짜 GPS** 로 기록 흐름을 확인한다. 산책 탭 위쪽의
  "가짜 GPS로 산책해 보기" 를 켜고 산책을 시작하면 저절로 걷는다.
  `kDebugMode` 라 릴리스에는 없다. 여기서 만든 기록은 이력에 그대로 남으니
  확인 후 지울 것. (`lib/services/simulated_location_service.dart`)
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
cd /c/PETWALK/app && export PATH="/c/flutter/bin:$PATH" && flutter run -d web-server --web-port=8080 --web-hostname=localhost
```

띄운 뒤 평소 쓰는 Chrome 으로 `http://localhost:8080` 을 직접 연다.
VS Code 는 F5 → `PETWALK (web-server :8080)`.

**`-d chrome` 은 이 PC 에서 안 된다.** 회사 Chrome 정책이 확장을 강제
설치하는데 Flutter 가 붙이는 `--disable-extensions` 와 충돌해서 브라우저가
기동하지 않는다. 정책은 건드리지 말 것. 자세한 건
[docs/개발환경-함정.md](docs/개발환경-함정.md).

`flutter run` 이 떠 있으면 프로젝트 락 때문에 `flutter test` 가 멈춘다.
테스트 전에 dev 서버를 내릴 것.

## 코드 구조

`app/lib/` 아래.

```
models/      Walk, TrackPoint, Course, Dog, WalkGoal
  route_segment.dart      추천 엔진 세그먼트 — 좌표·노면·차도분리도·그늘
  recommended_course.dart 추천 엔진이 만든 순환 코스
data/        breed_catalog.dart  견종 48종 (크기/활동량/단두종/켄넬클럽 권장시간)
theme/
  app_theme.dart        1a(포근)/1b(미니멀) 두 안. 토큰만 갈아끼운다
services/
  track_filter.dart     GPS 노이즈 제거. 정확도의 핵심
  walk_recorder.dart    기록 상태 기계. 화면은 여기만 본다
  walk_repository.dart  산책 CRUD + 코스 매칭
  dog_repository.dart   반려견 CRUD + 산책 연결
  course_matcher.dart   같은 길인지 판정하는 규칙
  location_service.dart GPS 스트림 + 권한 + 플랫폼별 설정
  simulated_location_service.dart 가짜 GPS. 개발용(kDebugMode)
  theme_controller.dart 고른 테마 보관 + 저장
  overpass_service.dart      OSM 도로망 가져오기 + 세그먼트 분할
  elevation_service.dart     Open-Elevation 고도 조회
  segment_scorer.dart        세그먼트 지표별 채점
  route_recommender.dart     그래프 구성 + 순환 경로 탐색
  recommendation_service.dart 위 넷을 하나로 묶는 진입점
  db.dart               스키마 v2 + 마이그레이션
  db_platform*.dart     웹/네이티브 sqflite 분기
screens/     산책 / 이력 / 상세 / 코스 / 우리 아이 / 프로필 편집 / 코스 추천
widgets/
  route_map.dart            지도 SDK 교체 지점 (걸은 기록용)
  recommended_route_map.dart 추천 코스 지도 표시 (route_map 과는 별개)
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

- [docs/추천-설계.md](docs/추천-설계.md) — 추천 엔진 설계. v2(앱 프로토타입)
  구현 위치와 한계가 "구현 순서" 절에 정리돼 있다
- [docs/권장산책량-근거.md](docs/권장산책량-근거.md) — 권장 산책량의 숫자와
  문구가 어디서 왔는지. 근거 있는 값과 없는 값을 구분해 두었다
- [docs/의사결정-기록.md](docs/의사결정-기록.md) — 왜 이렇게 만들었는지.
  되돌리기 전에 반드시 읽을 것
- [docs/개발환경-함정.md](docs/개발환경-함정.md) — 이 환경에서 시간을
  잡아먹었던 것들. 같은 함정을 다시 밟지 않기 위한 기록
- [README.md](README.md) — 실행 방법, 빌드, 설치, 현재 상태
