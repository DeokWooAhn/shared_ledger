import '../../model/category.dart';
import '../../model/name_problem.dart';
import '../../repository/settings_repository.dart';

/// 분류를 새로 더하거나 [editing]을 고친다. 온라인에서만 된다.
///
/// 이름이 비었거나 길거나 [categories]의 다른 분류(숨긴 것 포함)와 같으면 쓰지 않고 그 문제를 돌려준다([categoryNameProblemOf]).
/// 새 분류는 맨 뒤에 붙고, 고칠 때 이름과 저축 집계가 그대로면 쓰지 않는다. 쓰지 못하면 [SettingsWriteException]을 던진다.
class SaveCategoryUseCase {
  const SaveCategoryUseCase(this._settings);

  final SettingsRepository _settings;

  Future<NameProblem?> call({
    required String ledgerId,
    Category? editing,
    required String name,
    required bool countsAsSaving,
    required List<Category> categories,
    required String uid,
  }) async {
    final problem = categoryNameProblemOf(name, categories, editing: editing);
    if (problem != null) return problem;
    final draft = (name: name.trim(), countsAsSaving: countsAsSaving);
    if (editing == null) {
      await _settings.addCategory(
        ledgerId: ledgerId,
        draft: draft,
        order: categories.length,
        uid: uid,
      );
    } else if (draft.name != editing.name ||
        draft.countsAsSaving != editing.countsAsSaving) {
      await _settings.updateCategory(
        ledgerId: ledgerId,
        id: editing.id,
        draft: draft,
        uid: uid,
      );
    }
    return null;
  }
}
