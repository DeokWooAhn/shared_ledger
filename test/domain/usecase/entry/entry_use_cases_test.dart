import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/model/ledger.dart';
import 'package:shared_ledger/domain/model/ledger_entries.dart';
import 'package:shared_ledger/domain/model/month_ledger.dart';
import 'package:shared_ledger/domain/model/trashed_entry.dart';
import 'package:shared_ledger/domain/model/year_month.dart';
import 'package:shared_ledger/domain/repository/entries_repository.dart';
import 'package:shared_ledger/domain/usecase/entry/entry_use_cases.dart';

import '../../../../testing/fakes.dart';
import '../../../../testing/provider_container.dart';

const september = YearMonth(2026, 9);
const october = YearMonth(2026, 10);

// 달 목록이 있는 가계부(아직 항목이 들어간 달은 없다).
const mine = Ledger(id: 'l1', name: '우리 가계부', ownerUid: 'me', months: {});

const lunch = ExtraExpense(
  id: 'x-lunch',
  memberId: 'owner',
  title: '점심',
  paymentMethodId: 'p-account',
  amount: 9000,
);

PlannedExpense rentIn(YearMonth month) => PlannedExpense(
  id: 'template-rent',
  categoryId: 'c-living',
  memberId: 'owner',
  title: '관리비',
  paymentMethodId: 'p-account',
  dueOn: DateTime(month.year, month.month, 25),
);

const snack = EntryDraft(
  kind: EntryKind.extra,
  memberId: 'owner',
  amount: 3000,
  title: '간식',
  paymentMethodId: 'p-account',
);

EntryUseCases useCasesOf(FakeEntriesRepository entries) =>
    EntryUseCases(entries, now: () => testNow);

void main() {
  test('그달 항목을 그 가계부·달로만 지켜본다', () async {
    final entries = FakeEntriesRepository({
      october: const MonthLedger(extraExpenses: [lunch]),
    });

    final month = await useCasesOf(entries).watchMonth('l1', october).first;

    expect(month.extraExpenses, [lunch]);
    expect(entries.watched, [(ledgerId: 'l1', month: october)]);
  });

  test('서버가 받지 않은 새 항목을 알린다', () async {
    final entries = FakeEntriesRepository()..rejectNextAdd = true;
    final useCases = useCasesOf(entries);
    final rejected = <RejectedEntry>[];
    final subscription = useCases.watchRejectedEntries().listen(rejected.add);
    addTearDown(subscription.cancel);

    await useCases.saveEntry(
      ledger: mine,
      month: october,
      draft: snack,
      uid: 'me',
    );
    await pumpEventQueue();

    expect(rejected, [(id: 'entry-1', month: october, kind: EntryKind.extra)]);
  });

  group('저장', () {
    test('새 항목은 더하고, 그달에 처음 넣으면 달 목록에 그달을 같이 더한다', () async {
      final entries = FakeEntriesRepository();

      final problems = await useCasesOf(
        entries,
      ).saveEntry(ledger: mine, month: october, draft: snack, uid: 'me');

      expect(problems, isEmpty);
      expect(entries.added, [
        (ledgerId: 'l1', month: october, draft: snack, uid: 'me'),
      ]);
      expect(entries.recordedMonths, [october]);
    });

    test('달 목록을 아직 모으지 않은 가계부면 달 목록에 더하지 않는다', () async {
      final entries = FakeEntriesRepository();

      await useCasesOf(entries).saveEntry(
        ledger: const Ledger(id: 'l1', name: '우리 가계부', ownerUid: 'me'),
        month: october,
        draft: snack,
        uid: 'me',
      );

      expect(entries.added, hasLength(1));
      expect(entries.recordedMonths, isEmpty);
    });

    test('고칠 항목의 id가 있으면 그 항목을 고친다', () async {
      final entries = FakeEntriesRepository({
        october: const MonthLedger(extraExpenses: [lunch]),
      });

      await useCasesOf(entries).saveEntry(
        ledger: mine,
        month: october,
        id: 'x-lunch',
        draft: snack,
        uid: 'me',
      );

      expect(entries.updated, [
        (
          ledgerId: 'l1',
          month: october,
          id: 'x-lunch',
          draft: snack,
          uid: 'me',
        ),
      ]);
      expect(entries.added, isEmpty);
    });

    test('입력에 문제가 있으면 쓰지 않고 문제를 돌려준다', () async {
      final entries = FakeEntriesRepository();

      final problems = await useCasesOf(entries).saveEntry(
        ledger: mine,
        month: october,
        draft: const EntryDraft(kind: EntryKind.extra, memberId: 'owner'),
        uid: 'me',
      );

      expect(problems, {
        EntryProblem.amountMissing,
        EntryProblem.titleMissing,
        EntryProblem.paymentMethodMissing,
      });
      expect(entries.added, isEmpty);
    });

    test('연결이 없으면 고치기는 저장소의 실패를 그대로 던진다', () async {
      final entries = FakeEntriesRepository({
        october: const MonthLedger(extraExpenses: [lunch]),
      })..offline = true;

      await expectLater(
        useCasesOf(entries).saveEntry(
          ledger: mine,
          month: october,
          id: 'x-lunch',
          draft: snack,
          uid: 'me',
        ),
        throwsA(
          isA<EntryWriteException>().having(
            (e) => e.reason,
            'reason',
            EntryWriteFailure.offline,
          ),
        ),
      );
    });
  });

  group('휴지통', () {
    test('휴지통에 넣었다가 꺼낸다', () async {
      final entries = FakeEntriesRepository({
        october: const MonthLedger(extraExpenses: [lunch]),
      });
      final useCases = useCasesOf(entries);

      await useCases.trashEntry(
        ledgerId: 'l1',
        month: october,
        entry: lunch,
        uid: 'me',
      );
      expect(entries.monthOf(october).extraExpenses, isEmpty);
      await useCases.restoreEntry(
        ledgerId: 'l1',
        month: october,
        entry: lunch,
        uid: 'me',
      );

      expect(entries.trashed, [
        (ledgerId: 'l1', month: october, kind: EntryKind.extra, id: 'x-lunch'),
      ]);
      expect(entries.restored, entries.trashed);
      expect(entries.monthOf(october).extraExpenses, [lunch]);
    });

    test('휴지통 항목을 완전히 지우면 true다', () async {
      final entries = FakeEntriesRepository({
        october: const MonthLedger(trashed: [TrashedEntry(entry: lunch)]),
      });

      final purged = await useCasesOf(
        entries,
      ).purgeEntry(ledgerId: 'l1', month: october, entry: lunch, uid: 'me');

      expect(purged, isTrue);
      expect(entries.purged, [
        (ledgerId: 'l1', month: october, kind: EntryKind.extra, id: 'x-lunch'),
      ]);
    });

    test('고정 지출에서 만든 이번 달 기본 월 지출은 지우지 않고 false다', () async {
      final rent = rentIn(october);
      final entries = FakeEntriesRepository({
        october: MonthLedger(trashed: [TrashedEntry(entry: rent)]),
      });

      final purged = await useCasesOf(
        entries,
      ).purgeEntry(ledgerId: 'l1', month: october, entry: rent, uid: 'me');

      expect(purged, isFalse);
      expect(entries.purged, isEmpty);
    });

    test('지난 달의 고정 지출 항목은 다시 만들지 않아서 지운다', () async {
      final rent = rentIn(september);
      final entries = FakeEntriesRepository({
        september: MonthLedger(trashed: [TrashedEntry(entry: rent)]),
      });

      final purged = await useCasesOf(
        entries,
      ).purgeEntry(ledgerId: 'l1', month: september, entry: rent, uid: 'me');

      expect(purged, isTrue);
      expect(entries.purged.single.id, 'template-rent');
    });
  });
}
