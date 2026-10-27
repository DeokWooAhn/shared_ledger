import '../../repository/entries_repository.dart';
import '../../repository/ledger_repository.dart';
import 'plan_months_backfill_use_case.dart';

/// [backfill] 범위에서 항목(휴지통 포함)이 있는 달을 찾아 가계부에 처음 적는다. 항목이 없으면 빈 목록을 적어 다시 모으지 않게 한다.
///
/// 범위의 달마다 네 번씩 읽는다. 온라인에서만 되고, 연결이 없으면 [EntryWriteException]을 던진다.
class BackfillMonthsUseCase {
  const BackfillMonthsUseCase(this._entries, this._ledgers);

  final EntriesRepository _entries;
  final LedgerRepository _ledgers;

  Future<void> call(MonthsBackfill backfill) async {
    final found = await _entries.monthsWithEntries(
      backfill.ledgerId,
      backfill.months,
    );
    await _ledgers.recordMonths(ledgerId: backfill.ledgerId, months: found);
  }
}
