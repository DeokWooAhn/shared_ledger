import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/widget/sign_out.dart';
import '../../core/widget/tab_page.dart';
import '../../domain/model/auth_user.dart';
import 'setting_list.dart';

/// 화면에 보이는 로그인 방법 이름.
String signInMethodLabel(SignInMethod method) => switch (method) {
  SignInMethod.google => 'Google',
  SignInMethod.apple => 'Apple',
};

/// 계정 화면. 설정 탭 맨 아래의 '계정 · 로그아웃'으로 들어온다(탭 막대는 그대로 보인다).
///
/// 로그인 방법과 로그아웃. 탈퇴는 6단계에서 넣는다(docs/plan.md).
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signInMethod = ref.watch(authUserProvider).value?.signInMethod;
    return TabPage(
      header: const SubPageTitle('계정'),
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
              onTap: () => signOutWithFeedback(context, ref),
            ),
          ],
        ),
      ],
    );
  }
}
