import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// 웹에서는 IndexedDB 위에서 도는 WASM sqlite 로 갈아끼운다.
///
/// 워커를 쓰는 기본 구현(databaseFactoryFfiWeb)은 SharedArrayBuffer 가 필요하고,
/// 그러려면 서버가 COOP/COEP 헤더를 내려줘야 한다. flutter run 의 개발 서버는
/// 그 헤더를 주지 않아서 워커가 응답하지 못하고 openDatabase 가 null 을 돌려준다.
/// 그래서 워커 없이 메인 스레드에서 도는 구현을 쓴다.
///
/// 실제 서비스용이 아니라 PC에서 UI를 보며 개발하기 위한 경로다.
/// 큰 쿼리를 돌리면 UI가 잠깐 멈출 수 있고, 브라우저 저장소라 용량 제한과
/// 삭제 정책도 기기와 다르다.
Future<void> initDatabaseFactory() async {
  databaseFactory = databaseFactoryFfiWebNoWebWorker;
}

/// 웹에는 경로 개념이 없다. 파일명이 곧 DB 식별자다.
Future<String> databasePathFor(String fileName) async => fileName;
