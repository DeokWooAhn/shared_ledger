import '../../model/month_ledger.dart';
import '../../model/year_month.dart';
import '../../repository/entries_repository.dart';

/// [ledgerId] 가계부의 [month] 한 달 항목을 지켜본다. 휴지통 항목은 목록에서 빼고 [MonthLedger.trashed]에 따로 온다.
///
/// 그달의 컬렉션 네 개만 구독한다. 다른 달의 항목은 읽지 않는다.
class WatchMonthUseCase {
  const WatchMonthUseCase(this._entries);

  final EntriesRepository _entries;

  Stream<MonthLedger> call(String ledgerId, YearMonth month) =>
      _entries.watchMonth(ledgerId, month);
}
