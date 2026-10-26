import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/budget/budget_summary.dart';
import '../../core/budget/month_summary.dart';
import '../../core/data/providers.dart';
import '../../core/model/member.dart';
import '../../core/model/year_month.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widget/keep_all.dart';
import '../../core/widget/member_avatar.dart';
import '../../core/widget/month_header.dart';
import '../../core/widget/tab_page.dart';
import '../../core/widget/won.dart';

/// 본문(양옆 여백을 뺀 폭)이 이 폭 이상이면 월 요약을 두 칸으로 놓는다.
/// 아이패드를 가로로 놓은 정도다(세로는 한 칸).
const summaryTwoColumnMinWidth = 840.0;

/// 두 칸일 때 본문의 최대 폭.
const summaryTwoColumnMaxWidth = 960.0;

/// 월 요약 탭. 보고 있는 달의 남는 현금, 이번 달 지출·저축, 카드, 기본 월 지출 소계를 보여준다.
///
/// 저장소를 부르는 동작이 없어 컨트롤러 없이 [monthSummaryProvider]만 읽는다.
class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({required this.openCalendar, super.key});

  /// 달 이름을 누르면 여는 달력. 화면 이동은 router.dart가 정해서 넘겨준다.
  final void Function(BuildContext context) openCalendar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(monthSummaryProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final bodyWidth = constraints.maxWidth - tabPageSidePadding * 2;
        final twoColumns = bodyWidth >= summaryTwoColumnMinWidth;
        return TabPage(
          header: MonthHeader(openCalendar: openCalendar),
          maxWidth: twoColumns ? summaryTwoColumnMaxWidth : tabPageMaxWidth,
          children: [
            switch (summary) {
              AsyncData(:final value) => _SummaryBody(
                summary: value,
                twoColumns: twoColumns,
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
  const _SummaryBody({required this.summary, required this.twoColumns});

  final MonthSummary summary;
  final bool twoColumns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final members = ref.watch(membersProvider).value ?? const [];
    final totals = summary.totals;
    final cash = _CashCard(totals: totals);
    final empty = summary.isEmpty ? const _EmptyMonthNotice() : null;
    final metrics = _MetricTiles(totals: totals);
    final cards = summary.showsCards
        ? _CardSection(summary: summary, month: month)
        : null;
    final planned = _PlannedSection(summary: summary, members: members);
    if (twoColumns) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [cash, ?empty, metrics, ?cards],
            ),
          ),
          Expanded(child: planned),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [cash, ?empty, metrics, ?cards, planned],
    );
  }
}

/// 남는 현금과 현금 유입·유출. 라이트·다크 모두 진한 코발트 카드다.
class _CashCard extends StatelessWidget {
  const _CashCard({required this.totals});

  final BudgetSummary totals;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.hero,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -70,
            right: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.onHero.withValues(alpha: 0.07),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '남는 현금',
                  style: text.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colors.heroSub,
                  ),
                ),
                const SizedBox(height: 4),
                _Amount(
                  totals.remainingCash,
                  textKey: const Key('remaining-cash'),
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: colors.accentOnDark,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 1,
                  color: colors.onHero.withValues(alpha: 0.15),
                ),
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
              ],
            ),
          ),
        ],
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
        _Amount(
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
  const _MetricTiles({required this.totals});

  final BudgetSummary totals;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Expanded(
            child: _MetricTile(
              icon: Icons.receipt_long_outlined,
              label: '이번 달 지출',
              amount: totals.spending,
              amountKey: const Key('spending'),
              caption: '기본 지출 + 추가지출',
            ),
          ),
          Expanded(
            child: _MetricTile(
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
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
                Flexible(
                  child: Text(label, style: theme.textTheme.labelMedium),
                ),
              ],
            ),
            _Amount(
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
    );
  }
}

/// 카드: 이번 달 사용분(다음 달 청구 예정)과 카드별 소계, 저번 달 사용분(이번 달 카드대금).
class _CardSection extends StatelessWidget {
  const _CardSection({required this.summary, required this.month});

  final MonthSummary summary;
  final YearMonth month;

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
            const _SectionTitle(icon: Icons.credit_card, title: '카드'),
            _CardUsageRow(
              key: const Key('card-usage'),
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
              month: month,
              title: '저번 달 사용분',
              caption: '이번 달 출금 · 카드대금 ${summary.cardBillCount}건',
              amount: totals.cardBillTotal,
            ),
          ],
        ),
      ),
    );
  }
}

/// 카드 영역의 한 줄. 왼쪽 네모에 청구·출금 달을 적는다.
class _CardUsageRow extends StatelessWidget {
  const _CardUsageRow({
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
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
          Text(
            won(amount),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 기본 월 지출: 합계, 분류별 막대, 구성원별 막대.
class _PlannedSection extends StatelessWidget {
  const _PlannedSection({required this.summary, required this.members});

  final MonthSummary summary;
  final List<Member> members;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = summary.totals.plannedTotal;
    final unpriced = summary.unpricedPlannedCount;
    final subLabel = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    return Card(
      key: const Key('planned-section'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 2,
              children: [
                // 글자를 키워 한 줄에 다 들어가지 않으면 합계를 다음 줄로 내린다.
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    const _SectionTitle(
                      icon: Icons.event_available_outlined,
                      title: '기본 월 지출',
                    ),
                    Text(
                      won(total),
                      key: const Key('planned-total'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                if (unpriced > 0)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 26),
                    child: Text(
                      keepAll('금액 미정 $unpriced건은 합계에서 빠져 있어요'),
                      key: const Key('unpriced-planned'),
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
            if (summary.categories.isNotEmpty) ...[
              Text('분류별', style: subLabel),
              for (final (:category, :amount) in summary.categories)
                _CategoryBar(
                  key: ValueKey('category-${category?.id}'),
                  name: category?.name ?? '분류 없음',
                  countsAsSaving: category?.countsAsSaving ?? false,
                  amount: amount,
                  share: total == 0 ? 0 : amount / total,
                ),
            ],
            Text('구성원별', style: subLabel),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        Icon(icon, size: 18, color: context.appColors.accentText),
        Flexible(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}

/// 분류 하나의 이름·금액과 기본 월 지출에서 차지하는 비율 막대.
/// 저축으로 세는 분류는 '저축' 표시를 붙이고 막대를 진하게 칠한다(색만으로 구분하지 않는다).
class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.name,
    required this.countsAsSaving,
    required this.amount,
    required this.share,
    super.key,
  });

  final String name;
  final bool countsAsSaving;
  final int amount;
  final double share;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rowStyle = theme.textTheme.bodyMedium?.copyWith(fontSize: 14);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Row(
          spacing: 6,
          children: [
            Expanded(
              child: Row(
                spacing: 6,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: rowStyle?.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (countsAsSaving) const _SavingPill(),
                ],
              ),
            ),
            Text(
              won(amount),
              style: rowStyle?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        _ShareBar(
          share: share,
          color: countsAsSaving ? scheme.primary : context.appColors.barMuted,
        ),
      ],
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

/// 비율 막대. 숫자는 옆 글자로 읽으므로 화면 읽기 도구에는 알리지 않는다.
class _ShareBar extends StatelessWidget {
  const _ShareBar({required this.share, required this.color});

  final double share;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(4));
    return ExcludeSemantics(
      child: SizedBox(
        height: 8,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outlineVariant,
            borderRadius: radius,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: share.clamp(0.0, 1.0),
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color, borderRadius: radius),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 두 사람의 기본 월 지출을 한 막대에 나눠 그린다. 관리자는 진하게, 상대는 흐리게.
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

/// 큰 금액. 글자를 키우거나 금액이 길어도 잘리지 않게 폭이 모자라면 줄인다.
class _Amount extends StatelessWidget {
  const _Amount(this.amount, {required this.style, this.textKey});

  final int amount;
  final TextStyle? style;

  /// 테스트에서 금액 글자를 찾을 키.
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Text(won(amount), key: textKey, maxLines: 1, style: style),
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
