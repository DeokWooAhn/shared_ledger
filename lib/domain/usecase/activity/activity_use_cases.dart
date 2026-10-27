import '../../repository/activity_repository.dart';
import 'load_older_activity_use_case.dart';
import 'watch_recent_activity_use_case.dart';

/// 변경 기록 UseCase 묶음. 변경 기록 공급자와 화면이 읽는다. 기록을 남기는 것은 각 쓰기 저장소다.
class ActivityUseCases {
  ActivityUseCases(ActivityRepository activity)
    : watchRecentActivity = WatchRecentActivityUseCase(activity),
      loadOlderActivity = LoadOlderActivityUseCase(activity);

  final WatchRecentActivityUseCase watchRecentActivity;
  final LoadOlderActivityUseCase loadOlderActivity;
}
