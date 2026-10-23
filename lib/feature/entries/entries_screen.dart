import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/model/category.dart';
import '../../core/model/ledger_entries.dart';
import '../../core/model/member.dart';
import '../../core/model/month_ledger.dart';
import '../../core/model/payment_method.dart';
import '../../core/model/year_month.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widget/entry_kind_label.dart';
import '../../core/widget/keep_all.dart';
import '../../core/widget/member_avatar.dart';
import '../../core/widget/month_header.dart';
import '../../core/widget/tab_page.dart';
import '../../core/widget/won.dart';
import 'entries_controller.dart';
import 'entry_form_controller.dart';
import 'entry_kind_tabs.dart';
import 'entry_list.dart';

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

/// 항목 탭(design/app/04). 보고 있는 달의 항목을 네 종류로 나눠 보여준다.
///
/// 기본 월 지출은 분류마다 묶고 지급 전 항목에 표시를 붙인다. 항목을 누르면 입력 화면에서 고친다(보기 전용은 못 고친다).
class EntriesScreen extends ConsumerWidget {
  const EntriesScreen({required this.openForm, super.key});

  final OpenEntryForm openForm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(selectedEntryKindProvider);
    ref.listen(entriesControllerProvider.select((s) => s.failure), (
      _,
      failure,
    ) {
      if (failure == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(keepAll(entriesFailureMessage(failure)))),
      );
      ref.read(entriesControllerProvider.notifier).failureShown();
    });
    return TabPage(
      header: const MonthHeader(),
      children: [
        EntryKindTabs(
          selected: kind,
          onSelect: ref.read(selectedEntryKindProvider.notifier).select,
        ),
        const SizedBox(height: 14),
        _EntriesBody(kind: kind, openForm: openForm),
      ],
    );
  }
}

/// 그달 항목·분류·결제수단을 다 받으면 목록을, 아니면 불러오는 중이나 실패를 그린다.
class _EntriesBody extends ConsumerWidget {
  const _EntriesBody({required this.kind, required this.openForm});

  final EntryKind kind;
  final OpenEntryForm openForm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(monthLedgerProvider);
    final categories = ref.watch(categoriesProvider);
    final paymentMethods = ref.watch(paymentMethodsProvider);
    final values = <AsyncValue<Object>>[ledger, categories, paymentMethods];
    if (values.any((value) => value.hasError)) return const _EntriesFailed();
    if ((ledger, categories, paymentMethods) case (
      AsyncData(value: final ledger),
      AsyncData(value: final categories),
      AsyncData(value: final paymentMethods),
    )) {
      return _EntriesContent(
        kind: kind,
        ledger: ledger,
        categories: categories,
        paymentMethods: paymentMethods,
        openForm: openForm,
      );
    }
    return const _EntriesLoading();
  }
}

class _EntriesContent extends ConsumerWidget {
  const _EntriesContent({
    required this.kind,
    required this.ledger,
    required this.categories,
    required this.paymentMethods,
    required this.openForm,
  });

  final EntryKind kind;
  final MonthLedger ledger;
  final List<Category> categories;
  final List<PaymentMethod> paymentMethods;
  final OpenEntryForm openForm;

  // 고치기 화면을 열고, 휴지통에 넣고 돌아오면 '되돌리기'를 띄운다.
  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    LedgerEntry entry,
    YearMonth month,
  ) async {
    // await 뒤에는 context가 사라졌을 수 있어서 미리 잡아 둔다.
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(entriesControllerProvider.notifier);
    final outcome = await openForm(
      context,
      EntryFormArgs.edit(entry: entry, month: month),
    );
    if (outcome != EntryFormOutcome.trashed) return;
    messenger.showSnackBar(
      SnackBar(
        key: const Key('trashed-snack-bar'),
        content: Text(keepAll('휴지통에 넣었어요.')),
        // 동작이 있는 스낵바는 기본으로 계속 떠 있다. 되돌리기는 잠깐만 보여준다.
        persist: false,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          key: const Key('restore-entry'),
          label: '되돌리기',
          onPressed: () => controller.restore(entry, month),
        ),
      ),
    );
  }

  // 모르는 자리 값(규칙이 owner·partner 말고는 막는다)은 관리자로 그린다.
  static MemberSlot _slotOf(String memberId) =>
      MemberSlot.values.asNameMap()[memberId] ?? MemberSlot.owner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final members = ref.watch(membersProvider).value ?? const [];
    final canWrite = ref.watch(myRoleProvider)?.canWrite ?? false;
    final list = EntryList.of(kind, ledger, categories: categories);
    if (list.isEmpty) {
      return _EmptyEntries(
        kind: kind,
        canWrite: canWrite,
        hasCards: paymentMethods.any(
          (m) => m.kind == PaymentKind.card && !m.hidden,
        ),
      );
    }
    final methods = {for (final method in paymentMethods) method.id: method};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        _ListSummary(list: list),
        for (final group in list.groups)
          _GroupCard(
            key: ValueKey('group-${group.key}'),
            group: group,
            children: [
              for (final entry in group.entries)
                _EntryRow(
                  key: ValueKey('entry-${entry.id}'),
                  entry: entry,
                  member: memberIn(members, _slotOf(entry.memberId)),
                  methods: methods,
                  onTap: canWrite
                      ? () => _edit(context, ref, entry, month)
                      : null,
                ),
            ],
          ),
      ],
    );
  }
}

/// 건수, 지급 전 건수, 합계 한 줄.
class _ListSummary extends StatelessWidget {
  const _ListSummary({required this.list});

  final EntryList list;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Text(
                '${list.count}건',
                key: const Key('entries-count'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (list.unpaidCount > 0)
                _StatusPill(
                  '지급 전 ${list.unpaidCount}건',
                  key: const Key('entries-unpaid'),
                ),
            ],
          ),
          Text(
            won(list.total),
            key: const Key('entries-total'),
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 18),
          ),
        ],
      ),
    );
  }
}

/// 한 묶음의 카드. 제목이 있으면(기본 월 지출의 분류) 위에 이름·저축 표시·소계를 둔다.
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.children, super.key});

  final EntryGroup group;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = group.title;
    final headerStyle = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 14,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: theme.colorScheme.outlineVariant,
    );
    return Card(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, title == null ? 4 : 14, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: Row(
                        spacing: 6,
                        children: [
                          Flexible(
                            child: Semantics(
                              header: true,
                              child: Text(
                                title,
                                overflow: TextOverflow.ellipsis,
                                style: headerStyle?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          if (group.countsAsSaving) const _SavingPill(),
                        ],
                      ),
                    ),
                    Text(
                      won(group.total),
                      style: headerStyle?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            for (final (index, child) in children.indexed) ...[
              if (index > 0) divider,
              child,
            ],
          ],
        ),
      ),
    );
  }
}

/// 항목 한 줄: 누구 몫인지, 제목과 결제수단·날짜, 금액과 지급 전 표시.
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.member,
    required this.methods,
    required this.onTap,
    super.key,
  });

  final LedgerEntry entry;
  final Member member;
  final Map<String, PaymentMethod> methods;

  /// null이면 누를 수 없다(보기 전용).
  final VoidCallback? onTap;

  String _methodName(String id) => methods[id]?.name ?? '결제수단 없음';

  String get _title => switch (entry) {
    Income(:final title) ||
    PlannedExpense(:final title) ||
    ExtraExpense(:final title) => title,
    CardBill(:final cardId) => methods[cardId]?.name ?? '카드 없음',
  };

  // 제목 아래 한 줄: 결제수단, 날짜(지급 전이면 고정 지출의 예정일), 메모.
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
    return [...parts, ?entry.memo].join(' · ');
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
                if (unpaid) const _StatusPill('지급 전'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 포인트 색 바탕의 작은 표시('지급 전'). 글자로 뜻을 전하므로 색만으로 구분하지 않는다.
class _StatusPill extends StatelessWidget {
  const _StatusPill(this.label, {super.key});

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

class _SavingPill extends StatelessWidget {
  const _SavingPill();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '저축',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: scheme.primary,
        ),
      ),
    );
  }
}

/// 그 종류의 항목이 없는 달의 안내.
class _EmptyEntries extends StatelessWidget {
  const _EmptyEntries({
    required this.kind,
    required this.canWrite,
    required this.hasCards,
  });

  final EntryKind kind;
  final bool canWrite;
  final bool hasCards;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hint = !canWrite
        ? null
        : kind == EntryKind.cardBill && !hasCards
        ? '카드대금은 설정에서 카드를 추가한 뒤 적을 수 있어요.'
        : '+ 버튼으로 적을 수 있어요.';
    return Card(
      key: const Key('entries-empty'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Column(
          spacing: 6,
          children: [
            Text(
              keepAll('이 달에 적은 ${entryKindLabel(kind)}이 없어요.'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (hint != null)
              Text(
                keepAll(hint),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _EntriesLoading extends StatelessWidget {
  const _EntriesLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: Key('entries-loading'),
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _EntriesFailed extends StatelessWidget {
  const _EntriesFailed();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('entries-failed'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Text(
          keepAll('이 달 항목을 불러오지 못했어요. 잠시 후 다시 열어 주세요.'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ),
    );
  }
}
