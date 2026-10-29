import '../../model/year_month.dart';
import '../../repository/entries_repository.dart';
import '../../repository/ledger_repository.dart';
import 'plan_months_backfill_use_case.dart';

/// [backfill] 범위에서 항목(휴지통 포함)이 있는 달을 찾아 가계부에 처음 적는다. 이번 달도 같이 적는다.
///
/// 목록이 생기기 전의 가계부는 이번 달을 늘 보여 줬으니 옮긴 뒤에도 이번 달 가계부를 이어서 쓴다(2026-10-29, 가계부 탭).
/// 다시 모으지 않게 목록은 늘 적는다. 범위의 달마다 네 번씩 읽는다. 온라인에서만 되고, 연결이 없으면 [EntryWriteException]을 던진다.
class BackfillMonthsUseCase {
  const BackfillMonthsUseCase(this._entries, this._ledgers, this._now);

  final EntriesRepository _entries;
  final LedgerRepository _ledgers;
  final DateTime Function() _now;

  Future<void> call(MonthsBackfill backfill) async {
    final found = await _entries.monthsWithEntries(
      backfill.ledgerId,
      backfill.months,
    );
    await _ledgers.recordMonths(
      ledgerId: backfill.ledgerId,
      months: {...found, YearMonth.of(_now())},
    );
  }
}
