import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/data/providers.dart';

import 'fakes.dart';

/// 가짜 저장소를 끼운 ProviderContainer. 테스트가 끝나면 정리된다.
ProviderContainer createContainer({
  FakeAuthRepository? auth,
  FakeLedgerRepository? ledgers,
}) {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository()),
      ledgerRepositoryProvider.overrideWithValue(
        ledgers ?? FakeLedgerRepository(),
      ),
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
