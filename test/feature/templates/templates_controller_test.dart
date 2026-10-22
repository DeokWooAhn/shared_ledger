import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/data/providers.dart';
import 'package:shared_ledger/core/model/auth_user.dart';
import 'package:shared_ledger/core/model/expense_template.dart';
import 'package:shared_ledger/core/model/ledger.dart';
import 'package:shared_ledger/feature/templates/templates_controller.dart';

import '../../support/fakes.dart';
import '../../support/provider_container.dart';

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
    final states = recordStates(container, templatesControllerProvider);

    await container.read(templatesControllerProvider.notifier).restore(rent);

    expect(templates.restored.single, (ledgerId: 'l1', id: 'rent', uid: 'me'));
    expect(templates.templates, [rent]);
    expect(states, const [TemplatesState(restoring: true), TemplatesState()]);
  });

  test('오프라인이면 되돌리지 못했다고 한 번 알리고 끈다', () async {
    final templates = FakeTemplatesRepository()..offline = true;
    final container = await ready(templates);
    recordStates(container, templatesControllerProvider);
    final controller = container.read(templatesControllerProvider.notifier);

    await controller.restore(rent);

    expect(
      container.read(templatesControllerProvider).failure,
      TemplatesFailure.restoreOffline,
    );
    expect(templates.templates, isEmpty);

    controller.failureShown();
    expect(container.read(templatesControllerProvider), const TemplatesState());
  });

  test('예상 못 한 오류는 되돌리기 실패로 알린다', () async {
    final templates = FakeTemplatesRepository()..failNextWrite = true;
    final container = await ready(templates);
    recordStates(container, templatesControllerProvider);

    await container.read(templatesControllerProvider.notifier).restore(rent);

    expect(
      container.read(templatesControllerProvider).failure,
      TemplatesFailure.restore,
    );
  });
}
