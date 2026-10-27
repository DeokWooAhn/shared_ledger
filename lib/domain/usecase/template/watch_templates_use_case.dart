import '../../model/expense_template.dart';
import '../../repository/templates_repository.dart';

/// [ledgerId] 가계부의 고정 지출 전부를 지켜본다. 순서는 화면이 정한다.
class WatchTemplatesUseCase {
  const WatchTemplatesUseCase(this._templates);

  final TemplatesRepository _templates;

  Stream<List<ExpenseTemplate>> call(String ledgerId) =>
      _templates.watchTemplates(ledgerId);
}
