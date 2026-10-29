import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../domain/model/ledger_entries.dart';
import '../../domain/model/member.dart';
import '../../domain/model/payment_method.dart';
import '../../domain/model/trashed_entry.dart';
import '../../domain/model/year_month.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widget/entry_kind_label.dart';
import '../../core/widget/keep_all.dart';
import '../../core/widget/member_avatar.dart';
import '../../core/widget/month_header.dart';
import '../../core/widget/tab_page.dart';
import '../../domain/format/won.dart';
import 'setting_list.dart';
import 'trash_notifier.dart';

String trashFailureMessage(TrashFailure failure) => switch (failure) {
  TrashFailure.offline => '인터넷에 연결된 뒤에 다시 시도해 주세요. 휴지통은 연결돼 있을 때만 바꿀 수 있어요.',
  TrashFailure.gone => '그사이 되살렸거나 지운 항목이에요.',
  TrashFailure.restore => '되살리지 못했어요. 잠시 후 다시 시도해 주세요.',
  TrashFailure.purge => '지우지 못했어요. 잠시 후 다시 시도해 주세요.',
};

String trashNoticeMessage(TrashNotice notice) => switch (notice) {
  TrashNotice.restored => '되살렸어요. 항목 목록과 합계에 다시 들어가요.',
  TrashNotice.purged => '완전히 지웠어요.',
};

/// 자동 삭제까지 남은 날 안내. 하루가 안 남았으면 '곧'이다. 예: '29일 뒤 자동으로 지워져요'
String trashPurgeLabel(DateTime purgeAt, DateTime now) {
  final days = (purgeAt.difference(now).inHours / 24).ceil();
  return days <= 0 ? '곧 자동으로 지워져요' : '$days일 뒤 자동으로 지워져요';
}

/// 휴지통 화면. 설정 탭에서 들어온다(탭 막대는 그대로 보인다).
///
/// 보고 있는 달의 휴지통 항목을 최근에 넣은 것부터 보여주고, 달 머리말로 다른 달을 본다. 그달 구독을 요약·항목 탭과
/// 같이 써서 읽기가 늘지 않는다. 관리자·편집자는 되살리거나 완전히 지우고(확인 후), 보기 전용은 보기만 한다.
/// 넣은 지 30일이 지나면 자동으로 지워진다. 반복 설정이 남아 있는 이번 달 이후 고정 지출은 남겨 둔다([staysInTrash]).
class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(monthLedgerProvider);
    final notifier = ref.read(trashNotifierProvider.notifier);
    ref
      ..listen(trashNotifierProvider.select((s) => s.failure), (_, failure) {
        if (failure == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: const Key('trash-failure'),
            content: Text(keepAll(trashFailureMessage(failure))),
          ),
        );
        notifier.failureShown();
      })
      ..listen(trashNotifierProvider.select((s) => s.notice), (_, notice) {
        if (notice == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: const Key('trash-notice'),
            content: Text(keepAll(trashNoticeMessage(notice))),
          ),
        );
        notifier.noticeShown();
      });
    return TabPage(
      header: const SubPageTitle(
        '휴지통',
        description: '보고 있는 달의 휴지통이에요. 넣은 지 30일이 지나면 자동으로 지워져요.',
      ),
      children: [
        const MonthHeader(),
        const SizedBox(height: 12),
        switch (ledger) {
          AsyncData(:final value) => _TrashContent(items: value.trashed),
          AsyncError() => const SettingListMessage(
            '휴지통을 불러오지 못했어요. 잠시 후 다시 열어 주세요.',
          ),
          _ => const SettingListLoading(),
        },
      ],
    );
  }
}

class _TrashContent extends ConsumerWidget {
  const _TrashContent({required this.items});

  final List<TrashedEntry> items;

  // 완전히 지울지 묻고, 지운다고 하면 지운다.
  Future<void> _confirmPurge(
    BuildContext context,
    WidgetRef ref,
    TrashedEntry item,
    String title,
    YearMonth month,
  ) async {
    final notifier = ref.read(trashNotifierProvider.notifier);
    final purge = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _PurgeDialog(title: title, amount: item.entry.amount),
    );
    if (purge != true) return;
    await notifier.purge(item.entry, month);
  }

  // 모르는 자리 값(규칙이 owner·partner 말고는 막는다)은 관리자로 그린다.
  static MemberSlot _slotOf(String memberId) =>
      MemberSlot.values.asNameMap()[memberId] ?? MemberSlot.owner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final now = ref.watch(clockProvider)();
    final state = ref.watch(trashNotifierProvider);
    final canWrite = ref.watch(myRoleProvider)?.canWrite ?? false;
    final members = ref.watch(membersProvider).value ?? const [];
    final methods = {
      for (final method
          in ref.watch(paymentMethodsProvider).value ?? const <PaymentMethod>[])
        method.id: method,
    };
    final notifier = ref.read(trashNotifierProvider.notifier);
    // 최근에 넣은 것부터. 방금 넣어 서버 시간이 아직 없는 것이 맨 앞이다.
    final sorted = [...items]
      ..sort((a, b) {
        final (aAt, bAt) = (a.deletedAt, b.deletedAt);
        if (aAt == null || bAt == null) {
          return (aAt == null ? 0 : 1) - (bAt == null ? 0 : 1);
        }
        return bAt.compareTo(aAt);
      });
    // 반복 설정 목록을 받기 전(또는 오류)에는 고정 지출이 남아야 하는지 몰라서 그 줄의 단추를 막는다.
    final templateIds = switch (ref.watch(templatesProvider)) {
      AsyncData(:final value) => {for (final template in value) template.id},
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        if (!canWrite) const ViewOnlyNotice(),
        if (sorted.isEmpty)
          SettingListMessage('${month.month}월 휴지통이 비어 있어요.')
        else
          SettingCard(
            children: [
              for (final item in sorted)
                _TrashRow(
                  key: ValueKey(
                    'trash-${item.entry.kind.name}-${item.entry.id}',
                  ),
                  item: item,
                  title: _titleOf(item.entry, methods),
                  member: memberIn(members, _slotOf(item.entry.memberId)),
                  stays:
                      templateIds != null &&
                      staysInTrash(
                        item.entry,
                        month: month,
                        thisMonth: YearMonth.of(now),
                        templateIds: templateIds,
                      ),
                  now: now,
                  canWrite: canWrite,
                  busy:
                      state.busy ||
                      (templateIds == null && item.entry is PlannedExpense),
                  onRestore: () => notifier.restore(item.entry, month),
                  onPurge: () => _confirmPurge(
                    context,
                    ref,
                    item,
                    _titleOf(item.entry, methods),
                    month,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  static String _titleOf(
    LedgerEntry entry,
    Map<String, PaymentMethod> methods,
  ) => switch (entry) {
    Income(:final title) ||
    PlannedExpense(:final title) ||
    ExtraExpense(:final title) => title,
    CardBill(:final cardId) => methods[cardId]?.name ?? '카드 대금',
  };
}

/// 휴지통 항목 한 줄: 누구 몫인지, 제목·금액, 종류와 넣은 날, 자동 삭제 안내, 되살리기·완전 삭제 단추.
class _TrashRow extends StatelessWidget {
  const _TrashRow({
    required this.item,
    required this.title,
    required this.member,
    required this.stays,
    required this.now,
    required this.canWrite,
    required this.busy,
    required this.onRestore,
    required this.onPurge,
    super.key,
  });

  final TrashedEntry item;
  final String title;
  final Member member;

  /// 반복 설정이 남아 있는 이번 달 이후 고정 지출이라 지우지 않고 남겨 두는지.
  final bool stays;
  final DateTime now;
  final bool canWrite;
  final bool busy;
  final VoidCallback onRestore;
  final VoidCallback onPurge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final entry = item.entry;
    final amount = entry.amount;
    final deletedAt = item.deletedAt?.toLocal();
    final purgeAt = item.purgeAt;
    final meta = [
      entryKindLabel(entry.kind),
      deletedAt == null ? '방금 넣음' : '${deletedAt.month}/${deletedAt.day}에 넣음',
    ].join(' · ');
    final note = stays
        ? '고정 지출에서 만든 항목이라 지우면 다시 생겨요. 휴지통에 남겨 둬요.'
        : purgeAt == null
        ? null
        : trashPurgeLabel(purgeAt, now);
    final mutedStyle = theme.textTheme.labelSmall?.copyWith(
      color: colors.textMuted,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          MergeSemantics(
            child: Row(
              spacing: 12,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MemberAvatar(member: member, size: 36),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(meta, style: mutedStyle),
                      if (note != null)
                        Text(
                          keepAll(note),
                          key: const Key('trash-note'),
                          style: mutedStyle,
                        ),
                    ],
                  ),
                ),
                Text(
                  amount == null ? '금액 미정' : won(amount),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: amount == null
                        ? FontWeight.w500
                        : FontWeight.w700,
                    color: amount == null ? colors.textMuted : null,
                  ),
                ),
              ],
            ),
          ),
          if (canWrite)
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              children: [
                TextButton.icon(
                  key: Key('restore-${entry.id}'),
                  style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                  onPressed: busy ? null : onRestore,
                  icon: const Icon(Icons.restore, size: 20),
                  label: const Text('되살리기'),
                ),
                if (!stays)
                  TextButton.icon(
                    key: Key('purge-${entry.id}'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(64, 48),
                      foregroundColor: theme.colorScheme.error,
                    ),
                    onPressed: busy ? null : onPurge,
                    icon: const Icon(Icons.delete_forever_outlined, size: 20),
                    label: const Text('완전 삭제'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// 완전히 지울지 묻는 대화상자. 지운다고 하면 true를 돌려준다.
class _PurgeDialog extends StatelessWidget {
  const _PurgeDialog({required this.title, required this.amount});

  final String title;
  final int? amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = this.amount;
    return AlertDialog(
      title: const Text('완전히 지울까요?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            [title, amount == null ? '금액 미정' : won(amount)].join(' · '),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            keepAll('지우면 되살릴 수 없어요. 변경 기록에는 지운 사실이 남아요.'),
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('purge-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        TextButton(
          key: const Key('purge-confirm'),
          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('완전히 지우기'),
        ),
      ],
    );
  }
}
