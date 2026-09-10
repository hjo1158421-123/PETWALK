import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/walk_recorder.dart';
import 'services/walk_repository.dart';

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

  runApp(const PetWalkApp());
}

class PetWalkApp extends StatelessWidget {
  const PetWalkApp({super.key, this.recorderFactory});

  /// 테스트에서 가짜 위치 서비스를 물린 레코더를 넣기 위한 주입 지점.
  /// 비워 두면 실제 GPS 를 쓰는 기본 레코더가 만들어진다.
  final WalkRecorder Function()? recorderFactory;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => recorderFactory?.call() ?? WalkRecorder(),
      child: MaterialApp(
        title: 'PETWALK',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF3DA35D),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: const Color(0xFF3DA35D),
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
