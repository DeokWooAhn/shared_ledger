import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widget/keep_all.dart';
import '../../core/widget/member_avatar.dart';
import '../../core/widget/no_months_notice.dart';
import '../../core/widget/summary_parts.dart';
import '../../core/widget/tab_page.dart';
import '../../domain/budget/statistics.dart';
import '../../domain/format/won.dart';
import '../../domain/model/member.dart';
import 'stats_period_sheet.dart';

/// 그래프가 그려지는 시간. 통계 탭에 들어올 때와 기간을 바꿀 때 막대가 자라고 도넛이 돈다.
const statsRevealDuration = Duration(milliseconds: 700);

/// 도넛에 색으로 나눠 넣는 가장 많은 조각 수. 넘치면 뒤의 것을 '기타' 하나로 묶는다.
const statsDonutSlices = 6;

/// 통계 탭. 고른 기간(기본은 최근 6개월)의 수입 대비 지출·저축 비율, 모은 돈과 달마다 모은 돈, 지출의 분류별 도넛,
/// 고정 지출의 구성원별 막대, 결제수단별 막대를 보여준다.
///
/// 머리말은 '통계' 제목과 기간 단추(아이콘)이고, 기간은 본문 맨 위에 적는다. 설명 글은 두지 않는다.
/// 탭에 들어올 때마다(가려졌다 다시 보일 때)와 기간을 바꿀 때 그래프를 처음부터 그린다. 움직임 줄이기면 바로 다 그린다.
/// 모은 돈은 달마다 빠져나간 저축 + 남는 현금의 합이다(`docs/plan.md`의 '계산 규칙').
/// 저장소를 부르는 동작이 없어 Notifier 없이 공급자만 읽는다.
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen>
    with SingleTickerProviderStateMixin {
  late final _reveal = AnimationController(
    vsync: this,
    duration: statsRevealDuration,
  );
  late final _drawn = CurvedAnimation(
    parent: _reveal,
    curve: Curves.easeOutCubic,
  );

  // 탭이 보이는지. 탭은 화면 상태를 지키려고 가려질 뿐 그대로 있어서, 다시 보일 때를 여기서 안다.
  var _active = false;

  // 그래프를 처음부터 그린다. 움직임 줄이기를 켰으면 바로 다 그린다.
  void _draw() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _reveal.value = 1;
      return;
    }
    unawaited(_reveal.forward(from: 0));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.valuesOf(context).enabled;
    if (active && !_active) _draw();
    _active = active;
  }

  @override
  void dispose() {
    _drawn.dispose();
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final noMonths = ref.watch(ledgerMonthsProvider)?.isEmpty ?? false;
    // 달이 없으면 읽을 것도 없어서 통계 구독을 열지 않는다.
    final stats = noMonths ? null : ref.watch(statisticsProvider);
    if (!noMonths) {
      // 받기를 마쳤을 때와 기간을 바꿨을 때 그래프를 새로 그린다.
      ref.listen(statisticsProvider, (previous, next) {
        if (next is AsyncData && previous is! AsyncData) _draw();
      });
      ref.listen(statsPeriodProvider, (_, _) => _draw());
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final bodyWidth = constraints.maxWidth - tabPageSidePadding * 2;
        final twoColumns = bodyWidth >= summaryTwoColumnMinWidth;
        return TabPage(
          header: const _StatsHeader(),
          maxWidth: twoColumns ? summaryTwoColumnMaxWidth : tabPageMaxWidth,
          children: [
            if (stats == null)
              const NoMonthsNotice()
            else ...[
              const _PeriodLine(),
              const SizedBox(height: 12),
              switch (stats) {
                AsyncData(:final value) => _StatsBody(
                  stats: value,
                  twoColumns: twoColumns,
                  drawn: _drawn,
                ),
                AsyncError() => const _StatsFailed(),
                AsyncLoading() => const _StatsLoading(),
              },
            ],
          ],
        );
      },
    );
  }
}

/// '통계' 제목과 기간 단추. 단추를 누르면 조회 기간 시트를 연다.
class _StatsHeader extends StatelessWidget {
  const _StatsHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          IconButton(
            key: const Key('open-stats-period'),
            tooltip: '기간 설정',
            onPressed: () => unawaited(showStatsPeriodSheet(context)),
            icon: const Icon(Icons.date_range_outlined),
          ),
        ],
      ),
    );
  }
}

/// 본문 맨 위의 기간. 예: '2026년 6월 ~ 11월'
class _PeriodLine extends ConsumerWidget {
  const _PeriodLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Text(
      statsPeriodLabel(ref.watch(statsPeriodProvider)),
      key: const Key('stats-period'),
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15),
    );
  }
}

class _StatsBody extends ConsumerWidget {
  const _StatsBody({
    required this.stats,
    required this.twoColumns,
    required this.drawn,
  });

  final Statistics stats;
  final bool twoColumns;
  final Animation<double> drawn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider).value ?? const [];
    final income = _IncomeCard(stats: stats, drawn: drawn);
    final saved = _SavedCard(stats: stats, drawn: drawn);
    final rest = [
      _SpendingCard(stats: stats, drawn: drawn),
      if (MemberSlot.values.any((slot) => stats.plannedOf(slot) > 0))
        _MemberSection(stats: stats, members: members, drawn: drawn),
      if (stats.payments.isNotEmpty)
        _PaymentSection(
          payments: stats.payments,
          spending: stats.spending,
          drawn: drawn,
        ),
    ];
    if (twoColumns) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [income, saved],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: rest,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [income, saved, ...rest],
    );
  }
}

/// 수입 대비 비율의 한 칸: 이름, 금액, 색.
typedef _IncomePart = ({Key key, String name, int amount, Color color});

/// 수입: 기간 수입과, 그 수입에서 지출(저축 제외)·저축·남은 돈이 차지하는 비율을 한 막대(왼쪽에서 자란다)와 범례로 보여준다.
/// 지출이 수입보다 많으면 막대는 지출·저축으로만 채우고 넘친 만큼을 '초과'로 알린다. 수입이 없으면 비율은 적지 않는다.
class _IncomeCard extends StatelessWidget {
  const _IncomeCard({required this.stats, required this.drawn});

  final Statistics stats;
  final Animation<double> drawn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final income = stats.income;
    final over = max(-stats.left, 0);
    final List<_IncomePart> parts = [
      (
        key: const Key('income-consumption'),
        name: '지출',
        amount: stats.consumption,
        color: colors.chart[1],
      ),
      (
        key: const Key('income-saving'),
        name: '저축',
        amount: stats.saving,
        color: theme.colorScheme.primary,
      ),
      if (stats.left > 0)
        (
          key: const Key('income-left'),
          name: '남은 돈',
          amount: stats.left,
          color: colors.sea,
        ),
    ];
    final shown = [
      for (final part in parts)
        if (part.amount > 0) part,
    ];
    String? share(int amount) =>
        income > 0 ? '${(amount / income * 100).round()}%' : null;
    return Card(
      key: const Key('income-card'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('수입', style: theme.textTheme.labelMedium),
            const SizedBox(height: 2),
            AmountText(
              income,
              textKey: const Key('stats-income'),
              identifier: 'stats-income',
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (shown.isNotEmpty) ...[
              const SizedBox(height: 14),
              ExcludeSemantics(
                child: AnimatedBuilder(
                  animation: drawn,
                  builder: (context, child) => Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      widthFactor: drawn.value,
                      child: child,
                    ),
                  ),
                  child: ClipRRect(
                    key: const Key('income-split'),
                    borderRadius: BorderRadius.circular(7),
                    child: SizedBox(
                      height: 14,
                      child: Row(
                        spacing: 2,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final part in shown)
                            Expanded(
                              flex: part.amount,
                              child: ColoredBox(color: part.color),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              for (final part in shown)
                _IncomeLegend(
                  key: part.key,
                  color: part.color,
                  name: part.name,
                  share: share(part.amount),
                  amount: part.amount,
                ),
              if (over > 0)
                _IncomeLegend(
                  key: const Key('income-over'),
                  color: theme.colorScheme.error,
                  name: '초과',
                  share: share(over),
                  amount: over,
                  danger: true,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 수입 대비 비율의 범례 한 줄: 색 점, 이름, 수입에서 차지하는 비율, 금액.
class _IncomeLegend extends StatelessWidget {
  const _IncomeLegend({
    required this.color,
    required this.name,
    required this.share,
    required this.amount,
    this.danger = false,
    super.key,
  });

  final Color color;
  final String name;
  final String? share;
  final int amount;

  /// 수입을 넘긴 지출이라 오류 색으로 적는지.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 14,
      color: danger ? theme.colorScheme.error : null,
    );
    final share = this.share;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(name, style: style?.copyWith(fontWeight: FontWeight.w500)),
                if (share != null)
                  Text(share, style: theme.textTheme.labelSmall),
              ],
            ),
          ),
          Text(
            won(amount),
            style: style?.copyWith(fontWeight: FontWeight.w700).tabularFigures,
          ),
        ],
      ),
    );
  }
}

/// 모은 돈: 기간 합계, 저축·남은 현금으로 나눈 값, 달마다 모은 돈 막대(두 달 이상일 때).
class _SavedCard extends StatelessWidget {
  const _SavedCard({required this.stats, required this.drawn});

  final Statistics stats;
  final Animation<double> drawn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final muted = theme.textTheme.bodySmall;
    final part = muted?.copyWith(fontWeight: FontWeight.w700);
    final saving = theme.colorScheme.primary;
    final cash = colors.sea;
    final months = stats.savedMonths;
    final hasBars =
        months.length > 1 && months.any((m) => m.saving != 0 || m.cash != 0);
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
            Text('모은 돈', style: theme.textTheme.labelMedium),
            const SizedBox(height: 2),
            AmountText(
              stats.saved,
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
                  won(stats.savedSaving),
                  key: const Key('saved-saving'),
                  style: part,
                ),
                Text('· 남은 현금', style: muted),
                Text(
                  won(stats.savedCash),
                  key: const Key('saved-cash'),
                  style: part,
                ),
              ],
            ),
            if (hasBars) ...[
              const SizedBox(height: 18),
              KeyedSubtree(
                key: const Key('recent-saved'),
                child: _SavedBars(
                  months: months,
                  saving: saving,
                  cash: cash,
                  shortfall: theme.colorScheme.error,
                  drawn: drawn,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [legend(saving, '저축'), legend(cash, '남은 현금')],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 달마다 모은 돈 막대. 기준선에서 자라 오르고(모자란 달은 아래로), 막대 끝에 그달 금액을 짧게 적는다.
/// 화면 읽기 도구는 막대마다 달과 정확한 금액을 읽는다.
class _SavedBars extends StatelessWidget {
  const _SavedBars({
    required this.months,
    required this.saving,
    required this.cash,
    required this.shortfall,
    required this.drawn,
  });

  final List<MonthSaved> months;
  final Color saving;
  final Color cash;
  final Color shortfall;
  final Animation<double> drawn;

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
    final range = max(above + below, 1);
    double scaled(int amount) => amount / range * height;
    // 막대 위(모자란 달은 아래)에 적는 금액의 자리. 글자를 키우면 같이 늘린다.
    final label = MediaQuery.textScalerOf(context).scale(11) * 1.3 + 4;
    final baseline = label + scaled(above);
    final total = label + height + (below > 0 ? label : 0);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        SizedBox(
          height: total,
          child: Stack(
            children: [
              Positioned(
                top: baseline,
                left: 0,
                right: 0,
                child: Container(height: 1, color: theme.colorScheme.outline),
              ),
              AnimatedBuilder(
                animation: drawn,
                builder: (context, _) {
                  final t = drawn.value;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final m in months)
                        Expanded(
                          child: Semantics(
                            key: ValueKey('saved-bar-${m.month.id}'),
                            container: true,
                            label: '${m.month.month}월 모은 돈 ${won(m.total)}',
                            excludeSemantics: true,
                            child: Stack(
                              children: [
                                Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: total,
                                    child: _SavedBar(
                                      month: m,
                                      baseline: baseline,
                                      scale: height / range * t,
                                      saving: saving,
                                      cash: cash,
                                      shortfall: shortfall,
                                    ),
                                  ),
                                ),
                                // 그달 모은 돈을 짧게(만 원 단위) 막대 끝에 붙여 적는다. 모자란 달은 아래에 빨갛게.
                                Positioned(
                                  top: m.total >= 0
                                      ? baseline -
                                            (m.saving + max(m.cash, 0)) *
                                                height /
                                                range *
                                                t -
                                            label
                                      : baseline +
                                            -min(m.cash, 0) *
                                                height /
                                                range *
                                                t,
                                  height: label,
                                  left: 0,
                                  right: 0,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      wonShort(m.total),
                                      key: ValueKey(
                                        'saved-amount-${m.month.id}',
                                      ),
                                      style: m.total < 0
                                          ? labelStyle?.copyWith(
                                              color: shortfall,
                                            )
                                          : labelStyle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        ExcludeSemantics(
          child: Row(
            children: [
              for (final m in months)
                Expanded(
                  // 열두 달이어도 한 줄에 들어가게 칸이 좁으면 줄인다.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${m.month.month}월',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
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

/// 한 달의 막대. 기준선([baseline])에서 위로 남은 현금·저축을 쌓고, 모자란 현금은 아래로 그린다.
/// [scale]은 1원의 높이다(그려지는 중이면 그만큼 작다).
class _SavedBar extends StatelessWidget {
  const _SavedBar({
    required this.month,
    required this.baseline,
    required this.scale,
    required this.saving,
    required this.cash,
    required this.shortfall,
  });

  final MonthSaved month;
  final double baseline;
  final double scale;
  final Color saving;
  final Color cash;
  final Color shortfall;

  @override
  Widget build(BuildContext context) {
    const radius = Radius.circular(4);
    final savingHeight = max(month.saving, 0) * scale;
    final cashHeight = month.cash * scale;
    Widget bar(double top, double height, Color color, BorderRadius? round) =>
        Positioned(
          top: top,
          height: height,
          left: 0,
          right: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, borderRadius: round),
          ),
        );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (month.saving > 0)
          bar(
            baseline - savingHeight,
            savingHeight,
            saving,
            month.cash > 0 ? null : const BorderRadius.vertical(top: radius),
          ),
        if (month.cash > 0)
          bar(
            baseline - savingHeight - cashHeight,
            cashHeight,
            cash,
            const BorderRadius.vertical(top: radius),
          ),
        if (month.cash < 0)
          bar(
            baseline,
            -cashHeight,
            shortfall,
            const BorderRadius.vertical(bottom: radius),
          ),
      ],
    );
  }
}

/// 도넛 한 조각: 이름, 금액, 색, 저축 분류인지.
typedef _Slice = ({
  Key key,
  String name,
  int amount,
  Color color,
  bool countsAsSaving,
});

/// 지출: 기간 합계와, 고정 지출 분류별 + 추가 지출을 나눈 도넛과 범례.
class _SpendingCard extends StatelessWidget {
  const _SpendingCard({required this.stats, required this.drawn});

  final Statistics stats;
  final Animation<double> drawn;

  // 분류(설정 순서) 다음에 추가 지출을 둔다. 색은 이 순서대로 쓰고, 넘치면 뒤의 것을 '기타'로 묶는다.
  List<_Slice> _slices(BuildContext context) {
    final colors = context.appColors;
    final parts = [
      for (final (:category, :amount) in stats.categories)
        (
          key: ValueKey<String>('category-${category?.id}'),
          name: category?.name ?? '분류 없음',
          amount: amount,
          countsAsSaving: category?.countsAsSaving ?? false,
        ),
      if (stats.extra > 0)
        (
          key: const ValueKey<String>('category-extra'),
          name: '추가 지출',
          amount: stats.extra,
          countsAsSaving: false,
        ),
    ];
    final named = parts.length <= statsDonutSlices
        ? parts
        : parts.take(statsDonutSlices - 1).toList();
    final rest = parts.skip(named.length).fold(0, (sum, p) => sum + p.amount);
    return [
      for (final (index, part) in named.indexed)
        (
          key: part.key,
          name: part.name,
          amount: part.amount,
          color: colors.chart[index % colors.chart.length],
          countsAsSaving: part.countsAsSaving,
        ),
      if (rest > 0)
        (
          key: const ValueKey('category-others'),
          name: '기타',
          amount: rest,
          color: colors.barMuted,
          countsAsSaving: false,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spending = stats.spending;
    final slices = spending > 0 ? _slices(context) : const <_Slice>[];
    final donut = ExcludeSemantics(
      child: CustomPaint(
        key: const Key('spending-donut'),
        size: const Size.square(128),
        painter: _DonutPainter(
          slices: [for (final s in slices) (s.amount / spending, s.color)],
          progress: drawn,
          gap: theme.colorScheme.surface,
        ),
      ),
    );
    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final slice in slices)
          _SliceLegend(
            key: slice.key,
            slice: slice,
            share: slice.amount / spending,
          ),
      ],
    );
    return Card(
      key: const Key('spending-section'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('지출', style: theme.textTheme.labelMedium),
            const SizedBox(height: 2),
            AmountText(
              spending,
              textKey: const Key('stats-spending'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (slices.isNotEmpty) ...[
              const SizedBox(height: 16),
              // 넓으면 도넛 옆에 범례를, 좁거나 글자가 크면 도넛 아래에 둔다.
              LayoutBuilder(
                // 범례 자리가 글자 열두 개 폭보다 좁으면 아래로 내린다.
                builder: (context, constraints) =>
                    constraints.maxWidth - 148 >=
                        MediaQuery.textScalerOf(context).scale(14) * 12
                    ? Row(
                        spacing: 20,
                        children: [
                          donut,
                          Expanded(child: legend),
                        ],
                      )
                    : Column(spacing: 12, children: [donut, legend]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 도넛. 12시 방향부터 시계 방향으로 조각을 그리고, [progress]만큼만 돌아 있다. 조각 사이에는 바탕색 틈을 둔다.
class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.slices,
    required this.progress,
    required this.gap,
  }) : super(repaint: progress);

  /// 조각의 비율(합이 1)과 색.
  final List<(double, Color)> slices;
  final Animation<double> progress;

  /// 조각 사이 틈의 색(카드 바탕).
  final Color gap;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.2;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final drawn = 2 * pi * progress.value;
    var start = -pi / 2;
    for (final (fraction, color) in slices) {
      final sweep = min(2 * pi * fraction, drawn - (start + pi / 2));
      if (sweep <= 0) break;
      canvas.drawArc(rect, start, sweep, false, paint..color = color);
      start += 2 * pi * fraction;
    }
    // 조각 경계마다 바탕색 선을 그어 틈을 낸다. 조각이 하나면 틈이 없다.
    if (slices.length < 2) return;
    final center = rect.center;
    final inner = rect.width / 2 - stroke / 2 - 1;
    final outer = rect.width / 2 + stroke / 2 + 1;
    final line = Paint()
      ..color = gap
      ..strokeWidth = 2;
    var angle = -pi / 2;
    for (final (fraction, _) in slices) {
      if (angle + pi / 2 > drawn) break;
      final direction = Offset(cos(angle), sin(angle));
      canvas.drawLine(
        center + direction * inner,
        center + direction * outer,
        line,
      );
      angle += 2 * pi * fraction;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress || old.gap != gap || !_same(old.slices, slices);

  static bool _same(List<(double, Color)> a, List<(double, Color)> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((same) => same);
}

/// 도넛 범례 한 줄: 색 점, 이름(저축 표시), 비율, 금액.
class _SliceLegend extends StatelessWidget {
  const _SliceLegend({required this.slice, required this.share, super.key});

  final _Slice slice;
  final double share;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(fontSize: 14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      // 글자를 키우면 이름·저축 표시·비율은 다음 줄로 넘기고, 금액은 오른쪽에 둔다.
      child: Row(
        spacing: 8,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: slice.color,
              shape: BoxShape.circle,
            ),
            child: const SizedBox.square(dimension: 10),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  slice.name,
                  style: style?.copyWith(fontWeight: FontWeight.w500),
                ),
                if (slice.countsAsSaving) const _SavingPill(),
                Text(
                  '${(share * 100).round()}%',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          Text(
            won(slice.amount),
            style: style?.copyWith(fontWeight: FontWeight.w700).tabularFigures,
          ),
        ],
      ),
    );
  }
}

/// 구성원별 고정 지출: 두 사람 몫을 한 막대에 나누고(왼쪽에서 자라 나온다) 아래에 금액을 적는다.
class _MemberSection extends StatelessWidget {
  const _MemberSection({
    required this.stats,
    required this.members,
    required this.drawn,
  });

  final Statistics stats;
  final List<Member> members;
  final Animation<double> drawn;

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
            AnimatedBuilder(
              animation: drawn,
              builder: (context, child) => Align(
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  widthFactor: drawn.value,
                  child: child,
                ),
              ),
              child: _MemberSplit(
                owner: stats.plannedOf(MemberSlot.owner),
                partner: stats.plannedOf(MemberSlot.partner),
              ),
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
                      amount: stats.plannedOf(slot),
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

/// 결제수단별 지출(고정 지출 + 추가 지출). 쓴 결제수단만, 기간 지출에서 차지하는 비율 막대(왼쪽에서 자란다)와 함께.
class _PaymentSection extends StatelessWidget {
  const _PaymentSection({
    required this.payments,
    required this.spending,
    required this.drawn,
  });

  final List<PaymentTotal> payments;
  final int spending;
  final Animation<double> drawn;

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
                        style: rowStyle
                            ?.copyWith(fontWeight: FontWeight.w700)
                            .tabularFigures,
                      ),
                    ],
                  ),
                  AnimatedBuilder(
                    animation: drawn,
                    builder: (context, _) => ShareBar(
                      share: spending == 0
                          ? 0
                          : amount / spending * drawn.value,
                      color: theme.colorScheme.primary,
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
        child: Row(
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
