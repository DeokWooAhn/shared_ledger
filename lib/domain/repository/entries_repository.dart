import 'dart:async';
import '../model/expense_template.dart';
import '../model/ledger_entries.dart';
import '../model/month_ledger.dart';
import '../model/trashed_entry.dart';
import '../model/year_month.dart';

/// 항목을 고치거나 휴지통에 넣거나 꺼내지 못한 이유.
enum EntryWriteFailure {
  /// 연결이 없거나 서버가 답하지 않는다. 고치기·휴지통은 두 사람의 기록이 엇갈리지 않게 온라인에서만 한다.
  offline,

  /// 그사이 상대가 휴지통에 넣었거나(꺼내거나 완전히 지울 때는 꺼냈거나) 완전히 지웠다.
  notFound,
}

class EntryWriteException implements Exception {
  const EntryWriteException(this.reason);

  final EntryWriteFailure reason;

  @override
  String toString() => 'EntryWriteException($reason)';
}

/// 서버가 받지 않은 새 항목. 기다리지 않고 기기 캐시에 넣었던 것이라 목록에서 다시 빠진다.
typedef RejectedEntry = ({String id, YearMonth month, EntryKind kind});

/// 가계부 항목(수입·고정 지출·추가 지출·카드 대금)을 읽고 쓴다.
///
/// 오프라인에서는 보기와 새 항목 추가만 된다(docs/plan.md). 고치기·휴지통은 서버에 바로 닿아야 해서,
/// 연결이 없으면 [EntryWriteException]([EntryWriteFailure.offline])으로 실패한다.
///
/// 쓸 때마다 변경 기록(`activity`)을 같은 일괄 쓰기·트랜잭션으로 남긴다. 고정 지출로 채우기([fillPlanned])는 남기지 않는다.
abstract interface class EntriesRepository {
  /// [month] 한 달의 항목. 휴지통에 넣은 항목은 목록에서 빼고 [MonthLedger.trashed]에 따로 모은다.
  ///
  /// 그달의 하위 컬렉션 네 개만 구독한다. 다른 달의 항목은 읽지 않는다.
  Stream<MonthLedger> watchMonth(String ledgerId, YearMonth month);

  /// [month]에 새 항목을 더하고 id를 돌려준다. 작성자는 [uid]다.
  ///
  /// 오프라인에서도 더할 수 있게 서버에 닿기를 기다리지 않는다. 기기 캐시에 바로 들어가 [watchMonth]에 보이고,
  /// 연결되면 서버로 올라간다. 그래서 서버가 나중에 거부한 것은 이 Future가 아니라 [rejectedAdds]로 알린다.
  /// 변경 기록도 같은 일괄 쓰기라 오프라인에서 같이 쌓이고, 서버가 거부하면 같이 빠진다.
  /// [recordMonth]면 가계부의 항목 있는 달 목록에 그달을 같은 일괄 쓰기로 더한다([Ledger.needsToRecord]).
  Future<String> add({
    required String ledgerId,
    required YearMonth month,
    required EntryDraft draft,
    required String uid,
    bool recordMonth = false,
  });

  /// [add]로 더한 항목을 서버가 받지 않았을 때(그사이 보기 전용이 됐거나 가계부에서 나감) 알린다.
  /// 그 항목은 [watchMonth]에서 다시 빠진다.
  Stream<RejectedEntry> get rejectedAdds;

  /// [month]의 [id] 항목을 [draft]로 고친다. 종류([EntryDraft.kind])는 바꿀 수 없다. 온라인에서만 된다.
  Future<void> update({
    required String ledgerId,
    required YearMonth month,
    required String id,
    required EntryDraft draft,
    required String uid,
  });

  /// 항목을 휴지통에 넣는다. 목록과 합계에서 빠진다. 온라인에서만 된다.
  ///
  /// [trashRetention]이 지나면 자동으로 지워지게 한다. [keep]이면 자동으로 지우지 않는다
  /// (반복 설정이 남아 있는 이번 달 이후의 고정 지출은 지우면 다시 만들어진다, [staysInTrash]).
  Future<void> trash({
    required String ledgerId,
    required YearMonth month,
    required EntryKind kind,
    required String id,
    required String uid,
    bool keep = false,
  });

  /// 휴지통에 넣은 항목을 꺼낸다(되살리기). 자동으로 지울 때도 지운다. 온라인에서만 된다.
  Future<void> restore({
    required String ledgerId,
    required YearMonth month,
    required EntryKind kind,
    required String id,
    required String uid,
  });

  /// 휴지통에 넣은 항목을 완전히 지운다. 되살릴 수 없다. 온라인에서만 되고, 휴지통 밖의 항목은
  /// [EntryWriteFailure.notFound]로 실패한다(규칙도 휴지통 항목만 지우게 한다).
  Future<void> purge({
    required String ledgerId,
    required YearMonth month,
    required EntryKind kind,
    required String id,
    required String uid,
  });

  /// [month]에 아직 없는 [templates]의 고정 지출을 만들고, 만든 개수를 돌려준다. 작성자는 [uid]다.
  ///
  /// 문서 id가 템플릿 id라서 이미 있는 문서(휴지통에 넣은 것 포함)는 건드리지 않는다. 서버에서 읽고 없을 때만
  /// 만드는 트랜잭션이라 두 사람이 동시에 그달을 처음 열어도 하나만 생기고 덮어쓰지 않는다.
  /// 온라인에서만 되고, 연결이 없으면 [EntryWriteException]([EntryWriteFailure.offline])으로 실패한다.
  /// [recordMonth]면 가계부의 항목 있는 달 목록에 그달을 같은 트랜잭션으로 더한다. 고정 지출이 없거나 다 있어도 더해서,
  /// 달력에서 그달 가계부를 새로 만들 때도 쓴다.
  Future<int> fillPlanned({
    required String ledgerId,
    required YearMonth month,
    required List<ExpenseTemplate> templates,
    required String uid,
    bool recordMonth = false,
  });

  /// [months] 가운데 항목(휴지통에 넣은 것 포함)이 하나라도 있는 달. 항목 있는 달 목록을 처음 모을 때만 쓴다.
  ///
  /// 달마다 네 컬렉션을 서버에서 한 건씩만 읽는다(달마다 읽기 네 번). 캐시로 답하면 빠뜨릴 수 있어서
  /// 온라인에서만 되고, 연결이 없으면 [EntryWriteException]([EntryWriteFailure.offline])으로 실패한다.
  Future<Set<YearMonth>> monthsWithEntries(
    String ledgerId,
    Iterable<YearMonth> months,
  );
}
