import '../../model/expense_template.dart';
import '../../model/ledger.dart';
import '../../model/year_month.dart';
import '../../repository/templates_repository.dart';

/// [ledger]의 [id] 고정 지출을 [month]부터 그만한다. 작성자는 [uid]다.
///
/// 반복 설정을 지우고 그달 항목과 이미 만들어진 뒤 달([monthsAfter])의 지급 전 항목을 휴지통에 넣는다. 지난 기록은 남는다.
/// 휴지통에 넣은 달을 돌려준다(되돌리기에 쓴다). 온라인에서만 되고, 못 하면 [TemplateWriteException]을 던진다.
class StopFixedExpenseUseCase {
  const StopFixedExpenseUseCase(this._templates);

  final TemplatesRepository _templates;

  Future<List<YearMonth>> call({
    required Ledger ledger,
    required YearMonth month,
    required String id,
    required String uid,
  }) => _templates.stop(
    ledgerId: ledger.id,
    id: id,
    month: month,
    laterMonths: monthsAfter(ledger.months, month),
    uid: uid,
  );
}
