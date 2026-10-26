import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/model/ledger_entries.dart';
import '../../core/model/member.dart';
import '../../core/model/payment_method.dart';
import '../../core/model/year_month.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widget/entry_kind_label.dart';
import '../../core/widget/keep_all.dart';
import '../../core/widget/member_avatar.dart';
import '../../core/widget/won.dart';
import 'entries_controller.dart';
import 'entry_form_controller.dart';

// 항목 탭과 달력이 같이 쓰는 항목 한 줄, 표시, 고치기 흐름.

/// 입력 화면을 열고, 닫힐 때의 결과를 돌려준다. 화면 이동은 router.dart가 정해서 넘겨준다.
typedef OpenEntryForm =
    Future<EntryFormOutcome?> Function(
      BuildContext context,
      EntryFormArgs args,
    );

/// 목록에 보이는 짧은 날짜. 예: '10/25'
String entryShortDate(DateTime date) => '${date.month}/${date.day}';

/// 지급 전 기본 월 지출의 예정일. 그달 마지막 날이면 '말일', 아니면 짧은 날짜다. 예: '말일', '10/25'
String entryDueDate(DateTime dueOn) =>
    DateTime(dueOn.year, dueOn.month, dueOn.day + 1).month != dueOn.month
    ? '말일'
    : entryShortDate(dueOn);

String entriesFailureMessage(EntriesFailure failure) => switch (failure) {
  EntriesFailure.restoreOffline => '연결되지 않아 꺼내지 못했어요. 항목은 휴지통에 남아 있어요.',
  EntriesFailure.restoreGone => '그사이 휴지통에서 꺼냈거나 지운 항목이에요.',
  EntriesFailure.restore => '꺼내지 못했어요. 잠시 후 다시 시도해 주세요.',
};

/// 항목의 자리. 모르는 자리 값(규칙이 owner·partner 말고는 막는다)은 관리자로 그린다.
MemberSlot entryMemberSlot(String memberId) =>
    MemberSlot.values.asNameMap()[memberId] ?? MemberSlot.owner;

/// 고치기 화면을 열고, 휴지통에 넣고 돌아오면 '되돌리기'를 띄운다.
///
/// 되돌리기 실패는 [entriesControllerProvider]의 실패로 오니, 부르는 화면이 그 실패를 듣고 알린다.
/// 되돌리기는 부른 화면이 닫힌 뒤에도(요약 탭에서 연 달력을 닫음) 누를 수 있어서, 스낵바가 떠 있는 동안
/// autoDispose 컨트롤러를 살려 두고 누를 때 꺼낸다.
Future<void> editEntryWithUndo(
  BuildContext context,
  OpenEntryForm openForm,
  LedgerEntry entry,
  YearMonth month,
) async {
  // await 뒤에는 context가 사라졌을 수 있어서 미리 잡아 둔다.
  final messenger = ScaffoldMessenger.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  final outcome = await openForm(
    context,
    EntryFormArgs.edit(entry: entry, month: month),
  );
  if (outcome != EntryFormOutcome.trashed) return;
  final keepController = container.listen(entriesControllerProvider, (_, _) {});
  final snackBar = messenger.showSnackBar(
    SnackBar(
      key: const Key('trashed-snack-bar'),
      content: Text(keepAll('휴지통에 넣었어요.')),
      // 동작이 있는 스낵바는 기본으로 계속 떠 있다. 되돌리기는 잠깐만 보여준다.
      persist: false,
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        key: const Key('restore-entry'),
        label: '되돌리기',
        onPressed: () => container
            .read(entriesControllerProvider.notifier)
            .restore(entry, month),
      ),
    ),
  );
  unawaited(snackBar.closed.whenComplete(keepController.close));
}

/// 항목 한 줄: 누구 몫인지, 제목과 결제수단·날짜, 금액과 지급 전 표시.
///
/// [showKind]면 제목 아래 줄 앞에 종류를 붙인다(종류가 섞인 달력의 날 목록).
class EntryRow extends StatelessWidget {
  const EntryRow({
    required this.entry,
    required this.member,
    required this.methods,
    required this.onTap,
    this.showKind = false,
    super.key,
  });

  final LedgerEntry entry;
  final Member member;
  final Map<String, PaymentMethod> methods;

  /// null이면 누를 수 없다(보기 전용).
  final VoidCallback? onTap;
  final bool showKind;

  String _methodName(String id) => methods[id]?.name ?? '결제수단 없음';

  String get _title => switch (entry) {
    Income(:final title) ||
    PlannedExpense(:final title) ||
    ExtraExpense(:final title) => title,
    CardBill(:final cardId) => methods[cardId]?.name ?? '카드 없음',
  };

  // 제목 아래 한 줄: (종류,) 결제수단, 날짜(지급 전이면 고정 지출의 예정일), 메모.
  String get _meta {
    final entry = this.entry;
    final date = entry.date;
    final day = date == null ? null : entryShortDate(date);
    final parts = switch (entry) {
      Income() => [if (day != null) '$day 입금'],
      PlannedExpense(:final paymentMethodId, :final dueOn) => [
        _methodName(paymentMethodId),
        if (day != null)
          methods[paymentMethodId]?.kind == PaymentKind.card
              ? '$day 결제'
              : '$day 지급'
        else if (dueOn != null)
          '${entryDueDate(dueOn)} 예정',
      ],
      ExtraExpense(:final paymentMethodId) => [
        _methodName(paymentMethodId),
        ?day,
      ],
      CardBill() => [if (day != null) '$day 출금'],
    };
    return [
      if (showKind) entryKindLabel(entry.kind),
      ...parts,
      ?entry.memo,
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final amount = entry.amount;
    final meta = _meta;
    final unpaid = switch (entry) {
      PlannedExpense(:final isPaid) => !isPaid,
      _ => false,
    };
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          spacing: 12,
          children: [
            MemberAvatar(member: member, size: 36),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    _title,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (meta.isNotEmpty)
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: 4,
              children: [
                if (amount == null)
                  Text(
                    '금액 미정',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colors.textMuted,
                    ),
                  )
                else
                  Text(
                    won(amount),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (unpaid) const StatusPill('지급 전'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 포인트 색 바탕의 작은 표시('지급 전'). 글자로 뜻을 전하므로 색만으로 구분하지 않는다.
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.tertiary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: scheme.onTertiary,
        ),
      ),
    );
  }
}
