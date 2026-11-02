import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/data/activity/firestore_activity_repository.dart';
import 'package:shared_ledger/domain/activity/activity_summary.dart';
import 'package:shared_ledger/domain/model/activity.dart';
import 'package:shared_ledger/domain/model/expense_template.dart';
import 'package:shared_ledger/domain/model/ledger_entries.dart';
import 'package:shared_ledger/domain/model/payment_method.dart';
import 'package:shared_ledger/domain/model/year_month.dart';

const october = YearMonth(2026, 10);

const lunch = EntryDraft(
  kind: EntryKind.extra,
  memberId: 'owner',
  title: '점심',
  amount: 12000,
  paymentMethodId: 'p-card',
);

const rent = TemplateDraft(
  memberId: 'owner',
  title: '월세',
  amount: 500000,
  categoryId: 'c1',
  paymentMethodId: 'p1',
  dueDay: 25,
);

void main() {
  group('변경 기록 쓰기 데이터', () {
    test('보안 규칙(validActivity)이 받는 필드만 담고, 1년 뒤 지워지게 한다', () {
      final now = DateTime.utc(2026, 10, 15, 9);
      final data = newActivityData(
        const ActivityDraft(
          ActivityAction.entryCreate,
          "10월 추가 지출 '점심' 12,000원",
        ),
        uid: 'me',
        now: now,
      );

      expect(data.keys.toSet(), {
        'actorUid',
        'at',
        'action',
        'summary',
        'expireAt',
      });
      expect(data['actorUid'], 'me');
      expect(data['at'], FieldValue.serverTimestamp());
      expect(data['action'], 'entry.create');
      expect(data['summary'], "10월 추가 지출 '점심' 12,000원");
      expect(
        data['expireAt'],
        Timestamp.fromDate(DateTime.utc(2027, 10, 15, 9)),
      );
    });

    test('동작 값은 규칙의 형식(영문.영문, 40자까지)이고 서로 겹치지 않는다', () {
      final pattern = RegExp(r'^[a-z][a-zA-Z]*[.][a-z][a-zA-Z]*$');
      for (final action in ActivityAction.values) {
        expect(pattern.hasMatch(action.code), isTrue, reason: action.code);
        expect(action.code.length, lessThanOrEqualTo(40));
      }
      expect(
        ActivityAction.values.map((a) => a.code).toSet(),
        hasLength(ActivityAction.values.length),
      );
    });

    test('요약은 규칙이 받는 200자로 자르고, 이모지를 반쪽으로 자르지 않는다', () {
      expect(clampActivitySummary('가' * 200), '가' * 200);
      expect(clampActivitySummary('가' * 201), '${'가' * 199}…');
      final emoji = clampActivitySummary('${'가' * 198}😀😀');
      expect(emoji, '${'가' * 198}…');
      expect(emoji.length, lessThanOrEqualTo(activitySummaryMaxLength));
    });
  });

  group('변경 기록 읽기', () {
    test('바꾼 사람·동작·요약·시간을 읽는다', () {
      final at = DateTime(2026, 10, 15, 8, 40);
      final activity = activityFromFirestore('a1', {
        'actorUid': 'partner-uid',
        'at': Timestamp.fromDate(at),
        'action': 'entry.trash',
        'summary': "10월 추가 지출 '점심' 12,000원",
        'expireAt': Timestamp.fromDate(DateTime(2027, 10, 15)),
      });

      expect(
        activity,
        Activity(
          id: 'a1',
          actorUid: 'partner-uid',
          action: ActivityAction.entryTrash,
          summary: "10월 추가 지출 '점심' 12,000원",
          at: at,
        ),
      );
    });

    test('모르는 동작과 서버에 닿기 전의 시간은 비워 두고 기록은 살린다', () {
      final activity = activityFromFirestore('a1', {
        'actorUid': 'me',
        'at': null,
        'action': 'budget.create',
        'summary': '새 기능',
      });

      expect(activity?.action, isNull);
      expect(activity?.at, isNull);
      expect(activity?.summary, '새 기능');
    });

    test('바꾼 사람이나 요약이 없으면 건너뛴다', () {
      expect(activityFromFirestore('a1', {'summary': '요약'}), isNull);
      expect(activityFromFirestore('a1', {'actorUid': 'me'}), isNull);
      expect(
        activityFromFirestore('a1', {'actorUid': 1, 'summary': '요약'}),
        isNull,
      );
    });
  });

  group('항목 기록 요약', () {
    test('더하면 달·종류·제목·금액을 적는다', () {
      expect(
        entryActivity(
          ActivityAction.entryCreate,
          month: october,
          kind: EntryKind.extra,
          entry: lunch,
        ),
        const ActivityDraft(
          ActivityAction.entryCreate,
          "10월 추가 지출 '점심' 12,000원",
        ),
      );
    });

    test('카드 대금은 제목 없이, 금액 미정 고정 지출은 금액 미정으로 적는다', () {
      String summary(EntryDraft entry) => entryActivity(
        ActivityAction.entryTrash,
        month: october,
        kind: entry.kind,
        entry: entry,
      ).summary;

      expect(
        summary(
          const EntryDraft(
            kind: EntryKind.cardBill,
            memberId: 'owner',
            amount: 500000,
            cardId: 'p-card',
          ),
        ),
        '10월 카드 대금 500,000원',
      );
      expect(
        summary(
          const EntryDraft(
            kind: EntryKind.planned,
            memberId: 'owner',
            title: '관리비',
            categoryId: 'c1',
            paymentMethodId: 'p1',
          ),
        ),
        "10월 고정 지출 '관리비' 금액 미정",
      );
    });

    test('고치면 바뀐 칸을 붙이고, 제목·금액은 앞뒤 값을 적는다', () {
      final changed = EntryDraft(
        kind: EntryKind.extra,
        memberId: 'partner',
        title: '저녁',
        amount: 15000,
        paymentMethodId: 'p-card',
        date: DateTime(2026, 10, 14),
        memo: '회식',
      );

      expect(
        entryActivity(
          ActivityAction.entryUpdate,
          month: october,
          kind: EntryKind.extra,
          entry: changed,
          before: lunch,
        ).summary,
        "10월 추가 지출 · 제목 '점심' → '저녁', 금액 12,000원 → 15,000원, 누가, 쓴 날, 메모",
      );
    });

    test('금액만 바꾸면 제목은 그대로 두고 금액의 앞뒤를 적는다', () {
      const before = EntryDraft(
        kind: EntryKind.planned,
        memberId: 'owner',
        title: '관리비',
        categoryId: 'c1',
        paymentMethodId: 'p1',
      );
      const after = EntryDraft(
        kind: EntryKind.planned,
        memberId: 'owner',
        title: '관리비',
        amount: 210000,
        categoryId: 'c1',
        paymentMethodId: 'p1',
      );

      expect(
        entryActivity(
          ActivityAction.entryUpdate,
          month: october,
          kind: EntryKind.planned,
          entry: after,
          before: before,
        ).summary,
        "10월 고정 지출 '관리비' · 금액 미정 → 210,000원",
      );
    });

    test('바뀐 칸이 없으면 지금 값만 적는다', () {
      expect(
        entryActivity(
          ActivityAction.entryUpdate,
          month: october,
          kind: EntryKind.extra,
          entry: lunch,
          before: lunch,
        ).summary,
        "10월 추가 지출 '점심' 12,000원",
      );
    });

    test('문서를 읽지 못했으면 달과 종류만 적는다', () {
      expect(
        entryActivity(
          ActivityAction.entryPurge,
          month: october,
          kind: EntryKind.income,
        ).summary,
        '10월 추가 수입',
      );
    });
  });

  group('고정 지출·설정 기록 요약', () {
    test('고정 지출은 제목·금액을, 고치면 바뀐 칸을 적는다', () {
      expect(
        templateActivity(ActivityAction.templateCreate, rent).summary,
        "고정 지출 '월세' 500,000원",
      );
      expect(
        templateActivity(
          ActivityAction.templateUpdate,
          const TemplateDraft(
            memberId: 'owner',
            title: '월세',
            amount: 550000,
            categoryId: 'c1',
            paymentMethodId: 'p1',
            dueDay: 31,
          ),
          before: rent,
        ).summary,
        "고정 지출 '월세' · 금액 500,000원 → 550,000원, 예정일",
      );
      expect(
        templateActivity(ActivityAction.templateDelete, null).summary,
        '고정 지출',
      );
    });

    test('고정 수입 반복 설정은 고정 수입으로 적는다', () {
      const salary = TemplateDraft(
        kind: EntryKind.fixedIncome,
        memberId: 'owner',
        title: '월급',
        amount: 3000000,
        dueDay: 25,
      );

      expect(
        templateActivity(ActivityAction.templateCreate, salary).summary,
        "고정 수입 '월급' 3,000,000원",
      );
      // 지울 문서를 읽지 못했으면 종류만 적는다.
      expect(
        templateActivity(
          ActivityAction.templateDelete,
          null,
          kind: EntryKind.fixedIncome,
        ).summary,
        '고정 수입',
      );
    });

    test('이름을 바꾸면 앞뒤 이름을 적고, 처음 생긴 이름표는 새 이름만 적는다', () {
      expect(
        ledgerRenameActivity(from: '우리 가계부', to: '하늘바다 가계부'),
        const ActivityDraft(
          ActivityAction.ledgerRename,
          "가계부 이름 '우리 가계부' → '하늘바다 가계부'",
        ),
      );
      expect(
        memberRenameActivity(from: '상대', to: '바다').summary,
        "이름표 '상대' → '바다'",
      );
      expect(memberRenameActivity(to: '바다').summary, "이름표 '바다'");
    });

    test('분류는 이름과 저축 집계 켬·끔을 적는다', () {
      expect(
        categoryActivity(ActivityAction.categoryHide, '여행'),
        const ActivityDraft(ActivityAction.categoryHide, "분류 '여행'"),
      );
      expect(
        categoryUpdateActivity(
          fromName: '여행',
          fromSaving: false,
          name: '휴가',
          countsAsSaving: true,
        ).summary,
        "분류 '여행' → '휴가' · 저축 집계 켬",
      );
      expect(
        categoryUpdateActivity(
          fromName: '여행',
          fromSaving: true,
          name: '여행',
          countsAsSaving: true,
        ).summary,
        "분류 '여행'",
      );
    });

    test('결제수단은 카드면 카드로 적는다', () {
      expect(
        paymentMethodActivity(
          ActivityAction.paymentMethodCreate,
          '하늘카드',
          PaymentKind.card,
        ).summary,
        "카드 '하늘카드'",
      );
      expect(
        paymentMethodRenameActivity(
          from: '공동 통장',
          to: '생활비 통장',
          kind: PaymentKind.account,
        ).summary,
        "결제수단 '공동 통장' → '생활비 통장'",
      );
    });
  });
}
