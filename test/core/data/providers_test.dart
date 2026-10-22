import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/data/providers.dart';
import 'package:shared_ledger/core/model/auth_user.dart';
import 'package:shared_ledger/core/model/ledger.dart';
import 'package:shared_ledger/core/model/year_month.dart';

import '../../support/fakes.dart';
import '../../support/provider_container.dart';

void main() {
  const me = AuthUser(uid: 'me');

  test('보는 달은 이번 달에서 시작하고 앞뒤로 옮긴다', () {
    final container = createContainer(now: DateTime(2026, 12, 31, 23));
    final month = container.read(selectedMonthProvider.notifier);

    expect(container.read(selectedMonthProvider), const YearMonth(2026, 12));
    month.next();
    expect(container.read(selectedMonthProvider), const YearMonth(2027, 1));
    month
      ..previous()
      ..previous();
    expect(container.read(selectedMonthProvider), const YearMonth(2026, 11));
  });

  test('이름표는 지금 가계부의 것을 읽는다', () async {
    final settings = FakeSettingsRepository();
    final container = createContainer(
      auth: FakeAuthRepository(signedIn: me),
      ledgers: FakeLedgerRepository([
        const Ledger(id: 'l1', name: '우리 가계부', ownerUid: 'me'),
      ]),
      settings: settings,
    );
    await loadSignedInUser(container);
    container.listen(membersProvider, (_, _) {});
    // 가계부 목록이 오기 전에는 지금 가계부가 없어 빈 목록이다. 목록을 받은 뒤의 값을 본다.
    await container.read(myLedgersProvider.future);

    expect(await container.read(membersProvider.future), settings.members);
    expect(settings.watched, ['l1']);
  });

  test('가계부가 없으면 설정을 구독하지 않고 빈 목록이다', () async {
    final settings = FakeSettingsRepository();
    final container = createContainer(
      auth: FakeAuthRepository(signedIn: me),
      settings: settings,
    );
    await loadSignedInUser(container);
    for (final provider in [
      membersProvider,
      categoriesProvider,
      paymentMethodsProvider,
    ]) {
      container.listen(provider, (_, _) {});
    }

    expect(await container.read(membersProvider.future), isEmpty);
    expect(await container.read(categoriesProvider.future), isEmpty);
    expect(await container.read(paymentMethodsProvider.future), isEmpty);
    expect(settings.watched, isEmpty);
  });
}
