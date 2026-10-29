import '../../model/ledger_entries.dart';
import '../../model/trashed_entry.dart';
import '../../model/year_month.dart';
import '../../repository/entries_repository.dart';

/// 휴지통에 있는 [month]의 [entry]를 완전히 지운다. 지웠으면 true다. 되살릴 수 없다.
///
/// 반복 설정이 남아 있는 이번 달 이후의 고정 지출은 지우면 다시 만들어져서 지우지 않고 false를 돌려준다([staysInTrash]).
/// [templateIds]는 지금 있는 반복 설정 id다.
/// 온라인에서만 되고, 못 하면 [EntryWriteException]을 던진다.
class PurgeEntryUseCase {
  const PurgeEntryUseCase(this._entries, this._now);

  final EntriesRepository _entries;
  final DateTime Function() _now;

  Future<bool> call({
    required String ledgerId,
    required YearMonth month,
    required LedgerEntry entry,
    required Set<String> templateIds,
    required String uid,
  }) async {
    if (staysInTrash(
      entry,
      month: month,
      thisMonth: YearMonth.of(_now()),
      templateIds: templateIds,
    )) {
      return false;
    }
    await _entries.purge(
      ledgerId: ledgerId,
      month: month,
      kind: entry.kind,
      id: entry.id,
      uid: uid,
    );
    return true;
  }
}
