import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 릴리스 APK 의 매니페스트를 지킨다.
///
/// 여기 빠진 권한은 **조용히** 앱을 망가뜨린다. 빌드는 성공하고 앱도 뜨는데
/// 지도만 회색으로 비거나 글꼴이 기본으로 나온다. 기기에 설치해 보기 전에는
/// 알 수 없고, 알아채도 원인을 찾기 어렵다.
void main() {
  group('Android 릴리스 매니페스트', () {
    late String manifest;

    setUpAll(() {
      manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    });

    test('주석 안에 "--" 가 없다', () {
      // 주석에 "--" 를 넣었다가 매니페스트 파싱이 깨져 빌드가 3분 만에
      // 죽은 적이 있다. XML 주석에는 "--" 를 쓸 수 없다.
      // 에러는 "Error parsing AndroidManifest.xml" 한 줄뿐이라 원인을 짚기
      // 어렵다. 한국어 주석에 대시를 쓰고 싶을 때 다시 밟을 함정이다.
      final comments = RegExp(r'<!--([\s\S]*?)-->').allMatches(manifest);
      expect(comments, isNotEmpty, reason: '주석이 사라졌다면 이 검사도 의미가 없다');

      for (final c in comments) {
        expect(
          c.group(1),
          isNot(contains('--')),
          reason: '이 주석이 빌드를 깨뜨린다: ${c.group(1)?.trim()}',
        );
      }
    });

    test('INTERNET 권한이 main 에 있다', () {
      // Flutter 템플릿은 이 권한을 debug/profile 매니페스트에만 넣어 둔다.
      // 개발 중에는 멀쩡하다가 릴리스 APK 에서만 지도 타일(OSM)과
      // 글꼴(Google Fonts)이 죽는다.
      expect(
        manifest,
        contains('android.permission.INTERNET'),
        reason: '릴리스 APK 에서 지도와 글꼴을 받지 못한다',
      );
    });

    test('위치 권한이 모두 선언돼 있다', () {
      for (final p in const [
        'ACCESS_FINE_LOCATION',
        'ACCESS_BACKGROUND_LOCATION',
        'FOREGROUND_SERVICE_LOCATION',
      ]) {
        expect(manifest, contains(p), reason: '$p 없이는 산책 기록이 끊긴다');
      }
    });

    test('GPS 를 필수 기능으로 요구하지 않는다', () {
      // 위치 권한이 있으면 GPS 가 필수로 간주되어 WiFi 전용 태블릿이
      // 설치 대상에서 빠진다. 개발 중에는 가짜 GPS 로도 확인할 수 있어야 한다.
      expect(
        manifest.replaceAll(RegExp(r'\s+'), ' '),
        contains('android:name="android.hardware.location.gps" '
            'android:required="false"'),
      );
    });
  });
}
