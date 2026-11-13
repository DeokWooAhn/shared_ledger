import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/widget/keep_all.dart';
import '../../core/widget/sign_out.dart';
import '../../core/widget/tab_page.dart';
import '../../domain/model/auth_user.dart';
import 'account_notifier.dart';
import 'setting_list.dart';

/// 화면에 보이는 로그인 방법 이름.
String signInMethodLabel(SignInMethod method) => switch (method) {
  SignInMethod.google => 'Google',
  SignInMethod.apple => 'Apple',
};

/// 탈퇴하지 못했을 때의 안내.
String accountFailureMessage(AccountFailure failure) => switch (failure) {
  AccountFailure.wrongAccount => '지금 계정과 다른 계정으로 로그인했어요.\n탈퇴할 계정으로 다시 시도해 주세요.',
  AccountFailure.offline => '인터넷에 연결된 뒤에 다시 시도해 주세요. 탈퇴는 연결돼 있을 때만 돼요.',
  AccountFailure.failed => '탈퇴하지 못했어요. 잠시 후 다시 시도해 주세요.',
};

/// 계정 화면. 설정 탭 맨 아래의 '계정 · 로그아웃'으로 들어온다(탭 막대는 그대로 보인다).
/// 가계부가 없으면 가계부 시작 화면의 '탈퇴하기'로 들어온다.
///
/// 로그인 방법, 로그아웃, 탈퇴하기(design/app/07). 탈퇴는 확인 창에서 한 번 더 묻고, 한 번 더 로그인한 뒤 내 가계부에서 모두 나가
/// 계정을 지운다(`AccountNotifier`). 지우면 로그인 화면으로 간다.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({this.backTooltip = '설정으로 돌아가기', super.key});

  /// 뒤로 단추의 설명. 가계부 시작에서 열면 바꾼다.
  final String backTooltip;

  // 탈퇴할지 묻고, 탈퇴한다고 하면 탈퇴한다. 지우면 이 화면이 사라지므로 알림은 미리 잡은 messenger로 띄운다.
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(accountNotifierProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final delete = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (delete != true) return;
    if (!await notifier.deleteAccount()) return;
    messenger.showSnackBar(
      SnackBar(
        key: const Key('account-deleted'),
        content: Text(keepAll('탈퇴했어요. 그동안 고마웠어요.')),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signInMethod = ref.watch(authUserProvider).value?.signInMethod;
    final deleting = ref.watch(
      accountNotifierProvider.select((s) => s.deleting),
    );
    final scheme = Theme.of(context).colorScheme;
    ref.listen(accountNotifierProvider.select((s) => s.failure), (_, failure) {
      if (failure == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('account-failure'),
          content: Text(keepAll(accountFailureMessage(failure))),
        ),
      );
      ref.read(accountNotifierProvider.notifier).failureShown();
    });
    return TabPage(
      header: SubPageTitle('계정', backTooltip: backTooltip),
      children: [
        SettingCard(
          children: [
            if (signInMethod != null)
              SettingRow(
                key: const Key('sign-in-method'),
                leading: const SettingIconTile(Icons.login),
                title: '로그인 방법',
                value: signInMethodLabel(signInMethod),
              ),
            SettingRow(
              key: const Key('sign-out'),
              leading: const SettingIconTile(Icons.logout),
              title: '로그아웃',
              onTap: deleting ? null : () => signOutWithFeedback(context, ref),
            ),
            SettingRow(
              key: const Key('delete-account'),
              leading: const SettingIconTile(
                Icons.person_remove_outlined,
                danger: true,
              ),
              title: '탈퇴하기',
              titleColor: scheme.error,
              trailing: deleting ? const _Progress() : null,
              onTap: deleting ? null : () => _confirmDelete(context, ref),
            ),
          ],
        ),
      ],
    );
  }
}

/// 탈퇴 확인 창. 무엇이 지워지고 무엇이 남는지 알리고, 한 번 더 로그인한다고 안내한다.
class _DeleteAccountDialog extends StatelessWidget {
  const _DeleteAccountDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('탈퇴할까요?'),
      content: Text(
        keepAll(
          '계정이 지워지고 되살릴 수 없어요.\n'
          '혼자 쓰는 가계부는 모든 내역과 함께 지워져요.\n'
          '함께 쓰는 가계부는 상대가 이어서 쓰고, 내가 적은 내역도 남아요.\n'
          '확인을 위해 한 번 더 로그인해요.',
        ),
        style: theme.textTheme.bodyMedium,
      ),
      actions: [
        TextButton(
          key: const Key('delete-account-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        TextButton(
          key: const Key('delete-account-confirm'),
          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('탈퇴하기'),
        ),
      ],
    );
  }
}

/// 줄 오른쪽의 작은 진행 표시.
class _Progress extends StatelessWidget {
  const _Progress();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 20,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}
