/// 플랫폼별 sqflite 구현을 골라준다.
///
/// 웹에는 파일 시스템이 없어서 sqflite 기본 구현이 동작하지 않는다.
/// 조건부 import 로 웹에서만 IndexedDB 기반 구현을 끼워 넣는다.
/// (sqflite_common_ffi_web 을 네이티브에서 import 하면 웹 전용 코드 때문에
///  컴파일이 깨지므로, 반드시 이 방식이어야 한다.)
///
/// 조건을 "웹이면"이 아니라 "dart:io 가 있으면"으로 뒤집어 둔 이유:
/// dart.library.io 는 네이티브에서만 참이라 판별이 확실하다. 웹 판별용
/// 조건(js_interop, html)은 컴파일러와 Dart 버전에 따라 결과가 달라진다.
library;

export 'db_platform_web.dart' if (dart.library.io) 'db_platform_io.dart';
