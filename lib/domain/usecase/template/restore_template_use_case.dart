import '../../model/expense_template.dart';
import '../../repository/templates_repository.dart';

/// 지운 [template]를 같은 id로 다시 만든다(되돌리기). 온라인에서만 되고, 못 하면 [TemplateWriteException]을 던진다.
class RestoreTemplateUseCase {
  const RestoreTemplateUseCase(this._templates);

  final TemplatesRepository _templates;

  Future<void> call({
    required String ledgerId,
    required ExpenseTemplate template,
    required String uid,
  }) => _templates.restore(ledgerId: ledgerId, template: template, uid: uid);
}
