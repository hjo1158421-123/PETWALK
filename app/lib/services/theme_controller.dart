import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

/// 지금 고른 테마를 들고 있다가 바뀌면 앱 전체에 알린다.
///
/// 저장 실패는 삼킨다. 테마가 기억되지 않는 건 불편할 뿐이지만, 여기서
/// 예외가 올라가면 앱이 뜨지 않거나 버튼이 먹통이 된다. 둘 중에는 전자가
/// 훨씬 낫다.
class ThemeController extends ChangeNotifier {
  ThemeController({AppThemeVariant initial = AppThemeVariant.cozy})
      : _variant = initial;

  static const _prefsKey = 'theme_variant';

  AppThemeVariant _variant;
  AppThemeVariant get variant => _variant;

  /// 앱 시작 시 지난번 선택을 읽어 온다.
  ///
  /// 읽기 전에도 화면은 떠야 하므로 기본값으로 먼저 그리고, 저장된 값이
  /// 있으면 그때 갈아끼운다. 첫 프레임이 잠깐 기본 테마로 보일 수 있지만
  /// 스플래시를 하나 더 만드는 것보다 낫다.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved == null) return;

      for (final v in AppThemeVariant.values) {
        if (v.name == saved && v != _variant) {
          _variant = v;
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint('테마 설정을 읽지 못했습니다: $e');
    }
  }

  Future<void> select(AppThemeVariant next) async {
    if (next == _variant) return;
    _variant = next;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, next.name);
    } catch (e) {
      debugPrint('테마 설정을 저장하지 못했습니다: $e');
    }
  }

  Future<void> toggle() => select(_variant.next);
}
