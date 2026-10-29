import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../domain/model/category.dart';
import '../../domain/model/ledger_entries.dart';
import '../../domain/model/member.dart';
import '../../domain/model/month_ledger.dart';
import '../../domain/model/payment_method.dart';
import '../../core/widget/no_months_notice.dart';
import '../../core/widget/entry_kind_label.dart';
import '../../core/widget/keep_all.dart';
import '../../core/widget/month_header.dart';
import '../../core/widget/tab_page.dart';
import '../../domain/format/won.dart';
import 'entries_notifier.dart';
import 'entry_tabs.dart';
import 'entry_list.dart';
import 'entry_row.dart';

/// 항목 탭(design/app/04). 보고 있는 달의 항목을 세 칸(수입·지출·카드 대금)으로 나눠 보여준다.
///
/// 지출 칸은 고정 지출과 추가 지출을 구역으로 나눈다. 고정 지출은 분류마다 묶고 지급 전 항목에 표시를 붙인다.
/// 항목을 누르면 입력 화면에서 고친다(보기 전용은 못 고친다).
class EntriesScreen extends ConsumerWidget {
  const EntriesScreen({
    required this.openForm,
    required this.openCalendar,
    super.key,
  });

  final OpenEntryForm openForm;

  /// 달 이름을 누르면 여는 달력. 화면 이동은 router.dart가 정해서 넘겨준다.
  final void Function(BuildContext context) openCalendar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(selectedEntryTabProvider);
    ref.listen(entriesNotifierProvider.select((s) => s.failure), (_, failure) {
      if (failure == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(keepAll(entriesFailureMessage(failure)))),
      );
      ref.read(entriesNotifierProvider.notifier).failureShown();
    });
    return TabPage(
      header: MonthHeader(openCalendar: openCalendar),
      children: [
        EntryTabs(
          selected: tab,
          onSelect: ref.read(selectedEntryTabProvider.notifier).select,
        ),
        const SizedBox(height: 14),
        if (ref.watch(ledgerMonthsProvider)?.isEmpty ?? false)
          const NoMonthsNotice()
        else
          _EntriesBody(tab: tab, openForm: openForm),
      ],
    );
  }
}

/// 그달 항목·분류·결제수단을 다 받으면 목록을, 아니면 불러오는 중이나 실패를 그린다.
class _EntriesBody extends ConsumerWidget {
  const _EntriesBody({required this.tab, required this.openForm});

  final EntryTab tab;
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
        tab: tab,
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
    required this.tab,
    required this.ledger,
    required this.categories,
    required this.paymentMethods,
    required this.openForm,
  });

  final EntryTab tab;
  final MonthLedger ledger;
  final List<Category> categories;
  final List<PaymentMethod> paymentMethods;
  final OpenEntryForm openForm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final members = ref.watch(membersProvider).value ?? const [];
    final canWrite = ref.watch(myRoleProvider)?.canWrite ?? false;
    final lists = [
      for (final kind in tab.kinds)
        (kind, EntryList.of(kind, ledger, categories: categories)),
    ];
    if (lists.every((section) => section.$2.isEmpty)) {
      return _EmptyEntries(
        tab: tab,
        canWrite: canWrite,
        hasCards: paymentMethods.any(
          (m) => m.kind == PaymentKind.card && !m.hidden,
        ),
      );
    }
    final methods = {for (final method in paymentMethods) method.id: method};
    // 종류가 둘인 칸(지출)은 종류마다 제목·건수·합계를 단 구역으로 나누고, 맨 위에는 칸 전체의 건수와 합계를 둔다.
    final sectioned = lists.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        _ListSummary(
          count: lists.fold(0, (sum, section) => sum + section.$2.count),
          total: lists.fold(0, (sum, section) => sum + section.$2.total),
          unpaidCount: sectioned ? 0 : lists.single.$2.unpaidCount,
        ),
        for (final (kind, list) in lists)
          if (!list.isEmpty) ...[
            if (sectioned)
              _SectionHeader(
                key: ValueKey('section-${kind.name}'),
                kind: kind,
                list: list,
              ),
            for (final group in list.groups)
              _GroupCard(
                key: ValueKey('group-${kind.name}-${group.key}'),
                group: group,
                children: [
                  for (final entry in group.entries)
                    EntryRow(
                      key: ValueKey('entry-${entry.id}'),
                      entry: entry,
                      member: memberIn(
                        members,
                        entryMemberSlot(entry.memberId),
                      ),
                      methods: methods,
                      onTap: canWrite
                          ? () => editEntryWithUndo(
                              context,
                              openForm,
                              entry,
                              month,
                            )
                          : null,
                    ),
                ],
              ),
          ],
      ],
    );
  }
}

/// 칸 전체의 건수, 지급 전 건수, 합계 한 줄. 구역으로 나눈 칸은 지급 전 건수를 구역 제목에 단다.
class _ListSummary extends StatelessWidget {
  const _ListSummary({
    required this.count,
    required this.total,
    required this.unpaidCount,
  });

  final int count;
  final int total;
  final int unpaidCount;

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
                '$count건',
                key: const Key('entries-count'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (unpaidCount > 0)
                StatusPill(
                  '지급 전 $unpaidCount건',
                  key: const Key('entries-unpaid'),
                ),
            ],
          ),
          Text(
            won(total),
            key: const Key('entries-total'),
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 18),
          ),
        ],
      ),
    );
  }
}

/// 지출 칸의 구역 제목(고정 지출·추가 지출). 종류 이름, 건수, 지급 전 건수, 합계를 단다.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.kind, required this.list, super.key});

  final EntryKind kind;
  final EntryList list;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
      child: Row(
        spacing: 8,
        children: [
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    entryKindLabel(kind),
                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 17),
                  ),
                ),
                Text(
                  '${list.count}건',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (list.unpaidCount > 0)
                  StatusPill(
                    '지급 전 ${list.unpaidCount}건',
                    key: const Key('entries-unpaid'),
                  ),
              ],
            ),
          ),
          Text(
            won(list.total),
            key: Key('section-total-${kind.name}'),
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
          ),
        ],
      ),
    );
  }
}

/// 한 묶음의 카드. 제목이 있으면(고정 지출의 분류) 위에 이름·저축 표시·소계를 둔다.
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
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

/// 그 칸의 항목이 없는 달의 안내.
class _EmptyEntries extends StatelessWidget {
  const _EmptyEntries({
    required this.tab,
    required this.canWrite,
    required this.hasCards,
  });

  final EntryTab tab;
  final bool canWrite;
  final bool hasCards;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hint = !canWrite
        ? null
        : tab == EntryTab.cardBill && !hasCards
        ? '카드 대금은 설정에서 카드를 추가한 뒤 적을 수 있어요.'
        : '+ 버튼으로 적을 수 있어요.';
    return Card(
      key: const Key('entries-empty'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Column(
          spacing: 6,
          children: [
            Text(
              keepAll('이 달에 적은 ${entryTabLabel(tab)}이 없어요.'),
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
