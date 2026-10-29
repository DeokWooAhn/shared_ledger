import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/providers/usecases.dart';
import '../../domain/model/invite.dart';
import '../../domain/model/year_month.dart';

/// 진행 중인 동작.
enum LedgerStartAction { create, join }

/// 스낵바로 알릴 일회성 실패.
enum LedgerStartFailure { create, join }

/// 가계부 시작 화면 상태.
@immutable
class LedgerStartState {
  const LedgerStartState({this.pending, this.codeProblem, this.failure});

  /// 진행 중인 동작. null이면 아무것도 진행 중이 아니다.
  final LedgerStartAction? pending;

  /// 초대 코드 입력란 아래에 보여 줄 문제.
  final InviteCodeProblem? codeProblem;

  /// 스낵바로 알릴 실패. 화면이 알린 뒤 [LedgerStartNotifier.failureShown]으로 끈다.
  final LedgerStartFailure? failure;

  bool get busy => pending != null;

  @override
  bool operator ==(Object other) =>
      other is LedgerStartState &&
      other.pending == pending &&
      other.codeProblem == codeProblem &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(pending, codeProblem, failure);
}

final ledgerStartNotifierProvider =
    NotifierProvider.autoDispose<LedgerStartNotifier, LedgerStartState>(
      LedgerStartNotifier.new,
    );

/// 가계부 시작(만들기·입장 화면)의 Notifier. 새로 만들거나 초대 코드로 참여한다.
///
/// 성공하면 가계부 목록이 바뀌고 화면 이동 규칙(router.dart)이 홈으로 옮긴다.
class LedgerStartNotifier extends Notifier<LedgerStartState> {
  @override
  LedgerStartState build() => const LedgerStartState();

  /// 나를 관리자로 하는 가계부를 처음 쓸 달 [firstMonth]와 함께 만든다. 이름 검사는 화면의 폼이 끝낸 뒤 부른다.
  /// 이름 정리와 이름표의 내 이름은 `CreateLedgerUseCase`가 정한다.
  Future<void> create(String name, {required YearMonth firstMonth}) async {
    final user = ref.read(authUserProvider).value;
    if (state.busy || user == null) return;
    state = LedgerStartState(
      pending: LedgerStartAction.create,
      codeProblem: state.codeProblem,
    );
    try {
      await ref
          .read(ledgerUseCasesProvider)
          .createLedger(name: name, owner: user, firstMonth: firstMonth);
      if (!ref.mounted) return;
      state = LedgerStartState(codeProblem: state.codeProblem);
    } catch (e) {
      debugPrint('가계부 만들기 실패: $e');
      if (!ref.mounted) return;
      state = LedgerStartState(
        codeProblem: state.codeProblem,
        failure: LedgerStartFailure.create,
      );
    }
  }

  /// 입력한 초대 코드로 참여한다. 입력 문제와 참여 실패는 [LedgerStartState.codeProblem]으로,
  /// 예상하지 못한 오류는 [LedgerStartState.failure]로 알린다.
  ///
  /// 모양이 다른 코드는 서버에 묻지 않고 바로 알린다([inviteCodeProblemOf]).
  Future<void> join(String input) async {
    final uid = ref.read(authUserProvider).value?.uid;
    if (state.busy || uid == null) return;
    final problem = inviteCodeProblemOf(input);
    if (problem != null) {
      state = LedgerStartState(codeProblem: problem);
      return;
    }
    state = const LedgerStartState(pending: LedgerStartAction.join);
    try {
      final refused = await ref
          .read(ledgerUseCasesProvider)
          .joinLedger(input: input, uid: uid);
      if (!ref.mounted) return;
      state = LedgerStartState(codeProblem: refused);
    } catch (e) {
      debugPrint('가계부 참여 실패: $e');
      if (!ref.mounted) return;
      state = const LedgerStartState(failure: LedgerStartFailure.join);
    }
  }

  /// 초대 코드를 고치면 이전 안내를 지운다.
  void codeEdited() {
    if (state.codeProblem == null) return;
    state = LedgerStartState(pending: state.pending, failure: state.failure);
  }

  /// 화면이 실패를 알린 뒤 부른다.
  void failureShown() => state = LedgerStartState(
    pending: state.pending,
    codeProblem: state.codeProblem,
  );
}
