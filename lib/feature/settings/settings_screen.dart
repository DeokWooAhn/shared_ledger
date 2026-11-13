import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../domain/model/ledger.dart';
import '../../domain/model/member.dart';
import '../../core/widget/keep_all.dart';
import '../../core/widget/member_avatar.dart';
import '../../core/widget/tab_page.dart';
import '../../core/widget/wallet_glyph.dart';
import 'invite_sheet.dart';
import 'leave_ledger_notifier.dart';
import 'member_role_label.dart';
import 'rename_notifier.dart';
import 'rename_sheet.dart';
import 'setting_list.dart';
import 'setting_sheet.dart';

/// 설정 탭 안의 화면(분류, 결제수단·카드, 휴지통, 변경 기록, 계정)을 연다. 화면 이동은 router.dart가 정해서 넘겨준다.
typedef OpenSettingPage = void Function(BuildContext context);

/// 결제수단 줄의 설명에 이름을 몇 개까지 보여줄지. 더 있으면 '외 N개'로 줄인다.
const settingsPaymentNamesShown = 2;

/// 설정 탭(design/app/07). 가계부 이름, 두 사람의 이름표·역할과 초대, 가계부 관리(분류·결제수단),
/// 기록 관리(변경 기록·휴지통), 가계부 나가기, 맨 아래에 계정 화면으로 가는 '계정 · 로그아웃'.
///
/// 묶음 제목은 카드 밖에 굵게 두고, 다른 화면으로 가는 줄은 이름 아래에 작은 설명을 단다([SettingLinkRow]).
/// 가계부 이름은 관리자만, 이름표 이름은 관리자·편집자가 시트에서 바꾼다. 분류와 결제수단은 목록 화면에서 고친다.
/// 휴지통 줄에는 보고 있는 달에 지운 항목이 있으면 그 건수를 보여준다(홈·내역 탭과 같은 그달 구독).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({
    required this.openCategories,
    required this.openPaymentMethods,
    required this.openTrash,
    required this.openActivity,
    required this.openAccount,
    super.key,
  });

  final OpenSettingPage openCategories;
  final OpenSettingPage openPaymentMethods;
  final OpenSettingPage openTrash;
  final OpenSettingPage openActivity;
  final OpenSettingPage openAccount;

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
    final visibleMethods = methods?.where((m) => !m.hidden).toList();
    return TabPage(
      header: const TabTitle('설정'),
      children: [
        _LedgerCard(ledger: ledger, canRename: ledger.canRename(user.uid)),
        const SizedBox(height: 24),
        _MembersSection(
          ledger: ledger,
          uid: user.uid,
          members: members,
          canWrite: canWrite,
        ),
        const SizedBox(height: 24),
        SettingGroup(
          title: '가계부 관리',
          children: [
            SettingLinkRow(
              key: const Key('open-categories'),
              icon: Icons.sell_outlined,
              title: '분류',
              subtitle: categories == null
                  ? null
                  : '${categories.where((c) => !c.hidden).length}개',
              onTap: () => openCategories(context),
            ),
            SettingLinkRow(
              key: const Key('open-payment-methods'),
              icon: Icons.account_balance_wallet_outlined,
              title: '결제수단',
              subtitle: visibleMethods == null
                  ? null
                  : paymentNamesLabel([for (final m in visibleMethods) m.name]),
              onTap: () => openPaymentMethods(context),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SettingGroup(
          title: '기록 관리',
          children: [
            SettingLinkRow(
              key: const Key('open-activity'),
              icon: Icons.history,
              title: '변경 기록',
              onTap: () => openActivity(context),
            ),
            SettingLinkRow(
              key: const Key('open-trash'),
              icon: Icons.delete_outline,
              title: '휴지통',
              subtitle: trashed == null || trashed.isEmpty
                  ? null
                  : '${month.month}월 ${trashed.length}건',
              onTap: () => openTrash(context),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _LeaveLedgerCard(ledger: ledger, uid: user.uid, members: members),
        const SizedBox(height: 12),
        _AccountLink(onTap: () => openAccount(context)),
      ],
    );
  }
}

/// 나가지 못했을 때의 안내.
String leaveLedgerFailureMessage(LeaveLedgerFailure failure) =>
    switch (failure) {
      LeaveLedgerFailure.offline =>
        '인터넷에 연결된 뒤에 다시 시도해 주세요. 가계부 나가기는 연결돼 있을 때만 돼요.',
      LeaveLedgerFailure.failed => '가계부에서 나가지 못했어요. 잠시 후 다시 시도해 주세요.',
    };

/// 나간 뒤의 알림. 설정 탭은 사라지고 가계부 시작 화면(남은 가계부가 있으면 그 가계부)에서 보인다.
String leaveLedgerDoneMessage(LeaveOutcome outcome) => switch (outcome) {
  LeaveOutcome.memberLeaves || LeaveOutcome.handsOver => '가계부에서 나왔어요.',
  LeaveOutcome.closes => '가계부를 지우고 나왔어요.',
};

/// '가계부 나가기' 줄. 누르면 무엇이 일어나는지 확인 창으로 묻고 나간다(`LeaveLedgerNotifier`).
///
/// 초대로 들어온 사람은 그냥 나가고, 관리자는 상대에게 관리자를 넘기며, 혼자 쓰던 관리자가 나가면 가계부와 모든 내역이 지워진다.
class _LeaveLedgerCard extends ConsumerWidget {
  const _LeaveLedgerCard({
    required this.ledger,
    required this.uid,
    required this.members,
  });

  final Ledger ledger;
  final String uid;
  final List<Member> members;

  // 나갈지 묻고, 나간다고 하면 나간다. 나가면 설정 탭이 사라지므로 알림은 미리 잡은 messenger로 띄운다.
  Future<void> _confirmLeave(
    BuildContext context,
    WidgetRef ref,
    LeaveOutcome outcome,
  ) async {
    final notifier = ref.read(leaveLedgerNotifierProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (_) => _LeaveLedgerDialog(
        outcome: outcome,
        // 관리자를 넘겨받을 사람은 관리자가 아닌 자리에 있다.
        heirName: memberIn(members, ledger.ownerSlot.other).name,
      ),
    );
    if (leave != true) return;
    final left = await notifier.leave();
    if (left == null) return;
    messenger.showSnackBar(
      SnackBar(
        key: const Key('leave-ledger-done'),
        content: Text(keepAll(leaveLedgerDoneMessage(left))),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcome = ledger.leaveOutcomeOf(uid);
    final leaving = ref.watch(
      leaveLedgerNotifierProvider.select((s) => s.leaving),
    );
    final scheme = Theme.of(context).colorScheme;
    ref.listen(leaveLedgerNotifierProvider.select((s) => s.failure), (
      _,
      failure,
    ) {
      if (failure == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('leave-ledger-failure'),
          content: Text(keepAll(leaveLedgerFailureMessage(failure))),
        ),
      );
      ref.read(leaveLedgerNotifierProvider.notifier).failureShown();
    });
    if (outcome == null) return const SizedBox.shrink();
    return SettingCard(
      children: [
        SettingRow(
          key: const Key('leave-ledger'),
          leading: const SettingIconTile(Icons.logout, danger: true),
          title: '가계부 나가기',
          titleColor: scheme.error,
          trailing: leaving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: leaving ? null : () => _confirmLeave(context, ref, outcome),
        ),
      ],
    );
  }
}

/// 가계부 나가기 확인 창. 나가면 무엇이 일어나는지([outcome]) 알린다.
class _LeaveLedgerDialog extends StatelessWidget {
  const _LeaveLedgerDialog({required this.outcome, required this.heirName});

  final LeaveOutcome outcome;

  /// 관리자가 나가면 관리자를 넘겨받을 사람의 이름표 이름.
  final String heirName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (title, message, confirm) = switch (outcome) {
      LeaveOutcome.memberLeaves => (
        '가계부에서 나갈까요?',
        '나가면 이 가계부를 더 볼 수 없어요.\n'
            '내가 적은 내역은 가계부에 남아요.\n'
            '다시 들어오려면 관리자에게 새 초대 코드를 받아 주세요.',
        '나가기',
      ),
      LeaveOutcome.handsOver => (
        '가계부에서 나갈까요?',
        "나가면 '$heirName'에게 관리자를 넘겨요.\n"
            '내가 적은 내역은 가계부에 남아요.\n'
            '다시 들어오려면 새 초대 코드를 받아 주세요.',
        '나가기',
      ),
      LeaveOutcome.closes => (
        '가계부를 지울까요?',
        '혼자 쓰는 가계부라 나가면 가계부와 모든 내역이 지워져요.\n'
            '지우면 되살릴 수 없어요.',
        '지우고 나가기',
      ),
    };
    return AlertDialog(
      title: Text(title),
      content: Text(keepAll(message), style: theme.textTheme.bodyMedium),
      actions: [
        TextButton(
          key: const Key('leave-ledger-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        TextButton(
          key: const Key('leave-ledger-confirm'),
          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirm),
        ),
      ],
    );
  }
}

/// 결제수단 줄의 설명. 이름을 [settingsPaymentNamesShown]개까지 ' · '로 잇고, 더 있으면 '외 N개'를 붙인다.
/// 하나도 없으면 '없음'.
String paymentNamesLabel(List<String> names) {
  if (names.isEmpty) return '없음';
  final shown = names.take(settingsPaymentNamesShown).join(' · ');
  final rest = names.length - settingsPaymentNamesShown;
  return rest > 0 ? '$shown 외 $rest개' : shown;
}

/// 맨 아래의 작은 '계정 · 로그아웃'. 누르면 계정 화면(로그인 방법·로그아웃)으로 간다.
class _AccountLink extends StatelessWidget {
  const _AccountLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        key: const Key('open-account'),
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          textStyle: theme.textTheme.labelMedium,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        child: const Text('계정 · 로그아웃'),
      ),
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
    return SettingGroup(
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
      inset: 16,
      leading: MemberAvatar(member: member, size: 40),
      title: isMe ? '${member.name} (나)' : member.name,
      trailing: SettingChip(role == null ? '초대 전' : memberRoleLabel(role)),
      onTap: onTap,
    );
  }
}
