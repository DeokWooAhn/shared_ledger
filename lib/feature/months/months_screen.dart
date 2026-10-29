import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/widget/keep_all.dart';
import '../../core/widget/month_picker_sheet.dart';
import '../../core/widget/tab_page.dart';
import '../../domain/model/year_month.dart';
import 'months_notifier.dart';

String monthsFailureMessage(MonthsFailure failure) => switch (failure) {
  MonthsFailure.addOffline => '연결되지 않아 가계부를 추가하지 못했어요. 연결된 뒤에 다시 해 주세요.',
  MonthsFailure.add => '가계부를 추가하지 못했어요. 잠시 후 다시 시도해 주세요.',
};

/// 가계부 탭(design/app/06). 추가한 달의 가계부만 해(年)별로 최근 달부터 보여준다.
///
/// 이번 달이라도 추가하지 않았으면 없다. 달을 누르면 그달로 바꾸고 요약 탭으로 간다([openSummary]).
/// 관리자·편집자는 '가계부 추가'로 연·월 휠에서 달을 골라 더한다. 이미 있는 달을 고르면 그달로 간다.
/// 줄마다 합계는 보이지 않는다(달마다 항목을 읽어야 해서).
class MonthsScreen extends ConsumerWidget {
  const MonthsScreen({required this.openSummary, super.key});

  /// 요약 탭으로 옮긴다. 화면 이동은 router.dart가 정해서 넘겨준다.
  final void Function(BuildContext context) openSummary;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final months = ref.read(ledgerMonthsProvider) ?? const [];
    final thisMonth = YearMonth.of(ref.read(clockProvider)());
    final picked = await showMonthPicker(
      context,
      // 이번 달이 없으면 이번 달, 있으면 마지막 달의 다음 달을 먼저 보여준다.
      selected: months.contains(thisMonth) ? months.last.next : thisMonth,
      current: thisMonth,
    );
    if (picked == null || !context.mounted) return;
    final added =
        months.contains(picked) ||
        await ref.read(monthsNotifierProvider.notifier).add(picked);
    if (!added || !context.mounted) return;
    ref.read(selectedMonthProvider.notifier).select(picked);
    openSummary(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(monthsNotifierProvider.select((s) => s.failure), (_, failure) {
      if (failure == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(keepAll(monthsFailureMessage(failure)))),
      );
      ref.read(monthsNotifierProvider.notifier).failureShown();
    });
    final months = ref.watch(ledgerMonthsProvider);
    final selected = ref.watch(selectedMonthProvider);
    final thisMonth = YearMonth.of(ref.watch(clockProvider)());
    final canWrite = ref.watch(myRoleProvider)?.canWrite ?? false;
    final adding = ref.watch(monthsNotifierProvider.select((s) => s.adding));
    final years = <int, List<YearMonth>>{};
    for (final month in (months ?? const <YearMonth>[]).reversed) {
      years.putIfAbsent(month.year, () => []).add(month);
    }
    return TabPage(
      header: const TabTitle(
        '가계부',
        description: '추가한 달만 보여요. 달을 누르면 그달 요약으로 가요.',
      ),
      children: [
        const SizedBox(height: 14),
        if (months == null)
          const Padding(
            key: Key('months-loading'),
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (months.isEmpty)
          const _NoMonths()
        else
          for (final MapEntry(key: year, value: inYear) in years.entries) ...[
            _YearCard(
              key: ValueKey('year-$year'),
              year: year,
              months: inYear,
              selected: selected,
              thisMonth: thisMonth,
              onOpen: (month) {
                ref.read(selectedMonthProvider.notifier).select(month);
                openSummary(context);
              },
            ),
            const SizedBox(height: 14),
          ],
        if (canWrite && months != null)
          FilledButton.tonal(
            key: const Key('add-month'),
            onPressed: adding ? null : () => _add(context, ref),
            child: const Text('가계부 추가'),
          ),
      ],
    );
  }
}

/// 한 해의 달 카드. 최근 달부터 줄마다 달 이름을 두고, 이번 달 표시와 보고 있는 달 체크를 단다.
class _YearCard extends StatelessWidget {
  const _YearCard({
    required this.year,
    required this.months,
    required this.selected,
    required this.thisMonth,
    required this.onOpen,
    super.key,
  });

  final int year;
  final List<YearMonth> months;
  final YearMonth selected;
  final YearMonth thisMonth;
  final ValueChanged<YearMonth> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                '$year년',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final (index, month) in months.indexed) ...[
              if (index > 0)
                Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
              _MonthRow(
                key: ValueKey('month-${month.id}'),
                month: month,
                isThisMonth: month == thisMonth,
                viewing: month == selected,
                onTap: () => onOpen(month),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 달 한 줄. 보고 있는 달은 강조하고 체크를, 다른 달은 화살표를 단다.
class _MonthRow extends StatelessWidget {
  const _MonthRow({
    required this.month,
    required this.isThisMonth,
    required this.viewing,
    required this.onTap,
    super.key,
  });

  final YearMonth month;
  final bool isThisMonth;
  final bool viewing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: viewing,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Row(
            spacing: 8,
            children: [
              Text(
                '${month.month}월',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: viewing ? FontWeight.w700 : FontWeight.w600,
                  color: viewing ? scheme.primary : null,
                ),
              ),
              if (isThisMonth) const _ThisMonthPill(),
              const Spacer(),
              ExcludeSemantics(
                child: Icon(
                  viewing ? Icons.check : Icons.chevron_right,
                  color: viewing ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThisMonthPill extends StatelessWidget {
  const _ThisMonthPill();

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
        '이번 달',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

/// 추가한 달이 하나도 없을 때. 가계부 추가로 시작하게 알린다.
class _NoMonths extends StatelessWidget {
  const _NoMonths();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('months-empty'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Column(
          spacing: 6,
          children: [
            Text(
              keepAll('아직 추가한 가계부가 없어요.'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            Text(
              keepAll('가계부 추가로 쓸 달을 골라 주세요.'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
