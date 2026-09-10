import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/walk_recorder.dart';
import 'services/walk_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 앱이 강제 종료되면 종료 시각이 없는 산책이 남는다.
  // 지점 데이터로 통계를 복원해서 이력에 살려 둔다.
  await WalkRepository().recoverUnfinished();

  runApp(const PetWalkApp());
}

class PetWalkApp extends StatelessWidget {
  const PetWalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WalkRecorder(),
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
