import '../../model/ledger_entries.dart';
import '../../model/trashed_entry.dart';
import '../../model/year_month.dart';
import '../../repository/entries_repository.dart';

/// [month]의 [entry]를 휴지통에 넣는다. 목록과 합계에서 빠진다. 온라인에서만 되고, 못 하면 [EntryWriteException]을 던진다.
///
/// [templateIds]는 지금 있는 반복 설정 id다. 반복 설정이 남아 있는 이번 달 이후의 고정 지출·고정 수입은 지우면 다시 만들어져서
/// 자동으로 지우지 않게 남긴다([staysInTrash]).
class TrashEntryUseCase {
  const TrashEntryUseCase(this._entries, this._now);

  final EntriesRepository _entries;
  final DateTime Function() _now;

  Future<void> call({
    required String ledgerId,
    required YearMonth month,
    required LedgerEntry entry,
    required Set<String> templateIds,
    required String uid,
  }) => _entries.trash(
    ledgerId: ledgerId,
    month: month,
    kind: entry.kind,
    id: entry.id,
    uid: uid,
    keep: staysInTrash(
      entry,
      month: month,
      thisMonth: YearMonth.of(_now()),
      templateIds: templateIds,
    ),
  );
}
