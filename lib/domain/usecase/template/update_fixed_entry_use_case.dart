import '../../model/expense_template.dart';
import '../../model/ledger.dart';
import '../../model/ledger_entries.dart';
import '../../model/year_month.dart';
import '../../repository/templates_repository.dart';

/// [ledger]의 [month]에 있는 고정 지출·고정 수입을 [entry]로 고친다. [template]은 고치기 전의 반복 설정이다. 작성자는 [uid]다.
///
/// 입력에 문제가 있으면 쓰지 않고 그 문제를 돌려준다([fixedEntryProblemsOf]). 저장했으면 빈 집합이다.
/// 제목·분류·결제수단·누가·매달 예정일([dueDay])은 다음 달부터도 바뀐다. 금액·지급(받음) 완료·메모는 그달만 바뀌고,
/// [amountForLater]면 금액도 다음 달부터 바뀐다. 이미 만들어진 뒤 달([monthsAfter])의 지급 전·받기 전 항목도 같이 맞춘다.
/// 온라인에서만 되고, 못 하면 [TemplateWriteException]을 던진다.
class UpdateFixedEntryUseCase {
  const UpdateFixedEntryUseCase(this._templates);

  final TemplatesRepository _templates;

  Future<Set<EntryProblem>> call({
    required Ledger ledger,
    required YearMonth month,
    required ExpenseTemplate template,
    required EntryDraft entry,
    required int? dueDay,
    required bool amountForLater,
    required String uid,
  }) async {
    final problems = fixedEntryProblemsOf(entry, dueDay: dueDay);
    if (problems.isNotEmpty || dueDay == null) return problems;
    await _templates.update(
      ledgerId: ledger.id,
      id: template.id,
      month: month,
      draft: templateDraftOf(
        entry,
        dueDay: dueDay,
        amount: amountForLater ? entry.amount : template.amount,
      ),
      entry: fixedEntryIn(entry, month, dueDay),
      laterMonths: monthsAfter(ledger.months, month),
      uid: uid,
    );
    return const {};
  }
}
