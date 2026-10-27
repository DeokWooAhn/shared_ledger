import '../../model/activity.dart';
import '../../repository/activity_repository.dart';

/// [ledgerId] 가계부에서 [before]보다 먼저 남긴 변경 기록 [activityPageSize]건을 새것부터 한 번 읽는다('더 보기').
class LoadOlderActivityUseCase {
  const LoadOlderActivityUseCase(this._activity);

  final ActivityRepository _activity;

  Future<List<Activity>> call(String ledgerId, {required DateTime before}) =>
      _activity.loadOlder(ledgerId, before: before);
}
