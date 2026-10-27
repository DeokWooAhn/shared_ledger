import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../domain/model/auth_user.dart';
import '../../domain/model/ledger.dart';
import '../../domain/model/member.dart';
import '../../core/widget/keep_all.dart';
import '../../core/widget/member_avatar.dart';
import '../../core/widget/sign_out.dart';
import '../../core/widget/tab_page.dart';
import '../../core/widget/wallet_glyph.dart';
import 'invite_sheet.dart';
import 'member_role_label.dart';
import 'rename_notifier.dart';
import 'rename_sheet.dart';
import 'setting_list.dart';
import 'setting_sheet.dart';

/// 설정 탭 안의 화면(분류, 결제수단·카드, 휴지통, 변경 기록)을 연다. 화면 이동은 router.dart가 정해서 넘겨준다.
typedef OpenSettingPage = void Function(BuildContext context);

/// 화면에 보이는 로그인 방법 이름.
String signInMethodLabel(SignInMethod method) => switch (method) {
  SignInMethod.google => 'Google',
  SignInMethod.apple => 'Apple',
};

/// 설정 탭(design/app/07). 가계부 이름, 두 사람의 이름표·역할과 초대, 분류·결제수단, 휴지통·변경 기록,
/// 로그인 방법·로그아웃.
///
/// 가계부 이름은 관리자만, 이름표 이름은 관리자·편집자가 시트에서 바꾼다. 분류와 결제수단은 목록 화면에서 고친다.
/// 휴지통 줄에는 보고 있는 달의 휴지통 건수를 보여준다(요약·항목 탭과 같은 그달 구독). 탈퇴는 6단계에서 넣는다(docs/plan.md).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({
    required this.openCategories,
    required this.openPaymentMethods,
    required this.openTrash,
    required this.openActivity,
    super.key,
  });

  final OpenSettingPage openCategories;
  final OpenSettingPage openPaymentMethods;
  final OpenSettingPage openTrash;
  final OpenSettingPage openActivity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(currentLedgerProvider);
    final user = ref.watch(authUserProvider).value;
    if (ledger == null || user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final members = ref.watch(membersProvider).value ?? const [];
    final canWrite = ledger.roleOf(user.uid)?.canWrite ?? false;
    final categories = ref.watch(categoriesProvider).value;
    final methods = ref.watch(paymentMethodsProvider).value;
    final month = ref.watch(selectedMonthProvider);
    final trashed = ref.watch(monthLedgerProvider).value?.trashed;
    final signInMethod = user.signInMethod;
    return TabPage(
      header: const TabTitle('설정'),
      children: [
        _LedgerCard(ledger: ledger, canRename: ledger.canRename(user.uid)),
        const SizedBox(height: 12),
        _MembersSection(
          ledger: ledger,
          uid: user.uid,
          members: members,
          canWrite: canWrite,
        ),
        const SizedBox(height: 12),
        SettingCard(
          title: '가계부',
          children: [
            SettingRow(
              key: const Key('open-categories'),
              leading: const SettingIconTile(Icons.sell_outlined),
              title: '분류',
              value: categories == null
                  ? null
                  : '${categories.where((c) => !c.hidden).length}개',
              onTap: () => openCategories(context),
            ),
            SettingRow(
              key: const Key('open-payment-methods'),
              leading: const SettingIconTile(Icons.credit_card),
              title: '결제수단·카드',
              value: methods == null
                  ? null
                  : '${methods.where((m) => !m.hidden).length}개',
              onTap: () => openPaymentMethods(context),
            ),
            SettingRow(
              key: const Key('open-trash'),
              leading: const SettingIconTile(Icons.delete_outline),
              title: '휴지통',
              value: trashed == null
                  ? null
                  : '${month.month}월 ${trashed.length}건',
              onTap: () => openTrash(context),
            ),
            SettingRow(
              key: const Key('open-activity'),
              leading: const SettingIconTile(Icons.history),
              title: '변경 기록',
              onTap: () => openActivity(context),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingCard(
          title: '계정',
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

/// 가계부 이름과 구성원 수, 만든 달. 관리자에게는 이름을 바꾸는 연필 단추가 있다.
class _LedgerCard extends StatelessWidget {
  const _LedgerCard({required this.ledger, required this.canRename});

  final Ledger ledger;
  final bool canRename;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final createdAt = ledger.createdAt?.toLocal();
    final caption = [
      '구성원 ${ledger.memberUids.length}명',
      if (createdAt != null) '${createdAt.year}년 ${createdAt.month}월부터',
    ].join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.tertiary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: WalletGlyph(size: 28, color: scheme.onTertiary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ledger.name, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    keepAll(caption),
                    key: const Key('ledger-caption'),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (canRename)
              IconButton(
                key: const Key('rename-ledger'),
                tooltip: '가계부 이름 바꾸기',
                onPressed: () => showSettingSheet<void>(
                  context,
                  (_) => RenameSheet(
                    target: const LedgerNameTarget(),
                    initialName: ledger.name,
                  ),
                ),
                icon: Icon(Icons.edit_outlined, color: scheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}

/// 두 사람의 이름표와 역할, 초대 코드 만들기. 관리자·편집자는 이름표를 눌러 이름을 바꾼다.
class _MembersSection extends StatelessWidget {
  const _MembersSection({
    required this.ledger,
    required this.uid,
    required this.members,
    required this.canWrite,
  });

  final Ledger ledger;
  final String uid;
  final List<Member> members;
  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SettingCard(
      title: '구성원',
      footer: [
        if (ledger.canInvite(uid)) ...[
          const SizedBox(height: 12),
          FilledButton.tonal(
            key: const Key('create-invite'),
            // 다른 설정 시트처럼 떠 있는 탭 막대까지 덮게 띄운다.
            onPressed: () => showSettingSheet<void>(
              context,
              (_) => InviteSheet(ledgerId: ledger.id, uid: uid),
            ),
            child: const Text('초대 코드 만들기'),
          ),
          const SizedBox(height: 8),
          Text(
            keepAll('만들 때 편집자·보기 전용 중에서 고르고, 7일 동안 쓸 수 있어요.'),
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: 8),
        ] else if (ledger.isFull) ...[
          const SizedBox(height: 8),
          Text(keepAll('두 사람이 함께 쓰고 있어요.'), style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
        ],
      ],
      children: [
        for (final slot in MemberSlot.values)
          _MemberRow(
            key: Key('member-${slot.name}'),
            member: memberIn(members, slot),
            isMe: ledger.uidOf(slot) == uid,
            role: switch (ledger.uidOf(slot)) {
              final memberUid? => ledger.roleOf(memberUid),
              null => null,
            },
            onTap: canWrite
                ? () => showSettingSheet<void>(
                    context,
                    (_) => RenameSheet(
                      target: MemberNameTarget(slot),
                      initialName: memberIn(members, slot).name,
                    ),
                  )
                : null,
          ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isMe,
    required this.role,
    required this.onTap,
    super.key,
  });

  final Member member;
  final bool isMe;

  /// null이면 아직 들어오지 않은 자리다.
  final MemberRole? role;

  /// 이름을 바꾸는 시트를 연다. null이면 누를 수 없다(보기 전용).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final role = this.role;
    return SettingRow(
      leading: MemberAvatar(member: member, size: 40),
      title: isMe ? '${member.name} (나)' : member.name,
      trailing: SettingChip(role == null ? '초대 전' : memberRoleLabel(role)),
      onTap: onTap,
    );
  }
}
