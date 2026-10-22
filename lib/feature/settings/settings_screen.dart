import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/model/ledger.dart';
import '../../core/model/member.dart';
import '../../core/widget/keep_all.dart';
import '../../core/widget/member_avatar.dart';
import '../../core/widget/sign_out.dart';
import '../../core/widget/tab_page.dart';
import '../../core/widget/wallet_glyph.dart';
import 'invite_sheet.dart';
import 'member_role_label.dart';

/// 설정 탭. 지금은 가계부 정보, 두 사람의 이름표·역할, 초대, 로그아웃만 있다.
/// 분류·결제수단·휴지통·변경 기록과 이름 바꾸기는 설정 단계에서 넣는다.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(currentLedgerProvider);
    final user = ref.watch(authUserProvider).value;
    if (ledger == null || user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final members = ref.watch(membersProvider).value ?? const [];
    return TabPage(
      header: const TabTitle('설정'),
      children: [
        _LedgerCard(ledger: ledger),
        const SizedBox(height: 12),
        _MembersSection(ledger: ledger, uid: user.uid, members: members),
        const SizedBox(height: 12),
        _Section(
          title: '계정',
          children: [
            ListTile(
              key: const Key('sign-out'),
              contentPadding: EdgeInsets.zero,
              leading: const _IconTile(Icons.logout),
              title: const Text('로그아웃'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => signOutWithFeedback(context, ref),
            ),
          ],
        ),
      ],
    );
  }
}

class _LedgerCard extends StatelessWidget {
  const _LedgerCard({required this.ledger});

  final Ledger ledger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    '구성원 ${ledger.memberUids.length}명',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 두 사람의 이름표와 역할, 초대 코드 만들기.
class _MembersSection extends StatelessWidget {
  const _MembersSection({
    required this.ledger,
    required this.uid,
    required this.members,
  });

  final Ledger ledger;
  final String uid;
  final List<Member> members;

  // 이름표를 아직 못 받았거나 이름표가 생기기 전에 만든 가계부면 역할 이름으로 그린다.
  Member _memberOf(MemberSlot slot) =>
      members.where((m) => m.slot == slot).firstOrNull ??
      Member(
        slot: slot,
        name: switch (slot) {
          MemberSlot.owner => memberRoleLabel(MemberRole.owner),
          MemberSlot.partner => defaultPartnerName,
        },
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Section(
      title: '구성원',
      children: [
        for (final slot in MemberSlot.values) ...[
          if (slot != MemberSlot.values.first)
            Divider(height: 1, color: theme.colorScheme.outline),
          _MemberRow(
            member: _memberOf(slot),
            isMe: ledger.uidOf(slot) == uid,
            role: switch (ledger.uidOf(slot)) {
              final memberUid? => ledger.roleOf(memberUid),
              null => null,
            },
          ),
        ],
        if (ledger.canInvite(uid)) ...[
          const SizedBox(height: 12),
          FilledButton.tonal(
            key: const Key('create-invite'),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => InviteSheet(ledgerId: ledger.id, uid: uid),
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
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isMe,
    required this.role,
  });

  final Member member;
  final bool isMe;

  /// null이면 아직 들어오지 않은 자리다.
  final MemberRole? role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = this.role;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          MemberAvatar(member: member, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              isMe ? '${member.name} (나)' : member.name,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          _Chip(role == null ? '초대 전' : memberRoleLabel(role)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          text,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// 제목이 있는 설정 묶음 카드.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            const SizedBox(height: 4),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: scheme.onSurface),
    );
  }
}
