import '../../model/category.dart';
import '../../repository/settings_repository.dart';

/// [ledgerId] 가계부의 지출 분류를 지켜본다. 정한 순서대로, 숨긴 분류도 함께 온다.
class WatchCategoriesUseCase {
  const WatchCategoriesUseCase(this._settings);

  final SettingsRepository _settings;

  Stream<List<Category>> call(String ledgerId) =>
      _settings.watchCategories(ledgerId);
}
