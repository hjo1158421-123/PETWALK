import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/theme_controller.dart';
import 'services/walk_recorder.dart';
import 'services/walk_repository.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 앱이 강제 종료되면 종료 시각이 없는 산책이 남는다.
  // 지점 데이터로 통계를 복원해서 이력에 살려 둔다.
  //
  // 여기서 실패해도 앱은 떠야 한다. DB가 깨졌다고 화면조차 안 나오면
  // 사용자는 원인을 알 방법이 없다.
  try {
    await WalkRepository().recoverUnfinished();
  } catch (e, st) {
    debugPrint('산책 기록 복구 실패: $e');
    debugPrintStack(stackTrace: st);
  }

  await _warmUpFonts();

  runApp(const PetWalkApp());
}

/// 두 테마의 글꼴을 미리 받아 둔다.
///
/// 글꼴이 첫 프레임보다 늦게 도착하면, 대체 글꼴로 재 놓은 글자 크기와
/// 실제로 그릴 글자 크기가 어긋나 렌더링이 한 번 깨진다
/// (`debugSize == size` assertion).
///
/// **쓰는 쪽만 받아서는 안 된다.** 테마를 바꾸는 순간 반대편 글꼴을 처음
/// 받게 되어 같은 문제가 다시 난다. 그래서 두 벌을 모두 미리 받는다.
///
/// 실패해도 앱은 떠야 한다. 지하철이나 산 속에서 앱이 아예 안 뜨는 것보다
/// 대체 글꼴로 뜨는 편이 낫다. 타임아웃을 두는 이유도 같다 — 느린 망에서
/// 흰 화면을 오래 보여 주지 않는다.
Future<void> _warmUpFonts() async {
  try {
    // 게터를 불러야 내려받기가 시작된다. pendingFonts 는 이미 시작된
    // 것만 기다리므로 순서가 중요하다.
    GoogleFonts.poorStory();
    GoogleFonts.gowunDodum();
    GoogleFonts.blackHanSans();
    GoogleFonts.ibmPlexSansKr();
    GoogleFonts.ibmPlexMono();

    await GoogleFonts.pendingFonts().timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('글꼴을 미리 받지 못했습니다 (대체 글꼴로 표시됩니다): $e');
  }
}

class PetWalkApp extends StatelessWidget {
  const PetWalkApp({super.key, this.recorderFactory});

  /// 테스트에서 가짜 위치 서비스를 물린 레코더를 넣기 위한 주입 지점.
  /// 비워 두면 실제 GPS 를 쓰는 기본 레코더가 만들어진다.
  final WalkRecorder Function()? recorderFactory;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => recorderFactory?.call() ?? WalkRecorder(),
        ),
        ChangeNotifierProvider(create: (_) => ThemeController()..load()),
      ],
      child: Consumer<ThemeController>(
        builder: (_, themeController, __) => MaterialApp(
          title: 'PETWALK',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(themeController.variant),
          // 두 안 모두 종이/크림 톤을 전제로 설계됐다. 다크 모드는 색을
          // 처음부터 다시 잡아야 해서 지금은 두지 않는다.
          themeMode: ThemeMode.light,
          home: const HomeScreen(),
        ),
      ),
    );
  }
}
