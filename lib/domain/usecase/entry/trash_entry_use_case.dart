import '../../model/ledger_entries.dart';
import '../../model/year_month.dart';
import '../../repository/entries_repository.dart';

/// [month]의 [entry]를 휴지통에 넣는다. 목록과 합계에서 빠진다. 온라인에서만 되고, 못 하면 [EntryWriteException]을 던진다.
class TrashEntryUseCase {
  const TrashEntryUseCase(this._entries);

  final EntriesRepository _entries;

  Future<void> call({
    required String ledgerId,
    required YearMonth month,
    required LedgerEntry entry,
    required String uid,
  }) => _entries.trash(
    ledgerId: ledgerId,
    month: month,
    kind: entry.kind,
    id: entry.id,
    uid: uid,
  );
}
