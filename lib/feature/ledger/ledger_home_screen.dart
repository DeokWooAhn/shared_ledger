import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/widget/keep_all.dart';
import 'invite_sheet.dart';
import 'member_role_label.dart';

/// 가계부 홈. 월 요약 화면(3단계)이 생기기 전까지 가계부 정보와 초대만 보여준다.
class LedgerHomeScreen extends ConsumerWidget {
  const LedgerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(currentLedgerProvider);
    final user = ref.watch(authUserProvider).value;
    if (ledger == null || user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final theme = Theme.of(context);
    final role = ledger.roleOf(user.uid);
    return Scaffold(
      appBar: AppBar(
        title: Text(ledger.name),
        actions: [
          TextButton(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            child: const Text('로그아웃'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        ListTile(
                          title: const Text('내 역할'),
                          trailing: Text(
                            role == null ? '구성원 아님' : memberRoleLabel(role),
                          ),
                        ),
                        ListTile(
                          title: const Text('구성원'),
                          trailing: Text('${ledger.memberUids.length}명'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (ledger.canInvite(user.uid)) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('create-invite'),
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (_) =>
                          InviteSheet(ledgerId: ledger.id, uid: user.uid),
                    ),
                    child: const Text('초대 코드 만들기'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    keepAll('같이 쓸 사람 한 명을 초대할 수 있어요. 코드는 7일 동안 쓸 수 있어요.'),
                    style: theme.textTheme.labelSmall,
                  ),
                ] else if (ledger.isFull) ...[
                  const SizedBox(height: 16),
                  Text(
                    keepAll('두 사람이 함께 쓰고 있어요.'),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  keepAll('월 요약과 항목 입력 화면은 다음 단계에서 만들어요.'),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
