import '../../model/activity.dart';
import '../../repository/activity_repository.dart';

/// [ledgerId] 가계부의 최근 변경 기록 [activityPageSize]건을 새것부터 지켜본다.
///
/// 계속 늘어나는 목록이라 정한 개수만 구독한다. 아직 서버에 닿지 않은 기록(시간 없음)이 맨 앞에 온다.
class WatchRecentActivityUseCase {
  const WatchRecentActivityUseCase(this._activity);

  final ActivityRepository _activity;

  Stream<List<Activity>> call(String ledgerId) =>
      _activity.watchRecent(ledgerId);
}
