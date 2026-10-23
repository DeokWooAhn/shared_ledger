import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/data/entries_repository.dart';
import 'package:shared_ledger/core/model/expense_template.dart';
import 'package:shared_ledger/core/model/ledger_entries.dart';
import 'package:shared_ledger/core/model/year_month.dart';

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

    test('기본 월 지출은 고정 지출에서 옮긴 예정일을 읽고, 잘못된 예정일은 비운다', () {
      const data = {
        'memberId': 'owner',
        'categoryId': 'c1',
        'paymentMethodId': 'p1',
        'title': '관리비',
      };

      expect(
        plannedExpenseFromFirestore('t1', {
          ...data,
          'dueOn': '2026-10-31',
        })?.dueOn,
        DateTime(2026, 10, 31),
      );
      final broken = plannedExpenseFromFirestore('t1', {...data, 'dueOn': 31});
      expect(broken, isNotNull);
      expect(broken?.dueOn, isNull);
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

  group('항목 쓰기 데이터', () {
    final serverTime = FieldValue.serverTimestamp();
    final delete = FieldValue.delete();

    // 종류마다 다 채운 입력값. docs/firestore.md의 항목 표와 같다.
    final drafts = {
      EntryKind.income: EntryDraft(
        kind: EntryKind.income,
        memberId: 'owner',
        amount: 3000000,
        title: '월급',
        date: DateTime(2026, 10, 25),
        memo: '세후',
      ),
      EntryKind.planned: EntryDraft(
        kind: EntryKind.planned,
        memberId: 'partner',
        amount: 200000,
        title: '관리비',
        categoryId: 'c1',
        paymentMethodId: 'p1',
        date: DateTime(2026, 10, 31),
        memo: '10월분',
      ),
      EntryKind.extra: EntryDraft(
        kind: EntryKind.extra,
        memberId: 'owner',
        amount: 186000,
        title: '마트 장보기',
        paymentMethodId: 'card-1',
        date: DateTime(2026, 10, 18),
        memo: '주말',
      ),
      EntryKind.cardBill: EntryDraft(
        kind: EntryKind.cardBill,
        memberId: 'partner',
        amount: 500000,
        cardId: 'card-1',
        date: DateTime(2026, 10, 14),
        memo: '9월 사용분',
      ),
    };

    test('새 항목 문서는 종류마다 보안 규칙(entryFields)이 받는 필드만 담는다', () {
      const audit = {'createdBy', 'updatedBy', 'createdAt', 'updatedAt'};
      final expected = {
        EntryKind.income: {'memberId', 'amount', 'title', 'receivedOn', 'memo'},
        EntryKind.planned: {
          'memberId',
          'amount',
          'title',
          'categoryId',
          'paymentMethodId',
          'paidOn',
          'memo',
        },
        EntryKind.extra: {
          'memberId',
          'amount',
          'title',
          'paymentMethodId',
          'spentOn',
          'memo',
        },
        EntryKind.cardBill: {'memberId', 'amount', 'cardId', 'paidOn', 'memo'},
      };
      for (final MapEntry(key: kind, value: draft) in drafts.entries) {
        final data = newEntryData(draft, uid: 'me');
        expect(data.keys.toSet(), {
          ...?expected[kind],
          ...audit,
        }, reason: '$kind');
        expect(data['createdBy'], 'me');
        expect(data['updatedBy'], 'me');
        expect(data['createdAt'], serverTime);
        expect(data['updatedAt'], serverTime);
      }
    });

    test('새 기본 월 지출 문서에 값을 그대로 담고, 날짜는 yyyy-MM-dd로 적는다', () {
      final data = newEntryData(drafts[EntryKind.planned]!, uid: 'me');

      expect(data['memberId'], 'partner');
      expect(data['amount'], 200000);
      expect(data['title'], '관리비');
      expect(data['categoryId'], 'c1');
      expect(data['paymentMethodId'], 'p1');
      expect(data['paidOn'], '2026-10-31');
      expect(data['memo'], '10월분');
    });

    test('비어 있는 선택 칸(금액 미정·날짜·메모)은 새 문서에 넣지 않는다', () {
      const draft = EntryDraft(
        kind: EntryKind.planned,
        memberId: 'owner',
        title: '관리비',
        categoryId: 'c1',
        paymentMethodId: 'p1',
        memo: '   ',
      );

      final data = newEntryData(draft, uid: 'me');

      expect(data.keys, isNot(contains('amount')));
      expect(data.keys, isNot(contains('paidOn')));
      expect(data.keys, isNot(contains('memo')));
    });

    test('고정 지출로 만든 기본 월 지출은 그달 예정일을 담고 지급 전·메모 없이 만든다', () {
      const template = ExpenseTemplate(
        id: 't-rent',
        title: '관리비',
        categoryId: 'c1',
        paymentMethodId: 'p1',
        memberId: 'partner',
        dueDay: lastDueDay,
      );

      final data = newEntryData(
        template.draftFor(const YearMonth(2026, 2)),
        uid: 'me',
      );

      // 금액 미정이라 amount가 없다. 규칙의 planned 필드(entryFields)에 dueOn이 있다.
      expect(data.keys.toSet(), {
        'memberId',
        'title',
        'categoryId',
        'paymentMethodId',
        'dueOn',
        'createdBy',
        'updatedBy',
        'createdAt',
        'updatedAt',
      });
      expect(data['dueOn'], '2026-02-28');
      expect(data['memberId'], 'partner');
    });

    test('고칠 때 예정일이 있으면 그대로 다시 쓴다', () {
      final data = entryUpdateData(
        EntryDraft(
          kind: EntryKind.planned,
          memberId: 'owner',
          title: '관리비',
          categoryId: 'c1',
          paymentMethodId: 'p1',
          date: DateTime(2026, 10, 30),
          dueOn: DateTime(2026, 10, 31),
        ),
        uid: 'me',
      );

      expect(data['dueOn'], '2026-10-31');
      expect(data['paidOn'], '2026-10-30');
    });

    test('예정일은 기본 월 지출에만 쓴다', () {
      final data = newEntryData(
        EntryDraft(
          kind: EntryKind.extra,
          memberId: 'owner',
          amount: 1000,
          title: '간식',
          paymentMethodId: 'p1',
          dueOn: DateTime(2026, 10, 31),
        ),
        uid: 'me',
      );

      expect(data.keys, isNot(contains('dueOn')));
    });

    test('제목·메모는 앞뒤 공백을 뺀다', () {
      const draft = EntryDraft(
        kind: EntryKind.extra,
        memberId: 'owner',
        amount: 1000,
        title: '  간식 ',
        paymentMethodId: 'p1',
        memo: ' 편의점 ',
      );

      final data = newEntryData(draft, uid: 'me');

      expect(data['title'], '간식');
      expect(data['memo'], '편의점');
    });

    test('고칠 때는 그 종류의 칸을 모두 다시 쓰고, 비운 칸은 필드를 지운다', () {
      const draft = EntryDraft(
        kind: EntryKind.planned,
        memberId: 'owner',
        title: '관리비',
        categoryId: 'c1',
        paymentMethodId: 'p1',
      );

      final data = entryUpdateData(draft, uid: 'partner-uid');

      // 만든 사람·시간은 건드리지 않는다(규칙의 updatedNow).
      expect(data.keys.toSet(), {
        'memberId',
        'amount',
        'title',
        'categoryId',
        'paymentMethodId',
        'paidOn',
        'dueOn',
        'memo',
        'updatedBy',
        'updatedAt',
      });
      expect(data['amount'], delete);
      expect(data['paidOn'], delete);
      expect(data['dueOn'], delete);
      expect(data['memo'], delete);
      expect(data['updatedBy'], 'partner-uid');
      expect(data['updatedAt'], serverTime);
    });

    test('카드대금을 고칠 때는 제목·결제수단 칸을 쓰지 않는다', () {
      final data = entryUpdateData(drafts[EntryKind.cardBill]!, uid: 'me');

      expect(data.keys, containsAll(['cardId', 'paidOn']));
      expect(data.keys, isNot(contains('title')));
      expect(data.keys, isNot(contains('paymentMethodId')));
    });

    test('휴지통에 넣을 때는 deletedAt을 서버 시간으로, 자동으로 지울 때를 시각으로 적는다', () {
      final purgeAt = DateTime.utc(2026, 11, 14, 9);
      expect(trashEntryUpdate(uid: 'me', purgeAt: purgeAt), {
        'deletedAt': serverTime,
        'purgeAt': Timestamp.fromDate(purgeAt),
        'updatedBy': 'me',
        'updatedAt': serverTime,
      });
    });

    test('자동으로 지우지 않는 항목은 휴지통에 넣을 때 purgeAt을 적지 않는다', () {
      expect(trashEntryUpdate(uid: 'me'), {
        'deletedAt': serverTime,
        'updatedBy': 'me',
        'updatedAt': serverTime,
      });
    });

    test('꺼낼 때는 deletedAt과 purgeAt 필드를 지운다', () {
      expect(restoreEntryUpdate(uid: 'me'), {
        'deletedAt': delete,
        'purgeAt': delete,
        'updatedBy': 'me',
        'updatedAt': serverTime,
      });
    });

    test('종류마다 컬렉션 이름이 정해져 있다', () {
      expect(EntryKind.values.map(entryCollection), [
        'incomes',
        'planned',
        'extras',
        'cardBills',
      ]);
    });

    test('쓴 문서를 다시 읽으면 같은 값이다', () {
      for (final draft in drafts.values) {
        final data = {
          for (final MapEntry(:key, :value) in newEntryData(
            draft,
            uid: 'me',
          ).entries)
            if (value is! FieldValue) key: value,
        };
        final entry = switch (draft.kind) {
          EntryKind.income => incomeFromFirestore('id', data),
          EntryKind.planned => plannedExpenseFromFirestore('id', data),
          EntryKind.extra => extraExpenseFromFirestore('id', data),
          EntryKind.cardBill => cardBillFromFirestore('id', data),
        };
        expect(entry, isNotNull, reason: '${draft.kind}');
        expect(EntryDraft.of(entry!), draft, reason: '${draft.kind}');
      }
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

    test('기본 월 지출 문서 id는 휴지통 항목과 읽을 수 없는 문서까지 모은다', () {
      // 고정 지출로 채울 때 이 id의 문서를 다시 만들지 않는다.
      const planned = {
        'memberId': 'owner',
        'categoryId': 'c1',
        'paymentMethodId': 'p1',
      };
      final ledger = monthLedgerFromFirestore(
        incomes: const [],
        planned: [
          doc('t-live', planned),
          doc('t-trashed', {
            ...planned,
            'deletedAt': Timestamp.fromDate(DateTime(2026, 10, 2)),
          }),
          doc('t-broken', {...planned, 'amount': -1}),
        ],
        extras: const [],
        cardBills: const [],
      );

      expect(ledger.plannedExpenses.map((e) => e.id), ['t-live']);
      expect(ledger.plannedIds, {'t-live', 't-trashed', 't-broken'});
    });

    test('휴지통 항목은 넣은 때·자동으로 지울 때와 함께 따로 모은다', () {
      const owner = {'memberId': 'owner'};
      final deletedAt = DateTime(2026, 10, 2, 9);
      final purgeAt = DateTime(2026, 11, 1, 9);
      final ledger = monthLedgerFromFirestore(
        incomes: [
          doc('i1', {...owner, 'amount': 1000}),
        ],
        planned: const [],
        extras: [
          doc('e1', {
            ...owner,
            'title': '점심',
            'paymentMethodId': 'p1',
            'amount': 12000,
            'deletedAt': Timestamp.fromDate(deletedAt),
            'purgeAt': Timestamp.fromDate(purgeAt),
          }),
        ],
        cardBills: [
          doc('b1', {
            ...owner,
            'cardId': 'card-1',
            'amount': 300,
            'deletedAt': Timestamp.fromDate(deletedAt),
          }),
        ],
      );

      expect(ledger.extraExpenses, isEmpty);
      expect(ledger.trashed.map((t) => (t.entry.kind, t.entry.id, t.purgeAt)), [
        (EntryKind.extra, 'e1', purgeAt),
        (EntryKind.cardBill, 'b1', null),
      ]);
      expect(ledger.trashed.first.deletedAt, deletedAt);
      expect(ledger.trashed.first.entry.amount, 12000);
    });

    test('방금 휴지통에 넣어 서버 시간이 없는 항목도 넣은 때 없이 휴지통에 모으고, 읽을 수 없는 문서는 뺀다', () {
      const extra = {'memberId': 'owner', 'paymentMethodId': 'p1'};
      final ledger = monthLedgerFromFirestore(
        incomes: const [],
        planned: const [],
        extras: [
          doc('pending', {
            ...extra,
            'amount': 1000,
            'deletedAt': null,
          }, hasPendingWrites: true),
          doc('broken', {
            ...extra,
            'amount': -1,
            'deletedAt': Timestamp.fromDate(DateTime(2026, 10, 2)),
          }),
        ],
        cardBills: const [],
      );

      expect(ledger.trashed.map((t) => t.entry.id), ['pending']);
      expect(ledger.trashed.single.deletedAt, isNull);
    });

    test('종류에 맞는 변환으로 항목 문서를 읽는다', () {
      const data = {'memberId': 'owner', 'cardId': 'card-1', 'amount': 300};
      expect(
        entryFromFirestore(EntryKind.cardBill, 'b1', data),
        isA<CardBill>(),
      );
      // 추가지출은 결제수단이 있어야 해서 카드대금 문서로는 읽지 못한다.
      expect(entryFromFirestore(EntryKind.extra, 'b1', data), isNull);
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
