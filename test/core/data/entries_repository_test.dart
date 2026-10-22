import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/data/entries_repository.dart';

EntryDoc doc(
  String id,
  Map<String, dynamic> data, {
  bool hasPendingWrites = false,
}) => (id: id, data: data, hasPendingWrites: hasPendingWrites);

void main() {
  group('항목 문서 읽기', () {
    test('수입은 누가·제목·금액·받은 날·메모를 읽는다', () {
      final income = incomeFromFirestore('i1', {
        'memberId': 'owner',
        'title': '월급',
        'amount': 3000000,
        'receivedOn': '2026-10-25',
        'memo': '세후',
      });

      expect(income?.id, 'i1');
      expect(income?.memberId, 'owner');
      expect(income?.title, '월급');
      expect(income?.amount, 3000000);
      expect(income?.receivedOn, DateTime(2026, 10, 25));
      expect(income?.memo, '세후');
    });

    test('기본 월 지출은 금액이 비어 있으면 금액 미정으로 읽는다', () {
      for (final data in [
        {'amount': null},
        <String, dynamic>{},
      ]) {
        final expense = plannedExpenseFromFirestore('template-1', {
          'memberId': 'partner',
          'categoryId': 'c1',
          'paymentMethodId': 'p1',
          'title': '관리비',
          ...data,
        });
        expect(expense?.amount, isNull);
        expect(expense?.isPaid, isFalse);
      }
    });

    test('기본 월 지출은 지급한 날이 있으면 지급 완료다', () {
      final expense = plannedExpenseFromFirestore('template-1', {
        'memberId': 'owner',
        'categoryId': 'c1',
        'paymentMethodId': 'p1',
        'title': '대출이자',
        'amount': 0,
        'paidOn': '2026-10-05',
      });

      expect(expense?.amount, 0);
      expect(expense?.paidOn, DateTime(2026, 10, 5));
      expect(expense?.isPaid, isTrue);
    });

    test('추가지출과 카드대금을 읽는다', () {
      final extra = extraExpenseFromFirestore('e1', {
        'memberId': 'owner',
        'paymentMethodId': 'card-1',
        'title': '장보기',
        'amount': 45000,
        'spentOn': '2026-10-03',
      });
      final bill = cardBillFromFirestore('b1', {
        'memberId': 'partner',
        'cardId': 'card-1',
        'amount': 320000,
        'paidOn': '2026-10-15',
      });

      expect(extra?.paymentMethodId, 'card-1');
      expect(extra?.spentOn, DateTime(2026, 10, 3));
      expect(bill?.cardId, 'card-1');
      expect(bill?.amount, 320000);
      expect(bill?.paidOn, DateTime(2026, 10, 15));
    });

    test('계산에 쓰는 값이 없거나 잘못된 문서는 건너뛴다', () {
      const extra = {
        'memberId': 'owner',
        'paymentMethodId': 'p1',
        'title': '장보기',
        'amount': 1000,
      };
      expect(extraExpenseFromFirestore('ok', extra), isNotNull);
      for (final broken in [
        {...extra, 'amount': -1},
        {...extra, 'amount': 10.5},
        {...extra, 'amount': '1000'},
        {...extra, 'amount': null},
        {...extra, 'memberId': null},
        {...extra, 'paymentMethodId': 3},
      ]) {
        expect(
          extraExpenseFromFirestore('e', broken),
          isNull,
          reason: '$broken',
        );
      }
      expect(
        plannedExpenseFromFirestore('p', {
          'memberId': 'owner',
          'categoryId': 'c1',
          'paymentMethodId': 'p1',
          'amount': '미정',
        }),
        isNull,
      );
      expect(
        plannedExpenseFromFirestore('p', {
          'memberId': 'owner',
          'paymentMethodId': 'p1',
          'amount': 1000,
        }),
        isNull,
      );
      expect(incomeFromFirestore('i', {'amount': 1000}), isNull);
      expect(
        cardBillFromFirestore('b', {'memberId': 'owner', 'amount': 1000}),
        isNull,
      );
    });

    test('제목·메모·날짜는 없거나 잘못돼도 항목을 살리고 비워 둔다', () {
      final income = incomeFromFirestore('i1', {
        'memberId': 'owner',
        'amount': 1000,
        'title': 3,
        'memo': false,
        'receivedOn': Timestamp.fromDate(DateTime(2026, 10, 1)),
      });

      expect(income?.title, '');
      expect(income?.memo, isNull);
      expect(income?.receivedOn, isNull);
    });
  });

  group('항목 날짜', () {
    test('날짜는 yyyy-MM-dd 문자열로 적고 그대로 읽는다', () {
      expect(entryDateToFirestore(DateTime(2026, 3, 7, 23, 59)), '2026-03-07');
      expect(entryDateFromFirestore('2026-03-07'), DateTime(2026, 3, 7));
    });

    test('형식이 다르거나 없는 날은 null이다', () {
      for (final value in [
        '2026-02-30',
        '2026-13-01',
        '2026-3-7',
        '2026-03-07T00:00:00',
        '',
        null,
        20260307,
      ]) {
        expect(entryDateFromFirestore(value), isNull, reason: '$value');
      }
    });
  });

  group('휴지통', () {
    test('deletedAt에 값이 있으면 휴지통 항목이다', () {
      expect(
        entryIsTrashed({
          'deletedAt': Timestamp.fromDate(DateTime(2026, 10, 1)),
        }, hasPendingWrites: false),
        isTrue,
      );
      expect(entryIsTrashed({}, hasPendingWrites: false), isFalse);
      expect(
        entryIsTrashed({'deletedAt': null}, hasPendingWrites: false),
        isFalse,
      );
    });

    test('방금 휴지통에 넣어 서버 시간이 아직 null이어도 휴지통으로 본다', () {
      expect(
        entryIsTrashed({'deletedAt': null}, hasPendingWrites: true),
        isTrue,
      );
      // 휴지통과 상관없는 내용을 고치는 중이면 그대로 정상 항목이다.
      expect(entryIsTrashed({'amount': 1}, hasPendingWrites: true), isFalse);
    });

    test('한 달 항목에서 휴지통 항목과 읽을 수 없는 문서를 뺀다', () {
      const owner = {'memberId': 'owner'};
      final trashed = {'deletedAt': Timestamp.fromDate(DateTime(2026, 10, 2))};
      final ledger = monthLedgerFromFirestore(
        incomes: [
          doc('i1', {...owner, 'amount': 1000}),
          doc('i2', {...owner, 'amount': 2000, ...trashed}),
        ],
        planned: [
          doc('t1', {
            ...owner,
            'categoryId': 'c1',
            'paymentMethodId': 'p1',
            'amount': null,
          }),
          doc('t2', {
            ...owner,
            'categoryId': 'c1',
            'paymentMethodId': 'p1',
            'amount': 500,
            'deletedAt': null,
          }, hasPendingWrites: true),
        ],
        extras: [
          doc('e1', {...owner, 'paymentMethodId': 'p1', 'amount': -5}),
        ],
        cardBills: [
          doc('b1', {...owner, 'cardId': 'card-1', 'amount': 300}),
        ],
      );

      expect(ledger.incomes.map((e) => e.id), ['i1']);
      expect(ledger.plannedExpenses.map((e) => e.id), ['t1']);
      expect(ledger.extraExpenses, isEmpty);
      expect(ledger.cardBills.map((e) => e.id), ['b1']);
    });
  });

  group('구독 묶기(combineLatest)', () {
    test('모든 스트림이 한 번씩 값을 낸 뒤부터 묶음을 내고, 하나가 바뀌면 다시 낸다', () async {
      final a = StreamController<int>();
      final b = StreamController<int>();
      final results = <List<int>>[];
      final subscription = combineLatest([
        a.stream,
        b.stream,
      ]).listen(results.add);

      a.add(1);
      await pumpEventQueue();
      expect(results, isEmpty);

      b.add(10);
      await pumpEventQueue();
      a.add(2);
      await pumpEventQueue();

      expect(results, [
        [1, 10],
        [2, 10],
      ]);
      await subscription.cancel();
    });

    test('구독을 끊으면 모든 스트림의 구독을 끊는다', () async {
      var cancelled = 0;
      final streams = [
        for (var i = 0; i < 4; i++)
          StreamController<int>(onCancel: () => cancelled++),
      ];
      final subscription = combineLatest([
        for (final s in streams) s.stream,
      ]).listen((_) {});
      await pumpEventQueue();

      await subscription.cancel();

      expect(cancelled, 4);
    });

    test('오류는 그대로 넘긴다', () async {
      final a = StreamController<int>();
      final b = StreamController<int>();
      final errors = <Object>[];
      final subscription = combineLatest([
        a.stream,
        b.stream,
      ]).listen((_) {}, onError: errors.add);

      b.addError(StateError('permission-denied'));
      await pumpEventQueue();

      expect(errors, [isA<StateError>()]);
      await subscription.cancel();
    });

    test('모든 스트림이 끝나면 함께 끝난다', () async {
      final values = await combineLatest([
        Stream.value(1),
        Stream.value(2),
      ]).toList();

      expect(values, [
        [1, 2],
      ]);
    });
  });
}
