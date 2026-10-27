import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repository/entries_repository.dart';
import '../../core/providers/providers.dart';
import '../../core/providers/usecases.dart';
import '../../domain/usecase/month/plan_month_fill_use_case.dart';

/// 보고 있는 달에 고정 지출로 채울 것. 채울 것이 없거나 채울 수 없으면 null. 정하는 규칙은 `PlanMonthFillUseCase`다.
///
/// 그달 항목과 고정 지출은 UseCase가 꺼낼 때만 구독한다(보기 전용이거나 채우지 않는 달에는 읽지 않는다).
/// 달을 옮긴 직후에는 이전 달 항목으로 판단하지 않는다(받은 값만 쓴다).
/// 값이 바뀔 때만 알리므로, 홈 틀이 듣다가 [MonthFillNotifier.fill]로 넘긴다.
final plannedFillProvider = Provider<PlannedFill?>(
  (ref) => ref
      .watch(monthUseCasesProvider)
      .planMonthFill(
        ledger: ref.watch(currentLedgerProvider),
        canWrite: ref.watch(myRoleProvider)?.canWrite ?? false,
        month: ref.watch(selectedMonthProvider),
        ledgerMonths: ref.watch(ledgerMonthsProvider),
        entries: () => switch (ref.watch(monthLedgerProvider)) {
          AsyncData(:final value) => value,
          _ => null,
        },
        templates: () => switch (ref.watch(templatesProvider)) {
          AsyncData(:final value) => value,
          _ => null,
        },
      ),
);

/// 그달 기본 월 지출을 채우는 Notifier. 홈 틀이 떠 있는 동안 계속 살아 있게 autoDispose를 쓰지 않는다.
final monthFillNotifierProvider = NotifierProvider<MonthFillNotifier, bool>(
  MonthFillNotifier.new,
);

/// 보고 있는 달에 빠진 기본 월 지출을 고정 지출로 채운다. 상태는 채우는 중인지다.
///
/// 실패는 화면에 알리지 않는다. 오프라인이면 다음에 그달을 다시 열 때 채우고, 그동안 그달은 빈 달로 보인다.
/// 채운 항목은 그달 구독([monthLedgerProvider])으로 요약·항목 탭에 들어온다.
class MonthFillNotifier extends Notifier<bool> {
  // 채우는 중에 들어온 가장 최근 요청. 지금 채우기가 끝나면 이어서 채운다.
  PlannedFill? _waiting;

  @override
  bool build() => false;

  /// [fill]의 고정 지출로 그달 기본 월 지출을 만든다. 이미 있는 것은 저장소가 건너뛴다.
  ///
  /// 채우는 중에 다른 달로 옮기거나 고정 지출을 더하면 새 요청이 온다. 그동안 [plannedFillProvider]는
  /// 다시 바뀌지 않을 수 있어서 버리지 않고, 가장 최근 요청 하나만 남겨 두었다가 끝난 뒤 채운다.
  /// 방금 채운 것과 같은 요청은 건너뛴다.
  Future<void> fill(PlannedFill fill) async {
    final uid = ref.read(authUserProvider).value?.uid;
    if (uid == null) return;
    if (state) {
      _waiting = fill;
      return;
    }
    state = true;
    var next = fill;
    try {
      while (true) {
        await _fillOnce(next, uid);
        final waiting = _waiting;
        _waiting = null;
        if (!ref.mounted || waiting == null || waiting == next) break;
        next = waiting;
      }
    } finally {
      if (ref.mounted) state = false;
    }
  }

  Future<void> _fillOnce(PlannedFill fill, String uid) async {
    try {
      await ref
          .read(monthUseCasesProvider)
          .fillMonthFromTemplates(fill, uid: uid);
    } on EntryWriteException catch (e) {
      debugPrint('그달 기본 월 지출을 채우지 못해 다음에 다시 열 때 채움: ${e.reason}');
    } catch (e) {
      debugPrint('그달 기본 월 지출 채우기 실패: $e');
    }
  }
}
