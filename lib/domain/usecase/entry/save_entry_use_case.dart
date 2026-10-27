import '../../model/ledger.dart';
import '../../model/ledger_entries.dart';
import '../../model/year_month.dart';
import '../../repository/entries_repository.dart';

/// [ledger]의 [month]에 [draft]를 저장한다. [id]가 없으면 새 항목을 더하고, 있으면 그 항목을 고친다.
///
/// 입력에 문제가 있으면 쓰지 않고 그 문제를 돌려준다([entryProblemsOf]). 저장했으면 빈 집합이다.
/// 새 항목은 서버를 기다리지 않아 오프라인에서도 바로 끝나고, 그달에 처음 넣는 항목이면 가계부의 항목 있는 달 목록에
/// 그달을 같이 더한다([Ledger.needsToRecord]). 고치기는 온라인에서만 되고, 못 하면 [EntryWriteException]을 던진다.
class SaveEntryUseCase {
  const SaveEntryUseCase(this._entries);

  final EntriesRepository _entries;

  Future<Set<EntryProblem>> call({
    required Ledger ledger,
    required YearMonth month,
    String? id,
    required EntryDraft draft,
    required String uid,
  }) async {
    final problems = entryProblemsOf(draft);
    if (problems.isNotEmpty) return problems;
    if (id == null) {
      await _entries.add(
        ledgerId: ledger.id,
        month: month,
        draft: draft,
        uid: uid,
        recordMonth: ledger.needsToRecord(month),
      );
    } else {
      await _entries.update(
        ledgerId: ledger.id,
        month: month,
        id: id,
        draft: draft,
        uid: uid,
      );
    }
    return const {};
  }
}
