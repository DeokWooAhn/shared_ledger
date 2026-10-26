import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/model/category.dart';
import '../../core/model/ledger_entries.dart';
import '../../core/model/member.dart';
import '../../core/model/month_ledger.dart';
import '../../core/model/payment_method.dart';
import '../../core/widget/entry_kind_label.dart';
import '../../core/widget/keep_all.dart';
import '../../core/widget/month_header.dart';
import '../../core/widget/tab_page.dart';
import '../../core/widget/won.dart';
import 'entries_controller.dart';
import 'entry_kind_tabs.dart';
import 'entry_list.dart';
import 'entry_row.dart';

/// 항목 탭(design/app/04). 보고 있는 달의 항목을 네 종류로 나눠 보여준다.
///
/// 기본 월 지출은 분류마다 묶고 지급 전 항목에 표시를 붙인다. 항목을 누르면 입력 화면에서 고친다(보기 전용은 못 고친다).
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
      header: MonthHeader(openCalendar: openCalendar),
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
                EntryRow(
                  key: ValueKey('entry-${entry.id}'),
                  entry: entry,
                  member: memberIn(members, entryMemberSlot(entry.memberId)),
                  methods: methods,
                  onTap: canWrite
                      ? () => editEntryWithUndo(
                          context,
                          ref,
                          openForm,
                          entry,
                          month,
                        )
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
                StatusPill(
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
