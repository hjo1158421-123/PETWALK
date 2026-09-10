import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// 네이티브에서는 sqflite 기본 팩토리를 그대로 쓴다.
Future<void> initDatabaseFactory() async {}

Future<String> databasePathFor(String fileName) async =>
    p.join(await getDatabasesPath(), fileName);
