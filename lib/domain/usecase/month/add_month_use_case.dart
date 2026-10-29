import '../../model/expense_template.dart';
import '../../model/year_month.dart';
import '../../repository/entries_repository.dart';

/// 달력에서 [month] 가계부를 새로 만든다. 그달을 항목 있는 달 목록에 더하고, 반복 설정이 있으면 그달 고정 지출(지급 전)로 채운다.
///
/// 지난 달은 채우지 않고 달만 만든다([fillsTemplatesOnAdd]). 반복 설정([templates])은 채울 때만 읽는다.
/// 한 트랜잭션이라 온라인에서만 되고, 연결이 없으면 [EntryWriteException]을 던진다.
class AddMonthUseCase {
  const AddMonthUseCase(this._entries, this._now);

  final EntriesRepository _entries;
  final DateTime Function() _now;

  Future<void> call({
    required String ledgerId,
    required YearMonth month,
    required String uid,
    required Future<List<ExpenseTemplate>> Function() templates,
  }) async {
    final fills = fillsTemplatesOnAdd(month, thisMonth: YearMonth.of(_now()));
    await _entries.fillPlanned(
      ledgerId: ledgerId,
      month: month,
      templates: fills ? await templates() : const [],
      uid: uid,
      recordMonth: true,
    );
  }
}
