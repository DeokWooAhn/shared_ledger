import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/data/templates/firestore_templates_repository.dart';
import 'package:shared_ledger/domain/model/expense_template.dart';
import 'package:shared_ledger/domain/model/ledger_entries.dart';
import 'package:shared_ledger/domain/model/year_month.dart';

void main() {
  final serverTime = FieldValue.serverTimestamp();
  final delete = FieldValue.delete();

  const draft = TemplateDraft(
    memberId: 'partner',
    title: '  관리비 ',
    amount: 200000,
    categoryId: 'c1',
    paymentMethodId: 'p1',
    dueDay: lastDueDay,
  );

  group('고정 지출 쓰기 데이터', () {
    test('새 문서는 보안 규칙(validTemplate·createdNow)이 받는 필드만 담는다', () {
      final data = newTemplateData(draft, uid: 'me');

      expect(data.keys.toSet(), {
        'title',
        'amount',
        'categoryId',
        'paymentMethodId',
        'memberId',
        'dueDay',
        'createdBy',
        'updatedBy',
        'createdAt',
        'updatedAt',
      });
      expect(data['title'], '관리비');
      expect(data['amount'], 200000);
      expect(data['categoryId'], 'c1');
      expect(data['paymentMethodId'], 'p1');
      expect(data['memberId'], 'partner');
      expect(data['dueDay'], 31);
      expect(data['createdBy'], 'me');
      expect(data['updatedBy'], 'me');
      expect(data['createdAt'], serverTime);
      expect(data['updatedAt'], serverTime);
    });

    test('고정 수입은 kind를 income으로 적고 분류·결제수단은 넣지 않는다', () {
      const salary = TemplateDraft(
        kind: EntryKind.fixedIncome,
        memberId: 'owner',
        title: '월급',
        amount: 3000000,
        dueDay: 25,
      );

      final data = newTemplateData(salary, uid: 'me');

      expect(data.keys.toSet(), {
        'kind',
        'title',
        'amount',
        'memberId',
        'dueDay',
        'createdBy',
        'updatedBy',
        'createdAt',
        'updatedAt',
      });
      expect(data['kind'], 'income');
      // 고칠 때는 종류를 쓰지 않는다(규칙의 keepsKind가 막는다).
      expect(
        templateUpdateData(salary, uid: 'me').keys,
        isNot(contains('kind')),
      );
    });

    test('금액 미정이면 새 문서에 금액을 넣지 않는다', () {
      const unpriced = TemplateDraft(
        memberId: 'owner',
        title: '관리비',
        categoryId: 'c1',
        paymentMethodId: 'p1',
        dueDay: 25,
      );

      expect(
        newTemplateData(unpriced, uid: 'me').keys,
        isNot(contains('amount')),
      );
    });

    test('고칠 때는 모든 칸을 다시 쓰고, 비운 금액은 필드를 지우고, 만든 기록은 건드리지 않는다', () {
      const unpriced = TemplateDraft(
        memberId: 'owner',
        title: '관리비',
        categoryId: 'c1',
        paymentMethodId: 'p1',
        dueDay: 25,
      );

      final data = templateUpdateData(unpriced, uid: 'partner-uid');

      expect(data.keys.toSet(), {
        'title',
        'amount',
        'categoryId',
        'paymentMethodId',
        'memberId',
        'dueDay',
        'updatedBy',
        'updatedAt',
      });
      expect(data['amount'], delete);
      expect(data['dueDay'], 25);
      expect(data['updatedBy'], 'partner-uid');
      expect(data['updatedAt'], serverTime);
    });
  });

  group('뒤 달의 고정 지출 항목', () {
    const draft = TemplateDraft(
      memberId: 'partner',
      title: ' 관리비 ',
      amount: 200000,
      categoryId: 'c-living',
      paymentMethodId: 'p-account',
      dueDay: 30,
    );

    test('반복 설정으로 지급 전 항목을 만들고, 그달에 없는 예정일은 말일로 맞춘다', () {
      final entry = laterEntryDraft(draft, const YearMonth(2027, 2));

      expect(entry.kind, EntryKind.planned);
      expect(entry.title, '관리비');
      expect(entry.amount, 200000);
      expect(entry.date, isNull);
      expect(entry.dueOn, DateTime(2027, 2, 28));
    });

    test('고정 수입 반복 설정이면 받기 전 고정 수입 항목을 만든다', () {
      final entry = laterEntryDraft(
        const TemplateDraft(
          kind: EntryKind.fixedIncome,
          memberId: 'owner',
          title: '월급',
          amount: 3000000,
          dueDay: 25,
        ),
        const YearMonth(2026, 11),
      );

      expect(entry.kind, EntryKind.fixedIncome);
      expect(entry.amount, 3000000);
      expect(entry.date, isNull);
      expect(entry.dueOn, DateTime(2026, 11, 25));
      expect(entryProblemsOf(entry), isEmpty);
    });

    test('맞출 때는 반복 설정이 정하는 칸만 쓰고, 금액은 바뀌었을 때만 쓴다', () {
      final same = laterEntryUpdate(
        draft,
        const YearMonth(2026, 11),
        uid: 'me',
        withAmount: false,
      );
      expect(same.keys, {
        'title',
        'memberId',
        'categoryId',
        'paymentMethodId',
        'dueOn',
        'updatedBy',
        'updatedAt',
      });
      expect(same['title'], '관리비');
      expect(same['dueOn'], '2026-11-30');
      expect(same['updatedAt'], FieldValue.serverTimestamp());

      final changed = laterEntryUpdate(
        draft,
        const YearMonth(2026, 11),
        uid: 'me',
        withAmount: true,
      );
      expect(changed['amount'], 200000);
      // 금액을 비우면(금액 미정) 필드를 지운다.
      final cleared = laterEntryUpdate(
        const TemplateDraft(
          memberId: 'owner',
          title: '관리비',
          categoryId: 'c-living',
          paymentMethodId: 'p-account',
          dueDay: 25,
        ),
        const YearMonth(2026, 11),
        uid: 'me',
        withAmount: true,
      );
      expect(cleared['amount'], FieldValue.delete());
    });
  });

  group('고정 지출 문서 읽기', () {
    const valid = {
      'title': '관리비',
      'amount': 200000,
      'categoryId': 'c1',
      'paymentMethodId': 'p1',
      'memberId': 'partner',
      'dueDay': 31,
    };

    test('모든 값을 읽고, 금액이 비어 있으면 금액 미정이다', () {
      expect(
        templateFromFirestore('t1', valid),
        const ExpenseTemplate(
          id: 't1',
          title: '관리비',
          amount: 200000,
          categoryId: 'c1',
          paymentMethodId: 'p1',
          memberId: 'partner',
          dueDay: lastDueDay,
        ),
      );
      final unpriced = Map<String, dynamic>.of(valid)..remove('amount');
      expect(templateFromFirestore('t1', unpriced)?.amount, isNull);
      expect(
        templateFromFirestore('t1', {...valid, 'amount': null}),
        isNotNull,
      );
    });

    test('그달 고정 지출을 만드는 데 쓰는 값이 없거나 잘못된 문서는 건너뛴다', () {
      for (final broken in [
        {...valid, 'dueDay': 0},
        {...valid, 'dueDay': 32},
        {...valid, 'dueDay': '25'},
        {...valid, 'dueDay': null},
        {...valid, 'amount': -1},
        {...valid, 'amount': 10.5},
        {...valid, 'memberId': null},
        {...valid, 'categoryId': 3},
        {...valid, 'paymentMethodId': null},
      ]) {
        expect(templateFromFirestore('t', broken), isNull, reason: '$broken');
      }
    });

    test('제목이 없거나 잘못돼도 빈 제목으로 살린다', () {
      expect(templateFromFirestore('t', {...valid, 'title': 3})?.title, '');
    });

    test('kind가 income이면 고정 수입이고, 분류·결제수단 없이 금액이 있어야 읽는다', () {
      const salary = {
        'kind': 'income',
        'title': '월급',
        'amount': 3000000,
        'memberId': 'owner',
        'dueDay': 25,
      };

      expect(
        templateFromFirestore('t2', salary),
        const ExpenseTemplate(
          id: 't2',
          kind: EntryKind.fixedIncome,
          title: '월급',
          amount: 3000000,
          memberId: 'owner',
          dueDay: 25,
        ),
      );
      expect(templateKindFromFirestore(salary), EntryKind.fixedIncome);
      expect(templateKindFromFirestore(valid), EntryKind.planned);
      final unpriced = Map<String, dynamic>.of(salary)..remove('amount');
      expect(templateFromFirestore('t2', unpriced), isNull);
    });
  });
}
