import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/usecases.dart';
import '../../domain/model/invite.dart';
import '../../domain/model/ledger.dart';

/// 초대 코드 만들기 시트 상태.
@immutable
class InviteState {
  const InviteState({
    this.role = MemberRole.editor,
    this.pending = false,
    this.failed = false,
    this.invite,
  });

  /// 들어올 사람이 받을 역할. 편집자나 보기 전용이다.
  final MemberRole role;
  final bool pending;

  /// 만들기에 실패했다. 시트 안에 바로 보여주므로 일회성 이벤트가 아니다.
  final bool failed;

  /// 만들어진 초대. 있으면 시트가 코드를 보여준다.
  final Invite? invite;

  @override
  bool operator ==(Object other) =>
      other is InviteState &&
      other.role == role &&
      other.pending == pending &&
      other.failed == failed &&
      other.invite == invite;

  @override
  int get hashCode => Object.hash(role, pending, failed, invite);
}

final inviteNotifierProvider =
    NotifierProvider.autoDispose<InviteNotifier, InviteState>(
      InviteNotifier.new,
    );

/// 초대 코드 만들기 시트의 Notifier. 시트를 닫으면 해제된다.
class InviteNotifier extends Notifier<InviteState> {
  @override
  InviteState build() => const InviteState();

  /// 들어올 사람이 받을 역할을 고른다. 코드를 만든 뒤에는 바꿀 수 없다.
  void selectRole(MemberRole role) {
    assert(role != MemberRole.owner, '관리자 역할로는 초대할 수 없다');
    if (state.pending || state.invite != null) return;
    state = InviteState(role: role);
  }

  /// 고른 역할로 [ledgerId]의 초대 코드를 만든다. 실패하면 [InviteState.failed]를 켠다.
  Future<void> create({
    required String ledgerId,
    required String createdBy,
  }) async {
    if (state.pending || state.invite != null) return;
    final role = state.role;
    state = InviteState(role: role, pending: true);
    try {
      final invite = await ref
          .read(ledgerUseCasesProvider)
          .createInvite(ledgerId: ledgerId, role: role, createdBy: createdBy);
      if (!ref.mounted) return;
      state = InviteState(role: role, invite: invite);
    } catch (e) {
      debugPrint('초대 코드 만들기 실패: $e');
      if (!ref.mounted) return;
      state = InviteState(role: role, failed: true);
    }
  }
}
