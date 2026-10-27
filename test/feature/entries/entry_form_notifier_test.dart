import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/providers/providers.dart';
import 'package:shared_ledger/domain/model/auth_user.dart';
import 'package:shared_ledger/domain/model/ledger.dart';
import 'package:shared_ledger/domain/model/ledger_entries.dart';
import 'package:shared_ledger/domain/model/member.dart';
import 'package:shared_ledger/domain/model/month_ledger.dart';
import 'package:shared_ledger/domain/model/year_month.dart';
import 'package:shared_ledger/feature/entries/entry_form_notifier.dart';

import '../../../testing/fakes.dart';
import '../../../testing/provider_container.dart';

const me = AuthUser(uid: 'me');
const mine = Ledger(id: 'l1', name: '우리 가계부', ownerUid: 'me');
const october = YearMonth(2026, 10);

/// 로그인하고 가계부 목록까지 받은 컨테이너. Notifier가 내 uid와 지금 가계부를 바로 읽을 수 있다.
Future<ProviderContainer> ready({
  FakeEntriesRepository? entries,
  Ledger ledger = mine,
}) async {
  final container = createContainer(
    auth: FakeAuthRepository(signedIn: me),
    ledgers: FakeLedgerRepository([ledger]),
    entries: entries,
  );
  await loadSignedInUser(container);
  container.listen(myLedgersProvider, (_, _) {});
  await container.read(myLedgersProvider.future);
  return container;
}

EntryFormArgs add(EntryKind kind, [YearMonth month = october]) =>
    EntryFormArgs.add(kind: kind, month: month);

const rent = PlannedExpense(
  id: 'template-rent',
  categoryId: 'c-living',
  memberId: 'partner',
  title: '관리비',
  paymentMethodId: 'p-account',
);

void main() {
  group('새 항목', () {
    test('누가는 나, 날짜는 보는 달이 이번 달이면 오늘로 시작하고 기본 월 지출은 지급 전이다', () async {
      final container = await ready();

      final extra = container.read(
        entryFormNotifierProvider(add(EntryKind.extra)),
      );
      final planned = container.read(
        entryFormNotifierProvider(add(EntryKind.planned)),
      );
      final nextMonth = container.read(
        entryFormNotifierProvider(
          add(EntryKind.extra, const YearMonth(2026, 11)),
        ),
      );

      expect(extra.memberId, 'owner');
      expect(extra.date, DateTime(2026, 10, 15));
      expect(planned.date, isNull);
      expect(planned.paid, isFalse);
      expect(nextMonth.date, isNull);
    });

    test('달력에서 고른 날로 열면 그 날짜로 시작하고, 종류를 바꿔도 유지한다(기본 월 지출은 지급 전)', () async {
      final container = await ready();
      final provider = entryFormNotifierProvider(
        EntryFormArgs.add(
          kind: EntryKind.extra,
          month: october,
          date: DateTime(2026, 10, 18, 21, 30),
        ),
      );
      container.listen(provider, (_, _) {});

      expect(container.read(provider).date, DateTime(2026, 10, 18));
      container.read(provider.notifier).selectKind(EntryKind.planned);
      expect(container.read(provider).date, isNull);
      container.read(provider.notifier).selectKind(EntryKind.income);
      expect(container.read(provider).date, DateTime(2026, 10, 18));
    });

    test('초대로 들어온 사람의 새 항목은 상대 자리로 시작한다', () async {
      final container = await ready(
        ledger: const Ledger(
          id: 'l1',
          name: '우리 가계부',
          ownerUid: 'partner-uid',
          roles: {'me': MemberRole.editor},
        ),
      );

      expect(
        container.read(entryFormNotifierProvider(add(EntryKind.extra))),
        isA<EntryFormState>().having((s) => s.memberId, 'memberId', 'partner'),
      );
    });

    test('추가지출을 저장하면 보고 있는 달에 더하고 저장 결과로 닫힌다', () async {
      final entries = FakeEntriesRepository();
      final container = await ready(entries: entries);
      final provider = entryFormNotifierProvider(add(EntryKind.extra));
      final states = recordStates(container, provider);
      container.read(provider.notifier)
        ..selectMember(MemberSlot.partner)
        ..selectPaymentMethod('p-card');

      await container
          .read(provider.notifier)
          .save(amount: '186,000', title: ' 마트 장보기 ', memo: ' ');

      expect(entries.added, [
        (
          ledgerId: 'l1',
          month: october,
          draft: EntryDraft(
            kind: EntryKind.extra,
            memberId: 'partner',
            amount: 186000,
            title: '마트 장보기',
            paymentMethodId: 'p-card',
            date: DateTime(2026, 10, 15),
          ),
          uid: 'me',
        ),
      ]);
      expect(states.map((s) => s.pending), [
        null,
        null,
        EntryFormAction.save,
        null,
      ]);
      expect(states.last.outcome, EntryFormOutcome.saved);
    });

    test('그달에 처음 넣는 항목이면 가계부의 달 목록에 그달을 더하고, 이미 있으면 다시 더하지 않는다', () async {
      final entries = FakeEntriesRepository();
      final container = await ready(
        entries: entries,
        ledger: Ledger(
          id: 'l1',
          name: '우리 가계부',
          ownerUid: 'me',
          months: {const YearMonth(2026, 9)},
        ),
      );
      Future<void> saveExtra() async {
        final provider = entryFormNotifierProvider(add(EntryKind.extra));
        recordStates(container, provider);
        container.read(provider.notifier).selectPaymentMethod('p-card');
        await container
            .read(provider.notifier)
            .save(amount: '5,000', title: '간식', memo: '');
      }

      await saveExtra();
      await pumpEventQueue();
      expect(entries.recordedMonths, [october]);
      expect(container.read(currentLedgerProvider)?.months, {
        const YearMonth(2026, 9),
        october,
      });

      await saveExtra();
      expect(entries.recordedMonths, [october]);
    });

    test('달 목록을 아직 모으지 않은 가계부면 더하지 않는다(모을 때 같이 찾는다)', () async {
      final entries = FakeEntriesRepository();
      final container = await ready(entries: entries);
      final provider = entryFormNotifierProvider(add(EntryKind.income));
      recordStates(container, provider);

      await container
          .read(provider.notifier)
          .save(amount: '3,000,000', title: '월급', memo: '');

      expect(entries.added, hasLength(1));
      expect(entries.recordedMonths, isEmpty);
    });

    test('연결이 없어도 새 항목은 저장된다', () async {
      final entries = FakeEntriesRepository()..offline = true;
      final container = await ready(entries: entries);
      final provider = entryFormNotifierProvider(add(EntryKind.income));
      recordStates(container, provider);

      await container
          .read(provider.notifier)
          .save(amount: '3,000,000', title: '월급', memo: '');

      expect(entries.added.single.draft.kind, EntryKind.income);
      expect(container.read(provider).outcome, EntryFormOutcome.saved);
    });

    test('꼭 필요한 칸이 비어 있으면 저장하지 않고 칸마다 문제를 알린다', () async {
      final entries = FakeEntriesRepository();
      final container = await ready(entries: entries);
      final planned = entryFormNotifierProvider(add(EntryKind.planned));
      final extra = entryFormNotifierProvider(add(EntryKind.extra));
      final bill = entryFormNotifierProvider(add(EntryKind.cardBill));
      for (final provider in [planned, extra, bill]) {
        recordStates(container, provider);
        await container
            .read(provider.notifier)
            .save(amount: '', title: '  ', memo: '');
      }

      // 기본 월 지출은 금액을 비워 둘 수 있다(금액 미정).
      expect(container.read(planned).problems, {
        EntryProblem.titleMissing,
        EntryProblem.categoryMissing,
        EntryProblem.paymentMethodMissing,
      });
      expect(container.read(extra).problems, {
        EntryProblem.amountMissing,
        EntryProblem.titleMissing,
        EntryProblem.paymentMethodMissing,
      });
      // 카드대금은 제목이 없다.
      expect(container.read(bill).problems, {
        EntryProblem.amountMissing,
        EntryProblem.cardMissing,
      });
      expect(entries.added, isEmpty);
    });

    test('제목은 40자(UTF-16 단위), 메모는 200자를 넘으면 알린다', () {
      EntryDraft draft({String title = '간식', String? memo}) => EntryDraft(
        kind: EntryKind.extra,
        memberId: 'owner',
        amount: 1000,
        title: title,
        paymentMethodId: 'p1',
        memo: memo,
      );

      expect(entryProblemsOf(draft(title: '가' * 40)), isEmpty);
      expect(entryProblemsOf(draft(title: '가' * 41)), {
        EntryProblem.titleTooLong,
      });
      // 보안 규칙처럼 이모지 하나를 두 글자로 센다.
      expect(entryProblemsOf(draft(title: '🍚' * 21)), {
        EntryProblem.titleTooLong,
      });
      expect(entryProblemsOf(draft(memo: '가' * 200)), isEmpty);
      expect(entryProblemsOf(draft(memo: '가' * 201)), {
        EntryProblem.memoTooLong,
      });
    });

    test('칸을 고치거나 고르면 그 칸의 문제만 지운다', () async {
      final container = await ready();
      final provider = entryFormNotifierProvider(add(EntryKind.planned));
      recordStates(container, provider);
      final notifier = container.read(provider.notifier);
      await notifier.save(amount: '', title: '', memo: '');

      notifier
        ..textEdited(EntryTextField.title)
        ..selectCategory('c-living');

      expect(container.read(provider).problems, {
        EntryProblem.paymentMethodMissing,
      });
    });

    test('종류를 바꾸면 누가·결제수단은 남기고 분류·날짜는 그 종류의 처음 값으로 돌린다', () async {
      final container = await ready();
      final provider = entryFormNotifierProvider(add(EntryKind.planned));
      recordStates(container, provider);
      container.read(provider.notifier)
        ..selectMember(MemberSlot.partner)
        ..selectCategory('c-living')
        ..selectPaymentMethod('p-account')
        ..setPaid(true)
        ..selectKind(EntryKind.extra);

      expect(
        container.read(provider),
        EntryFormState(
          kind: EntryKind.extra,
          memberId: 'partner',
          paymentMethodId: 'p-account',
          date: DateTime(2026, 10, 15),
        ),
      );

      container.read(provider.notifier).selectKind(EntryKind.cardBill);
      expect(container.read(provider).paymentMethodId, isNull);
    });

    test('지급 완료를 켜면 오늘로 채우고, 그달 밖이면 그달 첫날·말일로 채우며, 끄면 비운다', () async {
      final container = await ready();
      DateTime? paidDate(YearMonth month) {
        final provider = entryFormNotifierProvider(
          add(EntryKind.planned, month),
        );
        recordStates(container, provider);
        container.read(provider.notifier).setPaid(true);
        return container.read(provider).date;
      }

      expect(paidDate(october), DateTime(2026, 10, 15));
      expect(paidDate(const YearMonth(2026, 9)), DateTime(2026, 9, 30));
      expect(paidDate(const YearMonth(2026, 11)), DateTime(2026, 11, 1));

      final provider = entryFormNotifierProvider(add(EntryKind.planned));
      container.read(provider.notifier).setPaid(false);
      expect(container.read(provider).paid, isFalse);
    });

    test('날짜를 고르면 시각을 버리고, 비우면 날짜가 없다', () async {
      final container = await ready();
      final provider = entryFormNotifierProvider(add(EntryKind.extra));
      recordStates(container, provider);
      final notifier = container.read(provider.notifier);

      notifier.selectDate(DateTime(2026, 10, 3, 13, 20));
      expect(container.read(provider).date, DateTime(2026, 10, 3));
      notifier.clearDate();
      expect(container.read(provider).date, isNull);
    });

    test('저장 중에 다시 누르면 무시한다', () async {
      final entries = FakeEntriesRepository();
      final container = await ready(entries: entries);
      final provider = entryFormNotifierProvider(add(EntryKind.income));
      recordStates(container, provider);
      final notifier = container.read(provider.notifier);

      await Future.wait([
        notifier.save(amount: '1000', title: '용돈', memo: ''),
        notifier.save(amount: '1000', title: '용돈', memo: ''),
      ]);

      expect(entries.added, hasLength(1));
    });

    test('예상 못 한 오류면 스낵바로 알릴 실패를 켜고, 알린 뒤 끈다', () async {
      final container = await ready(
        entries: FakeEntriesRepository()..failNextWrite = true,
      );
      final provider = entryFormNotifierProvider(add(EntryKind.income));
      recordStates(container, provider);
      final notifier = container.read(provider.notifier);

      await notifier.save(amount: '1000', title: '용돈', memo: '');
      expect(container.read(provider).failure, EntryFormFailure.save);
      expect(container.read(provider).outcome, isNull);

      notifier.failureShown();
      expect(container.read(provider).failure, isNull);
      expect(container.read(provider).busy, isFalse);
    });
  });

  group('고치기와 휴지통', () {
    FakeEntriesRepository withRent() => FakeEntriesRepository({
      october: const MonthLedger(plannedExpenses: [rent]),
    });

    EntryFormArgs edit() => EntryFormArgs.edit(entry: rent, month: october);

    test('있는 항목의 값으로 시작하고, 종류는 바꿀 수 없다', () async {
      final container = await ready(entries: withRent());
      final provider = entryFormNotifierProvider(edit());
      recordStates(container, provider);

      container.read(provider.notifier).selectKind(EntryKind.extra);

      expect(
        container.read(provider),
        const EntryFormState(
          kind: EntryKind.planned,
          memberId: 'partner',
          categoryId: 'c-living',
          paymentMethodId: 'p-account',
        ),
      );
    });

    test('금액을 채우고 지급 완료로 고치면 같은 항목을 바꾸고 닫힌다', () async {
      final entries = withRent();
      final container = await ready(entries: entries);
      final provider = entryFormNotifierProvider(edit());
      recordStates(container, provider);
      final notifier = container.read(provider.notifier)..setPaid(true);

      await notifier.save(amount: '210,000', title: '관리비', memo: '10월분');

      expect(entries.updated.single.id, 'template-rent');
      expect(entries.updated.single.uid, 'me');
      final updated = entries.monthOf(october).plannedExpenses.single;
      expect(updated.amount, 210000);
      expect(updated.paidOn, DateTime(2026, 10, 15));
      expect(updated.memo, '10월분');
      expect(entries.added, isEmpty);
      expect(container.read(provider).outcome, EntryFormOutcome.saved);
    });

    test('고정 지출에서 옮긴 예정일은 고쳐도 그대로 남는다', () async {
      final scheduled = PlannedExpense(
        id: 'template-rent',
        categoryId: 'c-living',
        memberId: 'partner',
        title: '관리비',
        paymentMethodId: 'p-account',
        dueOn: DateTime(2026, 10, 31),
      );
      final entries = FakeEntriesRepository({
        october: MonthLedger(plannedExpenses: [scheduled]),
      });
      final container = await ready(entries: entries);
      final provider = entryFormNotifierProvider(
        EntryFormArgs.edit(entry: scheduled, month: october),
      );
      recordStates(container, provider);

      await container
          .read(provider.notifier)
          .save(amount: '210,000', title: '관리비', memo: '');

      expect(entries.updated.single.draft.dueOn, DateTime(2026, 10, 31));
      expect(
        entries.monthOf(october).plannedExpenses.single.dueOn,
        DateTime(2026, 10, 31),
      );
    });

    test('연결이 없으면 고치지 않고 연결된 뒤에 하라고 알린다', () async {
      final entries = withRent()..offline = true;
      final container = await ready(entries: entries);
      final provider = entryFormNotifierProvider(edit());
      recordStates(container, provider);

      await container
          .read(provider.notifier)
          .save(amount: '210,000', title: '관리비', memo: '');

      expect(entries.updated, isEmpty);
      expect(container.read(provider).failure, EntryFormFailure.offline);
      expect(container.read(provider).outcome, isNull);
    });

    test('그사이 휴지통에 들어간 항목이면 알린다', () async {
      final container = await ready(entries: FakeEntriesRepository());
      final provider = entryFormNotifierProvider(edit());
      recordStates(container, provider);

      await container
          .read(provider.notifier)
          .save(amount: '210,000', title: '관리비', memo: '');

      expect(container.read(provider).failure, EntryFormFailure.gone);
    });

    test('휴지통에 넣으면 목록에서 빠지고 휴지통 결과로 닫힌다', () async {
      final entries = withRent();
      final container = await ready(entries: entries);
      final provider = entryFormNotifierProvider(edit());
      final states = recordStates(container, provider);

      await container.read(provider.notifier).trash();

      expect(entries.trashed, [
        (
          ledgerId: 'l1',
          month: october,
          kind: EntryKind.planned,
          id: 'template-rent',
        ),
      ]);
      expect(entries.monthOf(october).plannedExpenses, isEmpty);
      expect(states.map((s) => s.pending), [EntryFormAction.trash, null]);
      expect(states.last.outcome, EntryFormOutcome.trashed);
    });

    test('연결이 없으면 휴지통에 넣지 않고 알린다', () async {
      final entries = withRent()..offline = true;
      final container = await ready(entries: entries);
      final provider = entryFormNotifierProvider(edit());
      recordStates(container, provider);

      await container.read(provider.notifier).trash();

      expect(entries.monthOf(october).plannedExpenses, [rent]);
      expect(container.read(provider).failure, EntryFormFailure.offline);
    });

    test('새 항목 화면에서는 휴지통에 넣을 것이 없다', () async {
      final entries = withRent();
      final container = await ready(entries: entries);
      final provider = entryFormNotifierProvider(add(EntryKind.planned));
      recordStates(container, provider);

      await container.read(provider.notifier).trash();

      expect(entries.trashed, isEmpty);
      expect(container.read(provider).pending, isNull);
    });
  });
}
