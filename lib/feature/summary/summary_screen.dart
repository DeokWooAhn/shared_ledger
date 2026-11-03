import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/budget/budget_summary.dart';
import '../../domain/budget/month_summary.dart';
import '../../core/providers/providers.dart';
import '../../domain/model/year_month.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widget/no_months_notice.dart';
import '../../core/widget/keep_all.dart';
import '../../core/widget/month_header.dart';
import '../../core/widget/summary_parts.dart';
import '../../core/widget/tab_page.dart';
import '../../domain/format/won.dart';

/// 홈 탭(월 요약). 보고 있는 달의 남는 현금, 이번 달 지출·저축, 할 일(받기 전·지급 전), 카드를 보여준다.
/// 고정 지출의 분류별·구성원별 소계는 통계 탭에 있다.
///
/// 카드를 누르면 내역 탭의 그에 맞는 칸으로 간다. 현금 카드는 수입 칸, 이번 달 지출·저축·카드 이번 달 사용분은
/// 지출 칸, 카드 저번 달 사용분은 카드 대금 칸이다.
///
/// 저장소를 부르는 동작이 없어 Notifier 없이 [monthSummaryProvider]만 읽는다.
class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({
    required this.openMonths,
    required this.openEntries,
    super.key,
  });

  /// 머리말의 달 이름을 누르면 여는 달 고르기. 화면 이동은 router.dart가 정해서 넘겨준다.
  final void Function(BuildContext context) openMonths;

  /// 카드를 누르면 가는 내역 탭. 어느 칸을 볼지는 이 화면이 먼저 고른다.
  final void Function(BuildContext context) openEntries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(monthSummaryProvider);
    final noMonths = ref.watch(ledgerMonthsProvider)?.isEmpty ?? false;
    return LayoutBuilder(
      builder: (context, constraints) {
        final bodyWidth = constraints.maxWidth - tabPageSidePadding * 2;
        final twoColumns = bodyWidth >= summaryTwoColumnMinWidth;
        return TabPage(
          header: MonthHeader(openMonths: openMonths),
          maxWidth: twoColumns ? summaryTwoColumnMaxWidth : tabPageMaxWidth,
          children: [
            if (noMonths)
              const NoMonthsNotice()
            else
              switch (summary) {
                AsyncData(:final value) => _SummaryBody(
                  summary: value,
                  twoColumns: twoColumns,
                  openEntries: openEntries,
                ),
                AsyncError() => const _SummaryFailed(),
                AsyncLoading() => const _SummaryLoading(),
              },
          ],
        );
      },
    );
  }
}

class _SummaryBody extends ConsumerWidget {
  const _SummaryBody({
    required this.summary,
    required this.twoColumns,
    required this.openEntries,
  });

  final MonthSummary summary;
  final bool twoColumns;
  final void Function(BuildContext context) openEntries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final totals = summary.totals;
    // 내역 탭의 [tab] 칸으로 간다.
    void entries(EntryTab tab) {
      ref.read(selectedEntryTabProvider.notifier).select(tab);
      openEntries(context);
    }

    final cash = _CashCard(
      totals: totals,
      unreceivedIncomes: summary.unreceivedFixedIncomeCount,
      onTap: () => entries(EntryTab.income),
    );
    final empty = summary.isEmpty ? const _EmptyMonthNotice() : null;
    final metrics = _MetricTiles(
      totals: totals,
      onSpending: () => entries(EntryTab.expense),
      onSaving: () => entries(EntryTab.expense),
    );
    final unreceived = summary.unreceivedFixedIncomeCount;
    final unpaid = summary.unpaidPlannedCount;
    final pending = unreceived + unpaid == 0
        ? null
        : _PendingRow(
            unreceivedIncomes: unreceived,
            unpaidPlanned: unpaid,
            // 지급 전 고정 지출이 있으면 지출 칸, 받기 전 고정 수입만 있으면 수입 칸을 연다.
            onTap: () =>
                entries(unpaid > 0 ? EntryTab.expense : EntryTab.income),
          );
    final cards = summary.showsCards
        ? _CardSection(
            summary: summary,
            month: month,
            onUsage: () => entries(EntryTab.expense),
            onBills: () => entries(EntryTab.cardBill),
          )
        : null;
    if (twoColumns && (pending != null || cards != null)) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [cash, ?empty, metrics],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [?pending, ?cards],
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [cash, ?empty, metrics, ?pending, ?cards],
    );
  }
}

/// 할 일 한 줄: 받기 전 고정 수입과 지급 전 고정 지출 건수. 누르면 내역 탭의 그 칸으로 간다.
class _PendingRow extends StatelessWidget {
  const _PendingRow({
    required this.unreceivedIncomes,
    required this.unpaidPlanned,
    required this.onTap,
  });

  final int unreceivedIncomes;
  final int unpaidPlanned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = context.appColors.accentText;
    final label = [
      if (unreceivedIncomes > 0) '받기 전 수입 $unreceivedIncomes건',
      if (unpaidPlanned > 0) '지급 전 고정 지출 $unpaidPlanned건',
    ].join(' · ');
    return Material(
      color: theme.colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: const Key('pending-row'),
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              spacing: 8,
              children: [
                Expanded(
                  child: Text(
                    keepAll(label),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 남는 현금과 현금 유입·유출. 라이트·다크 모두 진한 코발트 카드다.
/// 받기 전 고정 수입이 있으면 현금 유입에서 빠져 있다고 아래에 알린다.
/// 카드 전체가 누름 자리 하나다.
class _CashCard extends StatelessWidget {
  const _CashCard({
    required this.totals,
    required this.unreceivedIncomes,
    required this.onTap,
  });

  final BudgetSummary totals;
  final int unreceivedIncomes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    return HeroCard(
      tapKey: const Key('home-cash'),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            spacing: 2,
            children: [
              Text(
                '남는 현금',
                style: text.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colors.heroSub,
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: colors.heroSub),
            ],
          ),
          const SizedBox(height: 4),
          AmountText(
            totals.remainingCash,
            textKey: const Key('remaining-cash'),
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: colors.accentOnDark,
            ),
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: colors.onHero.withValues(alpha: 0.15)),
          const SizedBox(height: 16),
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: _CashFlow(
                  icon: Icons.south_west,
                  label: '현금 유입',
                  amount: totals.cashIn,
                  amountKey: const Key('cash-in'),
                ),
              ),
              Expanded(
                child: _CashFlow(
                  icon: Icons.north_east,
                  label: '현금 유출',
                  amount: totals.cashOut,
                  amountKey: const Key('cash-out'),
                ),
              ),
            ],
          ),
          if (unreceivedIncomes > 0) ...[
            const SizedBox(height: 12),
            Text(
              keepAll('받기 전 고정 수입 $unreceivedIncomes건은 현금 유입에서 빠져 있어요'),
              key: const Key('unreceived-incomes'),
              style: text.labelSmall?.copyWith(color: colors.heroSub),
            ),
          ],
        ],
      ),
    );
  }
}

/// 카드 안에서 누를 수 있는 자리. 화면 읽기 도구에는 단추로 알린다.
class _TapArea extends StatelessWidget {
  const _TapArea({
    required this.tapKey,
    required this.onTap,
    required this.child,
  });

  final Key tapKey;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        key: tapKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
    );
  }
}

class _CashFlow extends StatelessWidget {
  const _CashFlow({
    required this.icon,
    required this.label,
    required this.amount,
    required this.amountKey,
  });

  final IconData icon;
  final String label;
  final int amount;
  final Key amountKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Row(
          spacing: 4,
          children: [
            Icon(icon, size: 14, color: colors.heroSub),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colors.heroSub,
                ),
              ),
            ),
          ],
        ),
        AmountText(
          amount,
          textKey: amountKey,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: colors.onHero,
          ),
        ),
      ],
    );
  }
}

/// 항목이 하나도 없는 달의 안내.
class _EmptyMonthNotice extends StatelessWidget {
  const _EmptyMonthNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      key: const Key('empty-month'),
      spacing: 6,
      children: [
        Icon(Icons.info_outline, size: 16, color: color),
        Expanded(
          child: Text(
            keepAll('아직 이 달에 적은 항목이 없어요.'),
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// 이번 달 지출과 저축 두 칸. 글자 길이가 달라도 두 칸 높이를 맞춘다.
class _MetricTiles extends StatelessWidget {
  const _MetricTiles({
    required this.totals,
    required this.onSpending,
    required this.onSaving,
  });

  final BudgetSummary totals;
  final VoidCallback onSpending;
  final VoidCallback onSaving;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Expanded(
            child: _MetricTile(
              tapKey: const Key('home-spending'),
              onTap: onSpending,
              icon: Icons.receipt_long_outlined,
              label: '이번 달 지출',
              amount: totals.spending,
              amountKey: const Key('spending'),
              caption: '고정 지출 + 추가 지출',
            ),
          ),
          Expanded(
            child: _MetricTile(
              tapKey: const Key('home-saving'),
              onTap: onSaving,
              icon: Icons.savings_outlined,
              label: '저축',
              amount: totals.saving,
              amountKey: const Key('saving'),
              caption: '저축으로 집계하는 분류',
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.tapKey,
    required this.onTap,
    required this.icon,
    required this.label,
    required this.amount,
    required this.amountKey,
    required this.caption,
  });

  final IconData icon;
  final String label;
  final int amount;
  final Key amountKey;
  final String caption;
  final Key tapKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
      child: _TapArea(
        tapKey: tapKey,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              Row(
                spacing: 6,
                children: [
                  Icon(icon, size: 16, color: context.appColors.accentText),
                  Expanded(
                    child: Text(label, style: theme.textTheme.labelMedium),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              AmountText(
                amount,
                textKey: amountKey,
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 18),
              ),
              Text(
                keepAll(caption),
                style: theme.textTheme.labelSmall?.copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 카드: 이번 달 사용분(다음 달 청구 예정)과 카드별 소계, 저번 달 사용분(이번 달 카드 대금).
/// 이번 달 사용분 줄을 누르면 내역의 지출 칸, 저번 달 사용분 줄을 누르면 카드 대금 칸으로 간다.
class _CardSection extends StatelessWidget {
  const _CardSection({
    required this.summary,
    required this.month,
    required this.onUsage,
    required this.onBills,
  });

  final MonthSummary summary;
  final YearMonth month;
  final VoidCallback onUsage;
  final VoidCallback onBills;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totals = summary.totals;
    final lineStyle = theme.textTheme.bodySmall;
    return Card(
      key: const Key('card-section'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 4,
          children: [
            const SectionTitle(icon: Icons.credit_card, title: '카드'),
            _CardUsageRow(
              key: const Key('card-usage'),
              onTap: onUsage,
              month: month.next,
              title: '이번 달 사용분',
              caption: '다음 달 청구 예정',
              amount: totals.cardUsage,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: 48,
                  bottom: summary.cards.isEmpty ? 0 : 8,
                ),
                child: Column(
                  children: [
                    for (final (:card, :amount) in summary.cards)
                      Padding(
                        key: ValueKey('card-${card.id}'),
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          spacing: 8,
                          children: [
                            Expanded(
                              child: Text(
                                card.name,
                                overflow: TextOverflow.ellipsis,
                                style: lineStyle,
                              ),
                            ),
                            Text(
                              won(amount),
                              style: lineStyle?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            _CardUsageRow(
              key: const Key('card-bills'),
              onTap: onBills,
              month: month,
              title: '저번 달 사용분',
              caption: '이번 달 출금 · 카드 대금 ${summary.cardBillCount}건',
              amount: totals.cardBillTotal,
            ),
          ],
        ),
      ),
    );
  }
}

/// 카드 영역의 한 줄. 왼쪽 네모에 청구·출금 달을 적는다. 누르면 그 줄에 맞는 내역 칸으로 간다.
class _CardUsageRow extends StatelessWidget {
  const _CardUsageRow({
    required this.onTap,
    required this.month,
    required this.title,
    required this.caption,
    required this.amount,
    super.key,
  });

  final YearMonth month;
  final String title;
  final String caption;
  final int amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              spacing: 12,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${month.month}월',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        keepAll(title),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(keepAll(caption), style: theme.textTheme.labelSmall),
                    ],
                  ),
                ),
                // 글자를 키워도 줄이 넘치지 않게 금액은 줄 폭의 40%까지만 쓰고, 넘으면 줄인다.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.4,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      won(amount),
                      maxLines: 1,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryLoading extends StatelessWidget {
  const _SummaryLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: Key('summary-loading'),
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _SummaryFailed extends StatelessWidget {
  const _SummaryFailed();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('summary-failed'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Text(
          keepAll('이 달 요약을 불러오지 못했어요. 잠시 후 다시 열어 주세요.'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ),
    );
  }
}
