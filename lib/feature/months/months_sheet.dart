import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/widget/keep_all.dart';
import '../../core/widget/month_picker_sheet.dart';
import '../../domain/model/year_month.dart';
import 'months_notifier.dart';

String monthsFailureMessage(MonthsFailure failure) => switch (failure) {
  MonthsFailure.addOffline => '연결되지 않아 달을 추가하지 못했어요. 연결된 뒤에 다시 해 주세요.',
  MonthsFailure.add => '달을 추가하지 못했어요. 잠시 후 다시 시도해 주세요.',
};

/// 달 고르기 시트의 최대 폭. 넓은 화면에서는 이 폭으로 가운데 둔다.
const monthsSheetMaxWidth = 560.0;

/// 달 고르기 시트를 연다. 머리말의 달 이름을 누르면 열리고, 탭 막대까지 덮게 앱 맨 위에 띄운다.
Future<void> showMonthsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: monthsSheetMaxWidth),
      builder: (_) => const MonthsSheet(),
    );

/// 달 고르기(예전 가계부 탭, design/app/06). 추가한 달만 해(年)별로 최근 달부터 보여준다.
///
/// 이번 달이라도 추가하지 않았으면 없다. 달을 누르면 그달로 바꾸고 닫는다. 보던 탭은 그대로다.
/// 관리자·편집자는 '달 추가'로 연·월 휠에서 달을 골라 더한다. 이미 있는 달을 고르면 그달로 간다.
/// 실패는 시트 안에 보여준다(스낵바는 시트 뒤에 가린다). 줄마다 합계는 보이지 않는다(달마다 항목을 읽어야 해서).
class MonthsSheet extends ConsumerWidget {
  const MonthsSheet({super.key});

  // 그달로 바꾸고 시트를 닫는다.
  void _open(BuildContext context, WidgetRef ref, YearMonth month) {
    ref.read(selectedMonthProvider.notifier).select(month);
    Navigator.of(context).pop();
  }

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
    _open(context, ref, picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final months = ref.watch(ledgerMonthsProvider);
    final selected = ref.watch(selectedMonthProvider);
    final thisMonth = YearMonth.of(ref.watch(clockProvider)());
    final canWrite = ref.watch(myRoleProvider)?.canWrite ?? false;
    final state = ref.watch(monthsNotifierProvider);
    final failure = state.failure;
    final years = <int, List<YearMonth>>{};
    for (final month in (months ?? const <YearMonth>[]).reversed) {
      years.putIfAbsent(month.year, () => []).add(month);
    }
    return SafeArea(
      child: ConstrainedBox(
        // 달이 많아도 화면 위쪽은 남겨 두고, 그 안에서 스크롤한다.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: ListView(
          key: const Key('months-sheet'),
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Semantics(
              header: true,
              child: Text('달 고르기', style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: 4),
            Text(
              keepAll('추가한 달만 보여요. 골라도 보던 화면에 그대로 있어요.'),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (months == null)
              const Padding(
                key: Key('months-loading'),
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (months.isEmpty)
              const _NoMonths()
            else
              for (final MapEntry(key: year, value: inYear) in years.entries)
                _YearGroup(
                  key: ValueKey('year-$year'),
                  year: year,
                  months: inYear,
                  selected: selected,
                  thisMonth: thisMonth,
                  onOpen: (month) => _open(context, ref, month),
                ),
            if (canWrite && months != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                key: const Key('add-month'),
                onPressed: state.adding ? null : () => _add(context, ref),
                child: const Text('달 추가'),
              ),
              if (failure != null) ...[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    keepAll(monthsFailureMessage(failure)),
                    key: const Key('months-failure'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// 한 해의 달들. 연도 아래로 최근 달부터 줄마다 달 이름을 두고, 이번 달 표시와 보고 있는 달 체크를 단다.
class _YearGroup extends StatelessWidget {
  const _YearGroup({
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
    return Padding(
      padding: const EdgeInsets.only(top: 12),
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
    );
  }
}

/// 달 한 줄. 보고 있는 달은 강조하고 체크를 단다.
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
              if (viewing)
                ExcludeSemantics(
                  child: Icon(Icons.check, color: scheme.primary),
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

/// 추가한 달이 하나도 없을 때. 달 추가로 시작하게 알린다.
class _NoMonths extends StatelessWidget {
  const _NoMonths();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: const Key('months-empty'),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        keepAll('아직 추가한 달이 없어요.'),
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium,
      ),
    );
  }
}
