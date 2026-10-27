import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/model/expense_template.dart';
import 'package:shared_ledger/domain/repository/templates_repository.dart';
import 'package:shared_ledger/domain/usecase/template/template_use_cases.dart';

import '../../../../testing/fakes.dart';

const rent = ExpenseTemplate(
  id: 'template-rent',
  title: '관리비',
  categoryId: 'c-living',
  paymentMethodId: 'p-account',
  memberId: 'owner',
  dueDay: 25,
);

const phoneDraft = TemplateDraft(
  memberId: 'partner',
  title: '통신비',
  amount: 50000,
  categoryId: 'c-living',
  paymentMethodId: 'p-account',
  dueDay: 10,
);

void main() {
  test('그 가계부의 고정 지출을 지켜본다', () async {
    final templates = FakeTemplatesRepository([rent]);

    expect(await TemplateUseCases(templates).watchTemplates('l1').first, [
      rent,
    ]);
    expect(templates.watched, ['l1']);
  });

  group('저장', () {
    test('id가 없으면 새로 더하고, 있으면 그 고정 지출을 고친다', () async {
      final templates = FakeTemplatesRepository([rent]);
      final useCases = TemplateUseCases(templates);

      expect(
        await useCases.saveTemplate(
          ledgerId: 'l1',
          draft: phoneDraft,
          uid: 'me',
        ),
        isEmpty,
      );
      await useCases.saveTemplate(
        ledgerId: 'l1',
        id: 'template-rent',
        draft: phoneDraft,
        uid: 'me',
      );

      expect(templates.added, [(ledgerId: 'l1', draft: phoneDraft, uid: 'me')]);
      expect(templates.updated, [
        (ledgerId: 'l1', id: 'template-rent', draft: phoneDraft, uid: 'me'),
      ]);
    });

    test('입력에 문제가 있으면 쓰지 않고 문제를 돌려준다', () async {
      final templates = FakeTemplatesRepository();

      final problems = await TemplateUseCases(templates).saveTemplate(
        ledgerId: 'l1',
        draft: const TemplateDraft(memberId: 'owner', title: '  '),
        uid: 'me',
      );

      expect(problems, {
        TemplateProblem.titleMissing,
        TemplateProblem.categoryMissing,
        TemplateProblem.paymentMethodMissing,
        TemplateProblem.dueDayMissing,
      });
      expect(templates.added, isEmpty);
    });

    test('연결이 없으면 저장소의 실패를 그대로 던진다', () async {
      final useCases = TemplateUseCases(
        FakeTemplatesRepository()..offline = true,
      );

      await expectLater(
        useCases.saveTemplate(ledgerId: 'l1', draft: phoneDraft, uid: 'me'),
        throwsA(
          isA<TemplateWriteException>().having(
            (e) => e.reason,
            'reason',
            TemplateWriteFailure.offline,
          ),
        ),
      );
    });
  });

  test('지운 고정 지출을 같은 id로 되돌린다', () async {
    final templates = FakeTemplatesRepository([rent]);
    final useCases = TemplateUseCases(templates);

    await useCases.deleteTemplate(
      ledgerId: 'l1',
      id: 'template-rent',
      uid: 'me',
    );
    expect(templates.templates, isEmpty);
    await useCases.restoreTemplate(ledgerId: 'l1', template: rent, uid: 'me');

    expect(templates.deleted, [
      (ledgerId: 'l1', id: 'template-rent', uid: 'me'),
    ]);
    expect(templates.restored, templates.deleted);
    expect(templates.templates, [rent]);
  });
}
