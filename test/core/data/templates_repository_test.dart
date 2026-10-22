import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/data/templates_repository.dart';
import 'package:shared_ledger/core/model/expense_template.dart';

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

    test('그달 기본 월 지출을 만드는 데 쓰는 값이 없거나 잘못된 문서는 건너뛴다', () {
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
  });
}
