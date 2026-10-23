import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/data/providers.dart';
import 'package:shared_ledger/core/model/auth_user.dart';
import 'package:shared_ledger/core/model/expense_template.dart';
import 'package:shared_ledger/core/model/ledger.dart';
import 'package:shared_ledger/core/model/member.dart';
import 'package:shared_ledger/feature/templates/template_form_controller.dart';

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

/// 로그인하고 가계부 목록까지 받은 컨테이너. 컨트롤러가 내 uid와 지금 가계부를 바로 읽을 수 있다.
Future<ProviderContainer> ready({
  FakeTemplatesRepository? templates,
  Ledger ledger = mine,
}) async {
  final container = createContainer(
    auth: FakeAuthRepository(signedIn: me),
    ledgers: FakeLedgerRepository([ledger]),
    templates: templates,
  );
  await loadSignedInUser(container);
  container.listen(myLedgersProvider, (_, _) {});
  await container.read(myLedgersProvider.future);
  return container;
}

const addArgs = TemplateFormArgs.add();
const editArgs = TemplateFormArgs.edit(rent);

/// [args] 화면의 컨트롤러를 살려 두고 지나간 상태를 기록한다.
(TemplateFormController, List<TemplateFormState>) controllerOf(
  ProviderContainer container,
  TemplateFormArgs args,
) {
  final states = recordStates(container, templateFormControllerProvider(args));
  return (
    container.read(templateFormControllerProvider(args).notifier),
    states,
  );
}

/// 꼭 필요한 칸(분류·결제수단·예정일)을 다 고른다.
void fillChoices(TemplateFormController controller) => controller
  ..selectCategory('c-spending')
  ..selectPaymentMethod('p-account')
  ..selectDueDay(25);

void main() {
  group('처음 값', () {
    test('새 고정 지출은 누가가 나이고, 분류·결제수단·예정일은 비어 있다', () async {
      final container = await ready();

      expect(
        container.read(templateFormControllerProvider(addArgs)),
        const TemplateFormState(memberId: 'owner'),
      );
    });

    test('초대로 들어온 사람의 새 고정 지출은 상대 자리로 시작한다', () async {
      final container = await ready(
        ledger: const Ledger(
          id: 'l1',
          name: '우리 가계부',
          ownerUid: 'partner-uid',
          roles: {'me': MemberRole.editor},
        ),
      );

      expect(
        container.read(templateFormControllerProvider(addArgs)).memberId,
        'partner',
      );
    });

    test('고치기 화면은 고정 지출의 값으로 시작한다', () async {
      final container = await ready();

      expect(
        container.read(templateFormControllerProvider(editArgs)),
        const TemplateFormState(
          memberId: 'partner',
          categoryId: 'c-spending',
          paymentMethodId: 'p-account',
          dueDay: lastDueDay,
        ),
      );
    });
  });

  group('입력 검사', () {
    test('내용·분류·결제수단·예정일이 비면 문제로 알리고 저장하지 않는다', () async {
      final templates = FakeTemplatesRepository();
      final container = await ready(templates: templates);
      final (controller, _) = controllerOf(container, addArgs);

      await controller.save(amount: '', title: '  ');

      expect(container.read(templateFormControllerProvider(addArgs)).problems, {
        TemplateProblem.titleMissing,
        TemplateProblem.categoryMissing,
        TemplateProblem.paymentMethodMissing,
        TemplateProblem.dueDayMissing,
      });
      expect(templates.added, isEmpty);
    });

    test('내용은 40자까지 받는다', () {
      TemplateDraft draft(String title) => TemplateDraft(
        memberId: 'owner',
        title: title,
        categoryId: 'c',
        paymentMethodId: 'p',
        dueDay: 1,
      );

      expect(templateProblemsOf(draft('가' * 40)), isEmpty);
      expect(templateProblemsOf(draft('가' * 41)), {
        TemplateProblem.titleTooLong,
      });
    });

    test('고르거나 글자를 고치면 그 칸의 문제만 지운다', () async {
      final container = await ready();
      final (controller, _) = controllerOf(container, addArgs);
      await controller.save(amount: '', title: '');

      controller
        ..selectCategory('c-spending')
        ..selectDueDay(lastDueDay)
        ..titleEdited();

      final state = container.read(templateFormControllerProvider(addArgs));
      expect(state.problems, {TemplateProblem.paymentMethodMissing});
      expect(state.dueDay, lastDueDay);
    });

    test('예정일은 1~31만 받는다', () async {
      final container = await ready();
      final (controller, _) = controllerOf(container, addArgs);

      controller
        ..selectDueDay(0)
        ..selectDueDay(32);
      expect(
        container.read(templateFormControllerProvider(addArgs)).dueDay,
        isNull,
      );

      controller.selectDueDay(1);
      expect(container.read(templateFormControllerProvider(addArgs)).dueDay, 1);
    });
  });

  group('저장', () {
    test('새 고정 지출을 더하고, 금액을 비우면 금액 미정으로 저장한 뒤 닫힌다', () async {
      final templates = FakeTemplatesRepository();
      final container = await ready(templates: templates);
      final (controller, states) = controllerOf(container, addArgs);
      fillChoices(controller);
      controller.selectMember(MemberSlot.partner);

      await controller.save(amount: '', title: ' 관리비 ');

      expect(templates.added.single.ledgerId, 'l1');
      expect(templates.added.single.uid, 'me');
      expect(
        templates.added.single.draft,
        const TemplateDraft(
          memberId: 'partner',
          title: '관리비',
          categoryId: 'c-spending',
          paymentMethodId: 'p-account',
          dueDay: 25,
        ),
      );
      // 저장 중 → 닫힘 순서로 지나간다.
      expect(states[states.length - 2].pending, TemplateFormAction.save);
      expect(states.last.outcome, TemplateFormOutcome.saved);
    });

    test('고치기는 같은 id의 고정 지출을 새 값으로 바꾼다', () async {
      final templates = FakeTemplatesRepository(const [rent]);
      final container = await ready(templates: templates);
      final (controller, states) = controllerOf(container, editArgs);
      controller.selectDueDay(1);

      await controller.save(amount: '210,000', title: '관리비');

      expect(templates.updated.single.id, 'rent');
      expect(templates.updated.single.draft.amount, 210000);
      expect(templates.updated.single.draft.dueDay, 1);
      expect(states.last.outcome, TemplateFormOutcome.saved);
    });

    test('오프라인이면 저장하지 않고 연결 안내를 한 번 띄운 뒤 끈다', () async {
      final templates = FakeTemplatesRepository()..offline = true;
      final container = await ready(templates: templates);
      final (controller, _) = controllerOf(container, addArgs);
      fillChoices(controller);

      await controller.save(amount: '1,000', title: '보험');

      var state = container.read(templateFormControllerProvider(addArgs));
      expect(state.failure, TemplateFormFailure.offline);
      expect(state.outcome, isNull);
      expect(state.busy, isFalse);

      controller.failureShown();
      state = container.read(templateFormControllerProvider(addArgs));
      expect(state.failure, isNull);
    });

    test('그사이 지워진 고정 지출을 고치면 사라졌다고 알린다', () async {
      final container = await ready(templates: FakeTemplatesRepository());
      final (controller, _) = controllerOf(container, editArgs);

      await controller.save(amount: '', title: '관리비');

      expect(
        container.read(templateFormControllerProvider(editArgs)).failure,
        TemplateFormFailure.gone,
      );
    });

    test('예상 못 한 오류는 저장 실패로 알린다', () async {
      final templates = FakeTemplatesRepository()..failNextWrite = true;
      final container = await ready(templates: templates);
      final (controller, _) = controllerOf(container, addArgs);
      fillChoices(controller);

      await controller.save(amount: '', title: '관리비');

      expect(
        container.read(templateFormControllerProvider(addArgs)).failure,
        TemplateFormFailure.save,
      );
    });

    test('저장 중에 두 번 눌러도 한 번만 저장한다', () async {
      final templates = FakeTemplatesRepository();
      final container = await ready(templates: templates);
      final (controller, _) = controllerOf(container, addArgs);
      fillChoices(controller);

      await Future.wait([
        controller.save(amount: '', title: '관리비'),
        controller.save(amount: '', title: '관리비'),
      ]);

      expect(templates.added, hasLength(1));
    });
  });

  group('삭제', () {
    test('고치는 고정 지출을 지우고 지웠다는 결과로 닫힌다', () async {
      final templates = FakeTemplatesRepository(const [rent]);
      final container = await ready(templates: templates);
      final (controller, states) = controllerOf(container, editArgs);

      await controller.delete();

      expect(templates.deleted.single, (ledgerId: 'l1', id: 'rent', uid: 'me'));
      expect(templates.templates, isEmpty);
      expect(states.last.outcome, TemplateFormOutcome.deleted);
    });

    test('새 고정 지출 화면에서는 지울 것이 없다', () async {
      final templates = FakeTemplatesRepository(const [rent]);
      final container = await ready(templates: templates);
      final (controller, _) = controllerOf(container, addArgs);

      await controller.delete();

      expect(templates.deleted, isEmpty);
    });

    test('오프라인이면 지우지 않고 알린다', () async {
      final templates = FakeTemplatesRepository(const [rent])..offline = true;
      final container = await ready(templates: templates);
      final (controller, _) = controllerOf(container, editArgs);

      await controller.delete();

      final state = container.read(templateFormControllerProvider(editArgs));
      expect(state.failure, TemplateFormFailure.offline);
      expect(templates.templates, [rent]);
    });
  });
}
