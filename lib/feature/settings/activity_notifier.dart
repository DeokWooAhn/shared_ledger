import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/providers/usecases.dart';
import '../../domain/model/activity.dart';

/// 변경 기록 목록을 받은 상태.
enum ActivityLoad {
  /// 처음 목록을 받는 중.
  loading,

  /// 처음 목록을 받지 못했다.
  failed,
  ready,
}

/// 스낵바로 한 번 알릴 실패.
enum ActivityFailure {
  /// '더 보기'로 더 오래된 기록을 읽지 못했다.
  loadMore,
}

/// 변경 기록 화면 상태. 최근 기록(실시간)과 '더 보기'로 읽은 기록을 합친 목록을 둔다.
@immutable
class ActivityState {
  const ActivityState({
    this.items = const [],
    this.load = ActivityLoad.loading,
    this.hasMore = false,
    this.loadingMore = false,
    this.loadedOlder = false,
    this.failure,
  });

  /// 새것부터. 아직 서버에 닿지 않은 기록(시간 없음)이 맨 앞이다.
  final List<Activity> items;
  final ActivityLoad load;

  /// 더 오래된 기록이 남아 있을 수 있는지. 마지막으로 읽은 묶음이 꽉 찼으면 true.
  final bool hasMore;
  final bool loadingMore;

  /// '더 보기'로 한 번이라도 읽었는지. 그 뒤로는 [hasMore]를 마지막 '더 보기' 결과로 정한다.
  final bool loadedOlder;

  /// 화면이 알린 뒤 [ActivityNotifier.failureShown]으로 끈다.
  final ActivityFailure? failure;

  ActivityState copyWith({
    List<Activity>? items,
    ActivityLoad? load,
    bool? hasMore,
    bool? loadingMore,
    bool? loadedOlder,
  }) => ActivityState(
    items: items ?? this.items,
    load: load ?? this.load,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    loadedOlder: loadedOlder ?? this.loadedOlder,
    failure: failure,
  );

  /// [failure]만 바꾼 상태.
  ActivityState withFailure(ActivityFailure? failure) => ActivityState(
    items: items,
    load: load,
    hasMore: hasMore,
    loadingMore: loadingMore,
    loadedOlder: loadedOlder,
    failure: failure,
  );

  @override
  bool operator ==(Object other) =>
      other is ActivityState &&
      listEquals(other.items, items) &&
      other.load == load &&
      other.hasMore == hasMore &&
      other.loadingMore == loadingMore &&
      other.loadedOlder == loadedOlder &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(items),
    load,
    hasMore,
    loadingMore,
    loadedOlder,
    failure,
  );
}

/// [current]에 [incoming]을 더한 목록. 같은 id는 [incoming]으로 바꾸고, 새것부터 정렬한다.
///
/// 기록은 추가만 되고 바뀌지 않아서, 최근 목록에서 밀려난 기록도 지우지 않고 남겨 둔다.
/// 그래야 '더 보기'로 읽은 기록과 최근 목록 사이가 비지 않는다. 시간이 없는(서버에 닿기 전) 기록이 맨 앞이다.
List<Activity> mergeActivities(
  List<Activity> current,
  List<Activity> incoming,
) {
  final byId = {
    for (final item in current) item.id: item,
    for (final item in incoming) item.id: item,
  };
  return [...byId.values]..sort((a, b) {
    final (aAt, bAt) = (a.at, b.at);
    if (aAt == null || bAt == null) {
      final pending = (aAt == null ? 0 : 1) - (bAt == null ? 0 : 1);
      return pending != 0 ? pending : b.id.compareTo(a.id);
    }
    final byTime = bAt.compareTo(aAt);
    return byTime != 0 ? byTime : b.id.compareTo(a.id);
  });
}

final activityNotifierProvider =
    NotifierProvider.autoDispose<ActivityNotifier, ActivityState>(
      ActivityNotifier.new,
    );

/// 변경 기록 화면의 Notifier. 최근 [activityPageSize]건을 실시간으로 받고, '더 보기'로 더 오래된 기록을 읽어 붙인다.
class ActivityNotifier extends Notifier<ActivityState> {
  @override
  ActivityState build() {
    // 가계부가 바뀌면 앞 가계부의 기록을 버리고 처음부터 받는다.
    ref.watch(currentLedgerProvider.select((ledger) => ledger?.id));
    ref.listen(recentActivityProvider, (_, next) => state = _withRecent(next));
    return _withRecent(ref.read(recentActivityProvider), const ActivityState());
  }

  ActivityState _withRecent(
    AsyncValue<List<Activity>> recent, [
    ActivityState? from,
  ]) {
    final current = from ?? state;
    return switch (recent) {
      AsyncData(:final value) => current.copyWith(
        items: mergeActivities(current.items, value),
        load: ActivityLoad.ready,
        hasMore: current.loadedOlder
            ? current.hasMore
            : value.length >= activityPageSize,
      ),
      // 이미 보이는 목록이 있으면 그대로 두고, 처음 받다가 실패했을 때만 실패로 그린다.
      AsyncError() when current.load != ActivityLoad.ready => current.copyWith(
        load: ActivityLoad.failed,
      ),
      _ => current,
    };
  }

  /// 지금 목록에서 가장 오래된 기록보다 먼저 남긴 기록을 [activityPageSize]건 더 읽는다.
  Future<void> loadMore() async {
    final ledgerId = ref.read(currentLedgerProvider)?.id;
    final oldest = state.items.reversed
        .map((item) => item.at)
        .nonNulls
        .firstOrNull;
    if (state.loadingMore ||
        !state.hasMore ||
        ledgerId == null ||
        oldest == null) {
      return;
    }
    state = state.copyWith(loadingMore: true);
    try {
      final older = await ref
          .read(activityUseCasesProvider)
          .loadOlderActivity(ledgerId, before: oldest);
      if (!ref.mounted) return;
      state = state.copyWith(
        items: mergeActivities(state.items, older),
        loadingMore: false,
        loadedOlder: true,
        hasMore: older.length >= activityPageSize,
      );
    } catch (e) {
      debugPrint('변경 기록 더 읽기 실패: $e');
      if (!ref.mounted) return;
      state = state
          .copyWith(loadingMore: false)
          .withFailure(ActivityFailure.loadMore);
    }
  }

  /// 화면이 실패를 알린 뒤 부른다.
  void failureShown() => state = state.withFailure(null);
}
