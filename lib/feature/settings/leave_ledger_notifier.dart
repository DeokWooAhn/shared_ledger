import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/providers/usecases.dart';
import '../../domain/model/ledger.dart';
import '../../domain/repository/settings_repository.dart';

/// 가계부에서 나가지 못한 이유. 스낵바로 한 번 알린다.
enum LeaveLedgerFailure {
  /// 나가기는 온라인에서만 된다.
  offline,
  failed,
}

/// 가계부 나가기 상태. 문구는 넣지 않는다.
@immutable
class LeaveLedgerState {
  const LeaveLedgerState({this.leaving = false, this.failure});

  final bool leaving;

  /// 화면이 알린 뒤 [LeaveLedgerNotifier.failureShown]으로 끈다.
  final LeaveLedgerFailure? failure;

  @override
  bool operator ==(Object other) =>
      other is LeaveLedgerState &&
      other.leaving == leaving &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(leaving, failure);
}

final leaveLedgerNotifierProvider =
    NotifierProvider.autoDispose<LeaveLedgerNotifier, LeaveLedgerState>(
      LeaveLedgerNotifier.new,
    );

/// 설정 탭의 '가계부 나가기'. 지금 가계부에서 나간다(`LeaveLedgerUseCase`). 온라인에서만 된다.
///
/// 나가면 가계부 목록에서 빠져, 남은 가계부가 없으면 화면 이동 규칙(router.dart)이 가계부 시작 화면으로 옮긴다.
/// 설정 탭이 사라지며 이 Notifier도 해제되므로, 나간 결과는 상태가 아니라 [leave]의 돌려준 값으로 알린다.
class LeaveLedgerNotifier extends Notifier<LeaveLedgerState> {
  @override
  LeaveLedgerState build() => const LeaveLedgerState();

  /// 지금 가계부에서 나가고 무슨 일이 일어났는지 돌려준다. 나가지 못했거나 이미 나가는 중이면 null.
  ///
  /// 그사이 이미 나갔으면(다른 기기, 관리자가 내보냄) 실패로 알리지 않는다. 가계부 목록에서 곧 빠진다.
  Future<LeaveOutcome?> leave() async {
    final uid = ref.read(authUserProvider).value?.uid;
    final ledgerId = ref.read(currentLedgerProvider)?.id;
    if (state.leaving || uid == null || ledgerId == null) return null;
    state = const LeaveLedgerState(leaving: true);
    try {
      final outcome = await ref
          .read(ledgerUseCasesProvider)
          .leaveLedger(ledgerId: ledgerId, uid: uid);
      if (ref.mounted) state = const LeaveLedgerState();
      return outcome;
    } on SettingsWriteException catch (e) {
      if (!ref.mounted) return null;
      state = LeaveLedgerState(
        failure: switch (e.reason) {
          SettingsWriteFailure.offline => LeaveLedgerFailure.offline,
          SettingsWriteFailure.notFound => null,
        },
      );
    } on Exception catch (e) {
      debugPrint('가계부 나가기 실패: $e');
      if (!ref.mounted) return null;
      state = const LeaveLedgerState(failure: LeaveLedgerFailure.failed);
    }
    return null;
  }

  void failureShown() => state = LeaveLedgerState(leaving: state.leaving);
}
