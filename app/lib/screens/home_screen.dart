import 'package:flutter/material.dart';

import 'dogs_screen.dart';
import 'history_screen.dart';
import 'walk_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  final _historyKey = GlobalKey<HistoryScreenState>();
  final _dogsKey = GlobalKey<DogsScreenState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const WalkScreen(),
          HistoryScreen(key: _historyKey),
          DogsScreen(key: _dogsKey),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          // 산책을 마치고 돌아오면 목록이 최신이어야 한다.
          if (i == 1) _historyKey.currentState?.reload();
          if (i == 2) _dogsKey.currentState?.reload();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.directions_walk_outlined),
            selectedIcon: Icon(Icons.directions_walk),
            label: '산책',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: '이력',
          ),
          NavigationDestination(
            icon: Icon(Icons.pets_outlined),
            selectedIcon: Icon(Icons.pets),
            label: '우리 아이',
          ),
        ],
      ),
    );
  }
}
