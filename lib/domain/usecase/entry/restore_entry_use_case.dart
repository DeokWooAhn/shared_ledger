import '../../model/ledger_entries.dart';
import '../../model/year_month.dart';
import '../../repository/entries_repository.dart';

/// [month]의 [entry]를 휴지통에서 꺼낸다. 그달 목록과 합계에 다시 들어간다.
/// 온라인에서만 되고, 못 하면 [EntryWriteException]을 던진다(그사이 꺼냈거나 지웠으면 notFound).
class RestoreEntryUseCase {
  const RestoreEntryUseCase(this._entries);

  final EntriesRepository _entries;

  Future<void> call({
    required String ledgerId,
    required YearMonth month,
    required LedgerEntry entry,
    required String uid,
  }) => _entries.restore(
    ledgerId: ledgerId,
    month: month,
    kind: entry.kind,
    id: entry.id,
    uid: uid,
  );
}
