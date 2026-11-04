import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/widget/month_picker_sheet.dart';
import '../../domain/budget/stats_period.dart';
import '../../domain/model/year_month.dart';

/// 조회 기간 시트의 최대 폭. 넓은 화면에서는 이 폭으로 가운데 둔다.
const statsPeriodSheetMaxWidth = 560.0;

/// 기간 고르는 칸의 이름.
String statsRangeLabel(StatsRange range) => switch (range) {
  StatsRange.month1 => '1개월',
  StatsRange.month3 => '3개월',
  StatsRange.month6 => '6개월',
  StatsRange.year1 => '1년',
  StatsRange.custom => '직접',
};

/// 기간을 적은 글. 예: '2026년 11월', '2026년 6월 ~ 11월', '2025년 12월 ~ 2026년 5월'
String statsPeriodLabel(StatsPeriod period) {
  final StatsPeriod(:from, :to) = period;
  if (from == to) return '${from.year}년 ${from.month}월';
  final end = from.year == to.year
      ? '${to.month}월'
      : '${to.year}년 ${to.month}월';
  return '${from.year}년 ${from.month}월 ~ $end';
}

/// 조회 기간 시트를 연다. 통계 머리말의 기간 단추를 누르면 열리고, 탭 막대까지 덮게 앱 맨 위에 띄운다.
Future<void> showStatsPeriodSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: statsPeriodSheetMaxWidth),
      builder: (_) => const StatsPeriodSheet(),
    );

// 직접 고르기에서 휠이 고치는 끝.
enum _PeriodEnd { from, to }

/// 조회 기간(은행 앱처럼): 1개월·3개월·6개월·1년(이번 달로 끝남)과 직접 고르기.
///
/// 직접 고르기는 시작·끝 칸 중 누른 칸을 같은 시트 안의 연·월 휠로 고친다(시트를 겹쳐 띄우지 않는다).
/// 기간은 최대 12개월이라, 넘으면 다른 쪽 끝을 당긴다. '확인'을 눌러야 통계에 들어간다.
class StatsPeriodSheet extends ConsumerStatefulWidget {
  const StatsPeriodSheet({super.key});

  @override
  ConsumerState<StatsPeriodSheet> createState() => _StatsPeriodSheetState();
}

class _StatsPeriodSheetState extends ConsumerState<StatsPeriodSheet> {
  // 고르는 중인 기간. '확인' 전에는 통계에 넣지 않아서 위젯이 갖는다.
  late var _period = ref.read(statsPeriodProvider);
  var _editing = _PeriodEnd.from;

  YearMonth get _thisMonth => YearMonth.of(ref.read(clockProvider)());

  void _choose(StatsRange range) => setState(() {
    _period = range == StatsRange.custom
        ? StatsPeriod.custom(_period.from, _period.to)
        : StatsPeriod.recent(range, _thisMonth);
  });

  void _roll(YearMonth month) => setState(() {
    _period = switch (_editing) {
      _PeriodEnd.from => _period.withFrom(month),
      _PeriodEnd.to => _period.withTo(month),
    };
  });

  void _done() {
    ref.read(statsPeriodProvider.notifier).select(_period);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final custom = _period.range == StatsRange.custom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text('조회 기간', style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: 16),
            SegmentedButton<StatsRange>(
              key: const Key('stats-range'),
              showSelectedIcon: false,
              segments: [
                for (final range in StatsRange.values)
                  ButtonSegment(
                    value: range,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        statsRangeLabel(range),
                        key: ValueKey('stats-range-${range.name}'),
                        maxLines: 1,
                      ),
                    ),
                  ),
              ],
              selected: {_period.range},
              onSelectionChanged: (selected) => _choose(selected.first),
            ),
            const SizedBox(height: 16),
            if (custom) ...[
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: _EndField(
                      key: const Key('stats-from'),
                      label: '시작',
                      month: _period.from,
                      editing: _editing == _PeriodEnd.from,
                      onTap: () => setState(() => _editing = _PeriodEnd.from),
                    ),
                  ),
                  Text('~', style: theme.textTheme.bodyMedium),
                  Expanded(
                    child: _EndField(
                      key: const Key('stats-to'),
                      label: '끝',
                      month: _period.to,
                      editing: _editing == _PeriodEnd.to,
                      onTap: () => setState(() => _editing = _PeriodEnd.to),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 누른 칸이 바뀌면 그 칸의 달로 휠을 새로 만든다.
              MonthWheels(
                key: ValueKey(_editing),
                initial: switch (_editing) {
                  _PeriodEnd.from => _period.from,
                  _PeriodEnd.to => _period.to,
                },
                current: _thisMonth,
                onChanged: _roll,
              ),
            ] else
              Text(
                statsPeriodLabel(_period),
                key: const Key('stats-sheet-period'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('stats-period-done'),
              onPressed: _done,
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 직접 고르기의 시작·끝 칸. 누르면 휠이 이 칸을 고친다.
class _EndField extends StatelessWidget {
  const _EndField({
    required this.label,
    required this.month,
    required this.editing,
    required this.onTap,
    super.key,
  });

  final String label;
  final YearMonth month;
  final bool editing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: editing ? scheme.primary : scheme.outline,
        width: editing ? 2 : 1,
      ),
    );
    return Semantics(
      selected: editing,
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: Ink(
            decoration: ShapeDecoration(shape: shape),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: theme.textTheme.labelSmall),
                    Text(
                      '${month.year}.${'${month.month}'.padLeft(2, '0')}',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
