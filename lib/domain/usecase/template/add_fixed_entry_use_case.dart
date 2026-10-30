import '../../model/expense_template.dart';
import '../../model/ledger.dart';
import '../../model/ledger_entries.dart';
import '../../model/year_month.dart';
import '../../repository/templates_repository.dart';

/// [ledger]의 [month]에 고정 지출·고정 수입 [entry]를 더한다. 매달 예정일은 [dueDay]다. 작성자는 [uid]다.
///
/// 입력에 문제가 있으면 쓰지 않고 그 문제를 돌려준다([fixedEntryProblemsOf]). 저장했으면 빈 집합이다.
/// 반복 설정과 그달 항목을 같은 id로 만들고, 이미 만들어진 뒤 달([monthsAfter])에도 그달 항목(지급 전·받기 전)을 만든다.
/// 그달에 처음 넣는 항목이면 가계부의 항목 있는 달 목록에 그달을 같이 더한다([Ledger.needsToRecord]).
/// 온라인에서만 되고, 못 하면 [TemplateWriteException]을 던진다.
class AddFixedEntryUseCase {
  const AddFixedEntryUseCase(this._templates);

  final TemplatesRepository _templates;

  Future<Set<EntryProblem>> call({
    required Ledger ledger,
    required YearMonth month,
    required EntryDraft entry,
    required int? dueDay,
    required String uid,
  }) async {
    final problems = fixedEntryProblemsOf(entry, dueDay: dueDay);
    if (problems.isNotEmpty || dueDay == null) return problems;
    await _templates.add(
      ledgerId: ledger.id,
      month: month,
      draft: templateDraftOf(entry, dueDay: dueDay, amount: entry.amount),
      entry: fixedEntryIn(entry, month, dueDay),
      laterMonths: monthsAfter(ledger.months, month),
      uid: uid,
      recordMonth: ledger.needsToRecord(month),
    );
    return const {};
  }
}
