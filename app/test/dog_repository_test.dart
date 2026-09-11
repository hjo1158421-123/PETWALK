import 'package:flutter_test/flutter_test.dart';
import 'package:petwalk/models/dog.dart';
import 'package:petwalk/services/db.dart';
import 'package:petwalk/services/dog_repository.dart';
import 'package:petwalk/services/walk_recorder.dart';
import 'package:petwalk/services/walk_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_location_service.dart';
import 'support/walk_simulator.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await AppDb.resetForTesting();
    AppDb.pathOverride = inMemoryDatabasePath;
    await databaseFactory.deleteDatabase(inMemoryDatabasePath);
  });

  tearDown(() async => AppDb.resetForTesting());

  test('반려견을 등록하고 다시 읽어온다', () async {
    final repo = DogRepository();

    final id = await repo.insertDog(Dog.fromBreed('콩이', '퍼그'));
    final dog = await repo.findDog(id);

    expect(dog, isNotNull);
    expect(dog!.name, '콩이');
    expect(dog.breed, '퍼그');
    expect(dog.brachycephalic, isTrue, reason: '견종에서 채워진 값이 저장돼야 한다');
    expect(dog.size, DogSize.small);
  });

  test('목록에서 빼도 산책 기록은 남는다', () async {
    final repo = DogRepository();
    final walkRepo = WalkRepository();

    final id = await repo.insertDog(Dog.fromBreed('콩이', '말티즈'));
    await _record([id]);

    expect(await walkRepo.listWalks(), hasLength(1));

    await repo.deactivateDog(id);

    // 목록에서는 사라지지만
    expect(await repo.listDogs(), isEmpty);
    // 기록과 연결은 그대로다
    expect(await walkRepo.listWalks(), hasLength(1));
    expect(await repo.listDogs(includeInactive: true), hasLength(1));
  });

  test('산책을 반려견과 연결하고 통계를 낸다', () async {
    final repo = DogRepository();
    final kong = await repo.insertDog(Dog.fromBreed('콩이', '말티즈'));
    final bori = await repo.insertDog(Dog.fromBreed('보리', '비글'));

    // 둘이 함께 한 번, 콩이만 한 번
    await _record([kong, bori]);
    await _record([kong]);

    final kongStats = await repo.statsFor(kong);
    final boriStats = await repo.statsFor(bori);

    expect(kongStats.count, 2);
    expect(boriStats.count, 1);
    expect(kongStats.distanceM, greaterThan(boriStats.distanceM));
  });

  test('여러 산책의 동반 반려견을 한 번에 가져온다', () async {
    final repo = DogRepository();
    final walkRepo = WalkRepository();
    final kong = await repo.insertDog(Dog.fromBreed('콩이', '말티즈'));

    await _record([kong]);
    await _record([]);

    final walks = await walkRepo.listWalks();
    final map = await repo.dogsForWalks([for (final w in walks) w.id!]);

    // 반려견을 지정한 산책만 항목이 생긴다
    expect(map.values.expand((e) => e).map((d) => d.name), contains('콩이'));
    expect(map.length, 1);
  });

  test('반려견 프로필을 지우면 연결도 함께 사라진다', () async {
    final repo = DogRepository();
    final id = await repo.insertDog(Dog.fromBreed('콩이', '말티즈'));
    await _record([id]);

    await repo.deleteDogPermanently(id);

    final walks = await WalkRepository().listWalks();
    // 산책 자체는 남고 연결만 정리된다 (ON DELETE CASCADE)
    expect(walks, hasLength(1));
    expect(await repo.dogsForWalk(walks.single.id!), isEmpty);
  });
}

/// 산책 한 번을 기록한다.
Future<void> _record(List<int> dogIds) async {
  final location = FakeLocationService();
  final recorder = WalkRecorder(location: location);

  await recorder.start(dogIds: dogIds);
  for (final p in simulateWalk().positions) {
    location.emit(p);
    await Future<void>.delayed(Duration.zero);
  }
  await Future<void>.delayed(const Duration(milliseconds: 50));
  await recorder.stop();
  recorder.dispose();
  await location.close();
}
