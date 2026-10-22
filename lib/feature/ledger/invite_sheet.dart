import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/model/ledger.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widget/keep_all.dart';
import 'invite_controller.dart';
import 'member_role_label.dart';

/// 초대 코드가 언제까지 유효한지 보여주는 문구. 예: '10월 28일 오후 3:05까지 쓸 수 있어요'
String inviteExpiryText(DateTime expiresAt) {
  final local = expiresAt.toLocal();
  final period = local.hour < 12 ? '오전' : '오후';
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.month}월 ${local.day}일 $period $hour:$minute까지 쓸 수 있어요';
}

/// 초대 코드 만들기 시트. 들어올 사람의 역할을 고르고 코드를 만든다.
///
/// 디자인에서는 설정 화면(07)에 있는 기능이다. 설정 화면을 만들 때 그쪽으로 옮긴다.
class InviteSheet extends ConsumerStatefulWidget {
  const InviteSheet({required this.ledgerId, required this.uid, super.key});

  final String ledgerId;
  final String uid;

  @override
  ConsumerState<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<InviteSheet> {
  // 복사했다는 표시는 화면에서만 쓰는 상태라 위젯이 갖는다.
  bool _copied = false;

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(inviteControllerProvider);
    final controller = ref.read(inviteControllerProvider.notifier);
    final invite = state.invite;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: invite == null
              ? [
                  Text(
                    keepAll('초대 코드 만들기'),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    keepAll('상대가 들어오면 받을 역할을 골라 주세요.'),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<MemberRole>(
                    key: const Key('invite-role'),
                    segments: [
                      for (final role in [MemberRole.editor, MemberRole.viewer])
                        ButtonSegment(
                          value: role,
                          label: Text(memberRoleLabel(role)),
                        ),
                    ],
                    selected: {state.role},
                    onSelectionChanged: state.pending
                        ? null
                        : (selection) => controller.selectRole(selection.first),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    keepAll(
                      state.role == MemberRole.editor
                          ? '편집자는 항목을 적고 고칠 수 있어요.'
                          : '보기 전용은 보기만 할 수 있어요.',
                    ),
                    style: theme.textTheme.labelSmall,
                  ),
                  if (state.failed) ...[
                    const SizedBox(height: 12),
                    Text(
                      keepAll('초대 코드를 만들지 못했어요. 잠시 후 다시 시도해 주세요.'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const Key('confirm-invite'),
                    onPressed: state.pending
                        ? null
                        : () => controller.create(
                            ledgerId: widget.ledgerId,
                            createdBy: widget.uid,
                          ),
                    child: const Text('만들기'),
                  ),
                ]
              : [
                  Text(
                    keepAll('초대 코드를 만들었어요'),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    keepAll(
                      '상대에게 이 코드를 보내 주세요. '
                      '${memberRoleWithRo(invite.role)} 들어와요.',
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: SelectableText(
                        invite.code,
                        key: const Key('invite-code-value'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    keepAll(inviteExpiryText(invite.expiresAt)),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: context.appColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    key: const Key('copy-invite'),
                    onPressed: () => _copy(invite.code),
                    icon: Icon(_copied ? Icons.check : Icons.copy),
                    label: Text(_copied ? '복사했어요' : '코드 복사하기'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('닫기'),
                  ),
                ],
        ),
      ),
    );
  }
}
