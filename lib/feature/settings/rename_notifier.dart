import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/providers/usecases.dart';
import '../../domain/repository/settings_repository.dart';
import '../../domain/model/ledger.dart';
import '../../domain/model/member.dart';
import '../../domain/model/name_problem.dart';
import 'setting_form.dart';

/// 이름을 바꿀 대상: 가계부 이름이나 이름표 하나.
@immutable
sealed class RenameTarget {
  const RenameTarget();

  /// 이름의 최대 길이. 보안 규칙과 같다.
  int get maxLength;
}

/// 가계부 이름. 관리자만 바꾼다.
final class LedgerNameTarget extends RenameTarget {
  const LedgerNameTarget();

  @override
  int get maxLength => ledgerNameMaxLength;

  @override
  bool operator ==(Object other) => other is LedgerNameTarget;

  @override
  int get hashCode => (LedgerNameTarget).hashCode;
}

/// [slot] 자리의 이름표 이름. 관리자와 편집자가 두 장 모두 바꿀 수 있다.
final class MemberNameTarget extends RenameTarget {
  const MemberNameTarget(this.slot);

  final MemberSlot slot;

  @override
  int get maxLength => memberNameMaxLength;

  @override
  bool operator ==(Object other) =>
      other is MemberNameTarget && other.slot == slot;

  @override
  int get hashCode => slot.hashCode;
}

/// 이름 바꾸기 시트 상태. 문구는 넣지 않는다.
@immutable
class RenameState {
  const RenameState({
    this.saving = false,
    this.problem,
    this.failure,
    this.done = false,
  });

  final bool saving;

  /// 이름 칸 아래에 보여 줄 문제.
  final NameProblem? problem;

  /// 저장하지 못한 이유. 시트 안에 바로 보여주고, 다시 저장하거나 이름을 고치면 지운다.
  final SettingFormFailure? failure;

  /// 저장을 마쳤다. 시트가 닫힌다.
  final bool done;

  /// 저장 중이거나 이미 끝나 닫히는 중이다. 버튼을 막는다.
  bool get busy => saving || done;

  @override
  bool operator ==(Object other) =>
      other is RenameState &&
      other.saving == saving &&
      other.problem == problem &&
      other.failure == failure &&
      other.done == done;

  @override
  int get hashCode => Object.hash(saving, problem, failure, done);
}

final renameNotifierProvider = NotifierProvider.autoDispose
    .family<RenameNotifier, RenameState, RenameTarget>(RenameNotifier.new);

/// 이름 바꾸기 시트의 Notifier. 가계부 이름이나 이름표 이름을 바꾼다. 온라인에서만 된다.
///
/// 바꾼 이름은 구독 중인 가계부·이름표로 모든 탭(머리말, 항목의 '누가', 요약의 구성원별 소계)에 바로 보인다.
class RenameNotifier extends Notifier<RenameState> {
  RenameNotifier(this.target);

  final RenameTarget target;

  @override
  RenameState build() => const RenameState();

  /// 이름을 고치면 이름 칸의 문제와 실패 안내를 지운다.
  void nameEdited() {
    if (state.busy || (state.problem == null && state.failure == null)) return;
    state = const RenameState();
  }

  /// [name]으로 바꾼다. 앞뒤 공백은 뺀다. 지금 이름과 같으면 쓰지 않고 끝낸다
  /// (`RenameLedgerUseCase`·`RenameMemberUseCase`).
  ///
  /// 이름에 문제가 있으면 [RenameState.problem]으로 알리고 저장하지 않는다.
  Future<void> save(String name) async {
    final uid = ref.read(authUserProvider).value?.uid;
    final ledger = ref.read(currentLedgerProvider);
    if (state.busy || uid == null || ledger == null) return;
    final problem = nameProblemOf(name, maxLength: target.maxLength);
    if (problem != null) {
      state = RenameState(problem: problem);
      return;
    }
    state = const RenameState(saving: true);
    try {
      final refused = switch (target) {
        LedgerNameTarget() =>
          await ref
              .read(ledgerUseCasesProvider)
              .renameLedger(ledger: ledger, name: name, uid: uid),
        MemberNameTarget(:final slot) =>
          await ref
              .read(settingsUseCasesProvider)
              .renameMember(
                ledgerId: ledger.id,
                slot: slot,
                name: name,
                members: ref.read(membersProvider).value ?? const [],
                uid: uid,
              ),
      };
      if (!ref.mounted) return;
      state = refused == null
          ? const RenameState(done: true)
          : RenameState(problem: refused);
    } on SettingsWriteException catch (e) {
      if (!ref.mounted) return;
      state = RenameState(failure: settingFormFailureOf(e.reason));
    } catch (e) {
      debugPrint('이름 바꾸기 실패: $e');
      if (!ref.mounted) return;
      state = const RenameState(failure: SettingFormFailure.save);
    }
  }
}
