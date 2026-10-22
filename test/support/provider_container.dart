import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/data/providers.dart';

import 'fakes.dart';

/// 테스트의 '지금'. 날짜에 따라 결과가 흔들리지 않게 고정한다.
final testNow = DateTime(2026, 10, 15, 9);

/// 가짜 저장소를 끼운 ProviderContainer. 테스트가 끝나면 정리된다.
ProviderContainer createContainer({
  FakeAuthRepository? auth,
  FakeLedgerRepository? ledgers,
  FakeSettingsRepository? settings,
  DateTime? now,
}) {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository()),
      ledgerRepositoryProvider.overrideWithValue(
        ledgers ?? FakeLedgerRepository(),
      ),
      settingsRepositoryProvider.overrideWithValue(
        settings ?? FakeSettingsRepository(),
      ),
      clockProvider.overrideWithValue(() => now ?? testNow),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// 로그인 상태를 먼저 받아 둔다. 컨트롤러가 `authUserProvider`의 값을 바로 읽을 수 있게 한다.
Future<void> loadSignedInUser(ProviderContainer container) async {
  container.listen(authUserProvider, (_, _) {});
  await container.read(authUserProvider.future);
}

/// autoDispose 컨트롤러를 테스트 동안 살려 두고, 지나간 상태를 모두 기록한다.
List<S> recordStates<S>(
  ProviderContainer container,
  ProviderListenable<S> provider,
) {
  final states = <S>[];
  container.listen(provider, (_, next) => states.add(next));
  return states;
}
