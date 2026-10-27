import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/providers/providers.dart';
import 'package:shared_ledger/domain/model/auth_user.dart';
import 'package:shared_ledger/domain/model/expense_template.dart';
import 'package:shared_ledger/domain/model/ledger.dart';
import 'package:shared_ledger/feature/templates/templates_notifier.dart';

import '../../../testing/fakes.dart';
import '../../../testing/provider_container.dart';

const me = AuthUser(uid: 'me');
const mine = Ledger(id: 'l1', name: '우리 가계부', ownerUid: 'me');

const rent = ExpenseTemplate(
  id: 'rent',
  title: '관리비',
  categoryId: 'c-spending',
  paymentMethodId: 'p-account',
  memberId: 'partner',
  dueDay: lastDueDay,
);

Future<ProviderContainer> ready(FakeTemplatesRepository templates) async {
  final container = createContainer(
    auth: FakeAuthRepository(signedIn: me),
    ledgers: FakeLedgerRepository([mine]),
    templates: templates,
  );
  await loadSignedInUser(container);
  container.listen(myLedgersProvider, (_, _) {});
  await container.read(myLedgersProvider.future);
  return container;
}

void main() {
  test('지운 고정 지출을 같은 id로 되돌린다', () async {
    final templates = FakeTemplatesRepository();
    final container = await ready(templates);
    final states = recordStates(container, templatesNotifierProvider);

    await container.read(templatesNotifierProvider.notifier).restore(rent);

    expect(templates.restored.single, (ledgerId: 'l1', id: 'rent', uid: 'me'));
    expect(templates.templates, [rent]);
    expect(states, const [TemplatesState(restoring: true), TemplatesState()]);
  });

  test('오프라인이면 되돌리지 못했다고 한 번 알리고 끈다', () async {
    final templates = FakeTemplatesRepository()..offline = true;
    final container = await ready(templates);
    recordStates(container, templatesNotifierProvider);
    final notifier = container.read(templatesNotifierProvider.notifier);

    await notifier.restore(rent);

    expect(
      container.read(templatesNotifierProvider).failure,
      TemplatesFailure.restoreOffline,
    );
    expect(templates.templates, isEmpty);

    notifier.failureShown();
    expect(container.read(templatesNotifierProvider), const TemplatesState());
  });

  test('예상 못 한 오류는 되돌리기 실패로 알린다', () async {
    final templates = FakeTemplatesRepository()..failNextWrite = true;
    final container = await ready(templates);
    recordStates(container, templatesNotifierProvider);

    await container.read(templatesNotifierProvider.notifier).restore(rent);

    expect(
      container.read(templatesNotifierProvider).failure,
      TemplatesFailure.restore,
    );
  });
}
