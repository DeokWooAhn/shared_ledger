import 'ledger_entries.dart';
import 'year_month.dart';

/// 휴지통 항목을 자동으로 지우기까지의 기간. 휴지통에 넣을 때 `purgeAt`으로 적고, 지나면 Firestore TTL 정책이 지운다.
const trashRetention = Duration(days: 30);

/// 휴지통에 든 항목.
class TrashedEntry {
  const TrashedEntry({required this.entry, this.deletedAt, this.purgeAt});

  final LedgerEntry entry;

  /// 휴지통에 넣은 때. 방금 넣어 서버 시간이 아직 없으면 null.
  final DateTime? deletedAt;

  /// 자동으로 지워질 때. null이면 자동으로 지우지 않는다
  /// (반복 설정에서 만든 이번 달 이후 고정 지출, 자동 삭제를 넣기 전에 휴지통에 넣은 항목).
  final DateTime? purgeAt;
}

/// [month]의 [entry]를 휴지통에서 지우지 않고 남겨야 하는지. [templateIds]는 지금 있는 반복 설정 id다.
///
/// 반복 설정이 남아 있는 이번 달 이후의 고정 지출은 완전히 지우면 그달을 다시 열 때 반복 설정으로 다시 만들어진다.
/// 휴지통에 남아 있으면 '이미 있는 것'으로 보고 다시 만들지 않아서, 완전 삭제와 자동 삭제를 하지 않는다.
/// 지난 달은 다시 만들지 않고, 그만한 고정 지출(반복 설정이 지워짐)도 다시 만들지 않으므로 지울 수 있다.
bool staysInTrash(
  LedgerEntry entry, {
  required YearMonth month,
  required YearMonth thisMonth,
  required Set<String> templateIds,
}) =>
    entry is PlannedExpense &&
    templateIds.contains(entry.id) &&
    month.compareTo(thisMonth) >= 0;
