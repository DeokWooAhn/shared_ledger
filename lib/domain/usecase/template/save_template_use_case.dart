import '../../model/expense_template.dart';
import '../../repository/templates_repository.dart';

/// [draft]를 고정 지출로 저장한다. [id]가 없으면 새로 더하고, 있으면 그 고정 지출을 고친다. 작성자는 [uid]다.
///
/// 입력에 문제가 있으면 쓰지 않고 그 문제를 돌려준다([templateProblemsOf]). 저장했으면 빈 집합이다.
/// 고쳐도 이미 만든 달의 기본 월 지출은 그대로다. 온라인에서만 되고, 못 하면 [TemplateWriteException]을 던진다.
class SaveTemplateUseCase {
  const SaveTemplateUseCase(this._templates);

  final TemplatesRepository _templates;

  Future<Set<TemplateProblem>> call({
    required String ledgerId,
    String? id,
    required TemplateDraft draft,
    required String uid,
  }) async {
    final problems = templateProblemsOf(draft);
    if (problems.isNotEmpty) return problems;
    if (id == null) {
      await _templates.add(ledgerId: ledgerId, draft: draft, uid: uid);
    } else {
      await _templates.update(
        ledgerId: ledgerId,
        id: id,
        draft: draft,
        uid: uid,
      );
    }
    return const {};
  }
}
