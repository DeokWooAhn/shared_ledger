import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widget/keep_all.dart';
import '../../core/widget/member_avatar.dart';
import '../../core/widget/month_header.dart';
import '../../core/widget/no_months_notice.dart';
import '../../core/widget/summary_parts.dart';
import '../../core/widget/tab_page.dart';
import '../../domain/budget/month_summary.dart';
import '../../domain/budget/statistics.dart';
import '../../domain/format/won.dart';
import '../../domain/model/member.dart';
import '../../domain/model/year_month.dart';

/// 통계 탭. 보고 있는 달까지 그동안 모은 돈과 달마다 모은 돈, 그달 지출과 앞 달 대비,
/// 고정 지출의 분류별·구성원별 소계, 결제수단별 지출을 보여준다.
///
/// 홈과 헷갈리지 않게 머리말은 '통계' 제목과 기간 칩(`11월까지 ▾`)이고, 진한 파란 카드 대신 그래프가 먼저 보이는 흰 카드를 쓴다.
/// 모은 돈은 달마다 빠져나간 저축 + 남는 현금의 합이다(`docs/plan.md`의 '계산 규칙').
/// 저장소를 부르는 동작이 없어 Notifier 없이 [statisticsProvider]만 읽는다.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({required this.openMonths, super.key});

  /// 기간 칩을 누르면 여는 달 고르기. 화면 이동은 router.dart가 정해서 넘겨준다.
  final void Function(BuildContext context) openMonths;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noMonths = ref.watch(ledgerMonthsProvider)?.isEmpty ?? false;
    // 달이 없으면 읽을 것도 없어서 통계 구독을 열지 않는다.
    final stats = noMonths ? null : ref.watch(statisticsProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final bodyWidth = constraints.maxWidth - tabPageSidePadding * 2;
        final twoColumns = bodyWidth >= summaryTwoColumnMinWidth;
        return TabPage(
          header: _StatsHeader(openMonths: openMonths),
          maxWidth: twoColumns ? summaryTwoColumnMaxWidth : tabPageMaxWidth,
          children: [
            switch (stats) {
              null => const NoMonthsNotice(),
              AsyncData(:final value) => _StatsBody(
                stats: value,
                twoColumns: twoColumns,
              ),
              AsyncError() => const _StatsFailed(),
              AsyncLoading() => const _StatsLoading(),
            },
          ],
        );
      },
    );
  }
}

/// '통계' 제목과 기간 칩. 칩에는 보고 있는 달을 적고, 누르면 달 고르기를 연다.
class _StatsHeader extends ConsumerWidget {
  const _StatsHeader({required this.openMonths});

  final void Function(BuildContext context) openMonths;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final month = ref.watch(selectedMonthProvider);
    final current = YearMonth.of(ref.watch(clockProvider)());
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text('통계', style: theme.textTheme.headlineMedium),
            ),
          ),
          Semantics(
            hint: '월별 가계부 열기',
            child: FilledButton.tonalIcon(
              key: const Key('open-months'),
              onPressed: () => openMonths(context),
              iconAlignment: IconAlignment.end,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                tapTargetSize: MaterialTapTargetSize.padded,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: const Icon(Icons.keyboard_arrow_down, size: 20),
              label: Text(
                '${monthLabel(month, current: current)}까지',
                key: const Key('stats-period'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsBody extends ConsumerWidget {
  const _StatsBody({required this.stats, required this.twoColumns});

  final Statistics stats;
  final bool twoColumns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider).value ?? const [];
    final current = YearMonth.of(ref.watch(clockProvider)());
    final saved = stats.savedMonths == null
        ? const _SavedUnknown()
        : _SavedCard(stats: stats);
    final spending = _SpendingCard(stats: stats, current: current);
    final memberSplit = _MemberSection(
      summary: stats.summary,
      members: members,
    );
    final payments = _PaymentSection(
      payments: stats.payments,
      spending: stats.summary.totals.spending,
    );
    if (twoColumns) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          Expanded(child: saved),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [spending, memberSplit, payments],
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [saved, spending, memberSplit, payments],
    );
  }
}

/// 그동안 모은 돈: 보고 있는 달까지의 합계, 저축·남은 현금으로 나눈 값, 최근 달들의 막대를 한 카드에 둔다.
class _SavedCard extends StatelessWidget {
  const _SavedCard({required this.stats});

  final Statistics stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final count = stats.savedMonths?.length ?? 0;
    final muted = theme.textTheme.bodySmall;
    final part = muted?.copyWith(fontWeight: FontWeight.w700);
    final saving = theme.colorScheme.primary;
    final cash = colors.sea;
    final hasBars = stats.recentSaved.any((m) => m.saving != 0 || m.cash != 0);
    Widget legend(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const SizedBox.square(dimension: 10),
        ),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
    return Card(
      key: const Key('saved-card'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              keepAll('그동안 모은 돈 · $count개 달'),
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: 2),
            AmountText(
              stats.saved ?? 0,
              textKey: const Key('saved-total'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: colors.accentText,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: [
                Text('저축', style: muted),
                Text(
                  won(stats.savedSaving ?? 0),
                  key: const Key('saved-saving'),
                  style: part,
                ),
                Text('· 남은 현금', style: muted),
                Text(
                  won(stats.savedCash ?? 0),
                  key: const Key('saved-cash'),
                  style: part,
                ),
              ],
            ),
            const SizedBox(height: 18),
            KeyedSubtree(
              key: const Key('recent-saved'),
              child: _SavedBars(
                months: stats.recentSaved,
                selected: stats.month,
                saving: saving,
                cash: cash,
                shortfall: theme.colorScheme.error,
              ),
            ),
            if (hasBars) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [legend(saving, '저축'), legend(cash, '남은 현금')],
              ),
            ],
            const SizedBox(height: 10),
            Text(
              keepAll('저축은 빠져나간 것만,\n남은 현금은 달마다 유입 − 유출을 더했어요.'),
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// 달 목록을 아직 모으지 않은 옛 가계부. 어느 달까지 더할지 몰라 모은 돈을 계산하지 않는다.
class _SavedUnknown extends StatelessWidget {
  const _SavedUnknown();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('saved-unknown'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          spacing: 6,
          children: [
            Text(
              keepAll('그동안 모은 돈은 달 목록이 모인 뒤에 보여요.'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            Text(
              keepAll('관리자나 편집자가 앱을 열면 달 목록이 모여요.'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// 달마다 모은 돈 막대. 화면 읽기 도구는 막대마다 달과 모은 돈을 읽는다.
class _SavedBars extends StatelessWidget {
  const _SavedBars({
    required this.months,
    required this.selected,
    required this.saving,
    required this.cash,
    required this.shortfall,
  });

  final List<MonthSaved> months;
  final YearMonth selected;
  final Color saving;
  final Color cash;
  final Color shortfall;

  /// 막대 영역의 높이.
  static const height = 120.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 기준선 위로 가장 높은 막대와 아래로 가장 깊은 막대가 영역을 꼭 채우게 비율을 정한다.
    final above = months.fold(
      0,
      (top, m) => max(top, m.saving + max(m.cash, 0)),
    );
    final below = months.fold(0, (bottom, m) => max(bottom, max(-m.cash, 0)));
    final range = above + below;
    // 모은 돈이 모두 0원이면 빈 막대 자리 대신 안내만 둔다.
    if (range == 0) {
      return Container(
        key: const Key('saved-bars-empty'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          keepAll('아직 모은 돈이 없어요.\n수입·지출을 적으면 막대로 보여요.'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      );
    }
    double scaled(int amount) => amount / range * height;
    const top = Radius.circular(4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned(
                top: scaled(above),
                left: 0,
                right: 0,
                child: Container(height: 1, color: theme.colorScheme.outline),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final m in months)
                    Semantics(
                      key: ValueKey('saved-bar-${m.month.id}'),
                      container: true,
                      label: '${m.month.month}월 모은 돈 ${won(m.total)}',
                      excludeSemantics: true,
                      child: SizedBox(
                        width: 18,
                        child: Column(
                          children: [
                            SizedBox(
                              height: scaled(above - m.saving - max(m.cash, 0)),
                            ),
                            if (m.cash > 0)
                              Container(
                                height: scaled(m.cash),
                                decoration: BoxDecoration(
                                  color: cash,
                                  borderRadius: const BorderRadius.vertical(
                                    top: top,
                                  ),
                                ),
                              ),
                            if (m.saving > 0)
                              Container(
                                height: scaled(m.saving),
                                decoration: BoxDecoration(
                                  color: saving,
                                  borderRadius: m.cash > 0
                                      ? null
                                      : const BorderRadius.vertical(top: top),
                                ),
                              ),
                            if (m.cash < 0)
                              Container(
                                height: scaled(-m.cash),
                                decoration: BoxDecoration(
                                  color: shortfall,
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: top,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final m in months)
                SizedBox(
                  width: 40,
                  child: Text(
                    '${m.month.month}월',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: m.month == selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: m.month == selected
                          ? context.appColors.accentText
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 그달 지출과 앞 달(가계부가 있는 바로 앞 달) 대비 칩, 고정 지출의 분류별 비율 띠와 범례.
class _SpendingCard extends StatelessWidget {
  const _SpendingCard({required this.stats, required this.current});

  final Statistics stats;
  final YearMonth current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = stats.summary;
    final spending = summary.totals.spending;
    final planned = summary.totals.plannedTotal;
    final unpriced = summary.unpricedPlannedCount;
    final categories = [
      for (final total in summary.categories)
        if (total.amount > 0) total,
    ];
    // 분류마다 포인트 색에서 점점 옅어지는 색을 준다. 이름·금액을 범례에 같이 적어 색만으로 구분하지 않는다.
    Color colorAt(int index) => Color.lerp(
      theme.colorScheme.primary,
      theme.colorScheme.surface,
      categories.length <= 1 ? 0 : index / categories.length * 0.8,
    )!;
    return Card(
      key: const Key('planned-section'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  '${monthLabel(stats.month, current: current)} 지출',
                  style: theme.textTheme.labelMedium,
                ),
                ?switch (stats.previous) {
                  null => null,
                  (:final month, spending: final before) => _ChangeChip(
                    month: month,
                    diff: spending - before,
                  ),
                },
              ],
            ),
            const SizedBox(height: 2),
            AmountText(
              spending,
              textKey: const Key('stats-spending'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 4,
              children: [
                Text('고정 지출', style: theme.textTheme.labelMedium),
                Text(
                  won(planned),
                  key: const Key('planned-total'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text('· 분류별', style: theme.textTheme.labelMedium),
              ],
            ),
            if (unpriced > 0)
              Text(
                keepAll('금액 미정 $unpriced건은 합계에서 빠져 있어요'),
                key: const Key('unpriced-planned'),
                style: theme.textTheme.labelSmall,
              ),
            const SizedBox(height: 8),
            if (categories.isEmpty)
              Text(
                keepAll('이 달에는 고정 지출이 없어요.'),
                style: theme.textTheme.bodySmall,
              )
            else ...[
              ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: SizedBox(
                    height: 10,
                    child: Row(
                      spacing: 2,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (index, (category: _, :amount))
                            in categories.indexed)
                          Expanded(
                            flex: amount,
                            child: ColoredBox(color: colorAt(index)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              for (final (index, (:category, :amount)) in categories.indexed)
                _CategoryLegend(
                  key: ValueKey('category-${category?.id}'),
                  color: colorAt(index),
                  name: category?.name ?? '분류 없음',
                  countsAsSaving: category?.countsAsSaving ?? false,
                  amount: amount,
                  share: planned == 0 ? 0 : amount / planned,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 앞 달보다 늘거나 줄어든 지출. 늘면 경고 색, 줄면 포인트 색이고 글자로도 '+'·'−'를 적는다.
class _ChangeChip extends StatelessWidget {
  const _ChangeChip({required this.month, required this.diff});

  final YearMonth month;
  final int diff;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, foreground, background) = switch (diff) {
      0 => (
        '${month.month}월과 같아요',
        scheme.onSurfaceVariant,
        scheme.surfaceContainerHighest,
      ),
      > 0 => (
        '${month.month}월보다 +${won(diff)}',
        scheme.error,
        scheme.errorContainer,
      ),
      _ => (
        '${month.month}월보다 −${won(-diff)}',
        scheme.onPrimaryContainer,
        scheme.primaryContainer,
      ),
    };
    return Container(
      key: const Key('spending-change'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

/// 분류 띠의 범례 한 줄: 색 점, 이름(저축 표시), 비율, 금액.
class _CategoryLegend extends StatelessWidget {
  const _CategoryLegend({
    required this.color,
    required this.name,
    required this.countsAsSaving,
    required this.amount,
    required this.share,
    super.key,
  });

  final Color color;
  final String name;
  final bool countsAsSaving;
  final int amount;
  final double share;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(fontSize: 14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      // 글자를 키우면 이름·저축 표시·비율은 다음 줄로 넘기고, 금액은 오른쪽에 둔다.
      child: Row(
        spacing: 8,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: const SizedBox.square(dimension: 10),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(name, style: style?.copyWith(fontWeight: FontWeight.w500)),
                if (countsAsSaving) const _SavingPill(),
                Text(
                  '${(share * 100).round()}%',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          Text(
            won(amount),
            style: style?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// 구성원별 고정 지출: 두 사람 몫을 한 막대에 나누고 아래에 금액을 적는다.
class _MemberSection extends StatelessWidget {
  const _MemberSection({required this.summary, required this.members});

  final MonthSummary summary;
  final List<Member> members;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('member-section'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            const SectionTitle(icon: Icons.people_outline, title: '구성원별 고정 지출'),
            _MemberSplit(
              owner: summary.plannedOf(MemberSlot.owner),
              partner: summary.plannedOf(MemberSlot.partner),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              spacing: 16,
              children: [
                for (final slot in MemberSlot.values)
                  Flexible(
                    child: _MemberTotal(
                      key: Key('member-${slot.name}'),
                      member: memberIn(members, slot),
                      amount: summary.plannedOf(slot),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 결제수단별 지출(고정 지출 + 추가 지출). 쓴 결제수단만 그달 지출에서 차지하는 비율 막대와 함께 보여준다.
class _PaymentSection extends StatelessWidget {
  const _PaymentSection({required this.payments, required this.spending});

  final List<PaymentTotal> payments;
  final int spending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rowStyle = theme.textTheme.bodyMedium?.copyWith(fontSize: 14);
    return Card(
      key: const Key('payment-section'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            const SectionTitle(
              icon: Icons.account_balance_wallet_outlined,
              title: '결제수단별 지출',
            ),
            if (payments.isEmpty)
              Text(keepAll('이 달에 쓴 돈이 없어요.'), style: theme.textTheme.bodySmall),
            for (final (:method, :amount) in payments)
              Column(
                key: ValueKey('payment-${method?.id}'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 6,
                children: [
                  Row(
                    spacing: 6,
                    children: [
                      Expanded(
                        child: Text(
                          method?.name ?? '결제수단 없음',
                          overflow: TextOverflow.ellipsis,
                          style: rowStyle?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        won(amount),
                        style: rowStyle?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  ShareBar(
                    share: spending == 0 ? 0 : amount / spending,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
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

/// 두 사람의 고정 지출을 한 막대에 나눠 그린다. 관리자는 진하게, 상대는 흐리게.
class _MemberSplit extends StatelessWidget {
  const _MemberSplit({required this.owner, required this.partner});

  final int owner;
  final int partner;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    const round = Radius.circular(5);
    Widget part(int amount, Color color, {required bool start}) {
      final alone = owner == 0 || partner == 0;
      return Expanded(
        flex: amount,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadiusDirectional.horizontal(
              start: start || alone ? round : Radius.zero,
              end: !start || alone ? round : Radius.zero,
            ),
          ),
        ),
      );
    }

    return ExcludeSemantics(
      child: SizedBox(
        key: const Key('member-split'),
        height: 10,
        child: owner + partner == 0
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: const BorderRadius.all(round),
                ),
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: owner > 0 && partner > 0 ? 3 : 0,
                children: [
                  if (owner > 0) part(owner, colors.sky, start: true),
                  if (partner > 0) part(partner, colors.sea, start: false),
                ],
              ),
      ),
    );
  }
}

class _MemberTotal extends StatelessWidget {
  const _MemberTotal({required this.member, required this.amount, super.key});

  final Member member;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w700);
    final barColor = switch (member.slot) {
      MemberSlot.owner => context.appColors.sky,
      MemberSlot.partner => context.appColors.sea,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        // 프로필이 둘 다 회색이라, 막대 색 점으로 어느 막대가 누구인지 잇는다.
        DecoratedBox(
          decoration: BoxDecoration(color: barColor, shape: BoxShape.circle),
          child: const SizedBox.square(dimension: 10),
        ),
        MemberAvatar(member: member, size: 24),
        // 금액이 '원' 앞에서 줄바뀌지 않게, 폭이 모자라면 줄인다.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(won(amount), maxLines: 1, style: style),
          ),
        ),
      ],
    );
  }
}

class _StatsLoading extends StatelessWidget {
  const _StatsLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: Key('stats-loading'),
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _StatsFailed extends StatelessWidget {
  const _StatsFailed();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('stats-failed'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Text(
          keepAll('통계를 불러오지 못했어요.\n잠시 후 다시 열어 주세요.'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ),
    );
  }
}
