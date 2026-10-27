import '../../model/member.dart';
import '../../repository/settings_repository.dart';

/// [ledgerId] 가계부의 이름표 두 장을 지켜본다. owner가 앞에 온다.
class WatchMembersUseCase {
  const WatchMembersUseCase(this._settings);

  final SettingsRepository _settings;

  Stream<List<Member>> call(String ledgerId) =>
      _settings.watchMembers(ledgerId);
}
