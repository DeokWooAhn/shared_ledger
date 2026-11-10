import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/providers/usecases.dart';
import '../../domain/repository/auth_repository.dart';
import '../../domain/repository/settings_repository.dart';

/// 탈퇴하지 못한 이유. 스낵바로 한 번 알린다.
enum AccountFailure {
  /// 다시 로그인할 때 다른 계정을 골랐다.
  wrongAccount,

  /// 가계부에서 나가기는 온라인에서만 된다.
  offline,
  failed,
}

/// 계정 화면 상태. 문구는 넣지 않는다.
@immutable
class AccountState {
  const AccountState({this.deleting = false, this.failure});

  /// 다시 로그인하고 가계부에서 나가 계정을 지우는 중이다.
  final bool deleting;

  /// 화면이 알린 뒤 [AccountNotifier.failureShown]으로 끈다.
  final AccountFailure? failure;

  @override
  bool operator ==(Object other) =>
      other is AccountState &&
      other.deleting == deleting &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(deleting, failure);
}

final accountNotifierProvider =
    NotifierProvider.autoDispose<AccountNotifier, AccountState>(
      AccountNotifier.new,
    );

/// 계정 화면의 Notifier. 탈퇴한다(`DeleteAccountUseCase`). 로그아웃은 `signOutWithFeedback`이 한다.
///
/// 탈퇴하면 로그아웃 상태가 되어 화면 이동 규칙(router.dart)이 로그인 화면으로 옮기고, 이 Notifier도 해제된다.
/// 그래서 탈퇴한 결과는 상태가 아니라 [deleteAccount]의 돌려준 값으로 알린다.
class AccountNotifier extends Notifier<AccountState> {
  @override
  AccountState build() => const AccountState();

  /// 다시 로그인한 뒤 내 가계부 모두에서 나가고 계정을 지운다. 지웠으면 true.
  ///
  /// 다시 로그인을 취소하면 아무것도 바꾸지 않고 false다. 실패하면 [AccountState.failure]로 알리고 false다.
  Future<bool> deleteAccount() async {
    final uid = ref.read(authUserProvider).value?.uid;
    final ledgers = ref.read(myLedgersProvider).value;
    if (state.deleting || uid == null || ledgers == null) return false;
    state = const AccountState(deleting: true);
    // 가계부에서 다 나가도 계정을 지울 때까지 시작 화면으로 옮기지 않게 한다. 실패를 알린 뒤에 끈다.
    // 지우면 이 Notifier가 먼저 해제될 수 있어서 미리 잡아 둔다(로그인한 사람이 바뀌면 저절로 꺼진다).
    final deletingAccount = ref.read(deletingAccountProvider.notifier)..start();
    try {
      final deleted = await ref
          .read(authUseCasesProvider)
          .deleteAccount(uid: uid, ledgerIds: [for (final l in ledgers) l.id]);
      if (ref.mounted) state = const AccountState();
      return deleted;
    } on AccountDeletionException catch (e) {
      if (!ref.mounted) return false;
      state = AccountState(
        failure: switch (e.reason) {
          AccountDeletionFailure.wrongAccount => AccountFailure.wrongAccount,
        },
      );
    } on SettingsWriteException catch (e) {
      if (!ref.mounted) return false;
      state = AccountState(
        failure: switch (e.reason) {
          SettingsWriteFailure.offline => AccountFailure.offline,
          SettingsWriteFailure.notFound => AccountFailure.failed,
        },
      );
    } on Exception catch (e) {
      debugPrint('탈퇴 실패: $e');
      if (!ref.mounted) return false;
      state = const AccountState(failure: AccountFailure.failed);
    } finally {
      deletingAccount.end();
    }
    return false;
  }

  void failureShown() => state = AccountState(deleting: state.deleting);
}
