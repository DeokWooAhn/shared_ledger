import '../../model/entry_edit.dart';
import '../../model/expense_template.dart';
import '../../model/ledger.dart';
import '../../model/ledger_entries.dart';
import '../../model/year_month.dart';
import '../../repository/templates_repository.dart';

/// [ledger]의 [month]에 있는 고정 지출·고정 수입 [original]을 [entry]로 고친다. [template]은 고치기 전의 반복 설정이다.
/// 작성자는 [uid]다.
///
/// 입력에 문제가 있으면 쓰지 않고 그 문제를 돌려준다([fixedEntryProblemsOf]). 저장했으면 빈 집합이다.
/// 내가 바꾼 제목·분류·결제수단·누가와 새로 고른 매달 예정일([dueDay])은 다음 달부터도 바뀐다. [dueDay]를 고르지
/// 않았으면(null) 반복 설정과 그달 항목의 예정일을 그대로 둔다. 금액·지급(받음) 완료·메모는 그달만 바뀌고,
/// [amountForLater]면 금액도 다음 달부터 바뀐다. 이미 만들어진 뒤 달([monthsAfter])의 지급 전·받기 전 항목도
/// 반복 설정에서 바뀐 칸만 같이 맞춘다. 온라인에서만 되고, 못 하면 [TemplateWriteException]을 던진다.
/// 그달 항목은 [original](고치기 화면을 열 때의 값)과 견주어 내가 바꾼 칸만 쓴다. 그사이 상대가 같은 칸을 다르게
/// 바꿨으면 [choice]대로 고르고, 없으면 [EntryEditConflict]를 던진다([TemplatesRepository.update]).
class UpdateFixedEntryUseCase {
  const UpdateFixedEntryUseCase(this._templates);

  final TemplatesRepository _templates;

  Future<Set<EntryProblem>> call({
    required Ledger ledger,
    required YearMonth month,
    required ExpenseTemplate template,
    required LedgerEntry original,
    required EntryDraft entry,
    required int? dueDay,
    required bool amountForLater,
    required String uid,
    EditConflictChoice? choice,
  }) async {
    final problems = fixedEntryProblemsOf(
      entry,
      dueDay: dueDay ?? template.dueDay,
    );
    if (problems.isNotEmpty) return problems;
    final base = EntryDraft.of(original);
    await _templates.update(
      ledgerId: ledger.id,
      id: template.id,
      month: month,
      template: TemplateDraft.of(template),
      base: base,
      // 예정일을 새로 골랐을 때만 그달 예정일을 옮기고, 아니면 그달 항목의 예정일을 그대로 둔다.
      entry: switch (dueDay) {
        final day? => fixedEntryIn(entry, month, day),
        null => fixedEntryDueOn(entry, base.dueOn),
      },
      laterMonths: monthsAfter(ledger.months, month),
      uid: uid,
      dueDay: dueDay,
      amountForLater: amountForLater,
      choice: choice,
    );
    return const {};
  }
}
