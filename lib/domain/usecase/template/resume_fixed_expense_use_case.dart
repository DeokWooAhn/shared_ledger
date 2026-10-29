import '../../model/expense_template.dart';
import '../../model/year_month.dart';
import '../../repository/templates_repository.dart';

/// 그만한 고정 지출을 되살린다(되돌리기). [template]은 그만하기 전의 반복 설정, [months]는 그때 휴지통에 넣은 달이다.
///
/// 온라인에서만 되고, 못 하면 [TemplateWriteException]을 던진다.
class ResumeFixedExpenseUseCase {
  const ResumeFixedExpenseUseCase(this._templates);

  final TemplatesRepository _templates;

  Future<void> call({
    required String ledgerId,
    required ExpenseTemplate template,
    required List<YearMonth> months,
    required String uid,
  }) => _templates.resume(
    ledgerId: ledgerId,
    template: template,
    months: months,
    uid: uid,
  );
}
