import '../../repository/settings_repository.dart';

/// [id] 분류를 숨기거나([hidden]이 true) 다시 보이게 한다. 온라인에서만 된다.
///
/// 분류는 지우지 않는다. 숨긴 분류는 새 항목·고정 지출에서 고를 수 없지만 지난 항목과 합계에는 그대로 쓰인다.
class SetCategoryHiddenUseCase {
  const SetCategoryHiddenUseCase(this._settings);

  final SettingsRepository _settings;

  Future<void> call({
    required String ledgerId,
    required String id,
    required bool hidden,
    required String uid,
  }) => _settings.setCategoryHidden(
    ledgerId: ledgerId,
    id: id,
    hidden: hidden,
    uid: uid,
  );
}
