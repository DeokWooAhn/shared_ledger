import 'package:flutter/material.dart';

import '../model/year_month.dart';

/// 달 고르기 시트의 최대 폭. 넓은 화면에서도 단추가 너무 벌어지지 않게 한다.
const monthPickerMaxWidth = 480.0;

/// 달 고르기 시트를 열고 고른 달을 돌려준다. 고르지 않고 닫으면 null.
///
/// [selected]는 지금 보고 있는 달, [current]는 이번 달이다. 고를 수 있는 달에 제한은 없다(머리말 화살표와 같다).
Future<YearMonth?> showMonthPicker(
  BuildContext context, {
  required YearMonth selected,
  required YearMonth current,
}) => showModalBottomSheet<YearMonth>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: monthPickerMaxWidth),
  builder: (_) => MonthPickerSheet(selected: selected, current: current),
);

/// 연도를 화살표로 넘기고 1~12월 중 하나를 누르면 그 달을 돌려주며 닫힌다.
///
/// 보고 있는 달은 채워서, 이번 달은 테두리로 표시한다.
class MonthPickerSheet extends StatefulWidget {
  const MonthPickerSheet({
    required this.selected,
    required this.current,
    super.key,
  });

  final YearMonth selected;
  final YearMonth current;

  @override
  State<MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<MonthPickerSheet> {
  late int _year = widget.selected.year;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  key: const Key('month-picker-previous-year'),
                  tooltip: '이전 해',
                  onPressed: () => setState(() => _year--),
                  icon: const Icon(Icons.chevron_left),
                ),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    '$_year년',
                    key: const Key('month-picker-year'),
                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 19),
                  ),
                ),
                IconButton(
                  key: const Key('month-picker-next-year'),
                  tooltip: '다음 해',
                  onPressed: () => setState(() => _year++),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            for (final row in const [
              [1, 2, 3, 4],
              [5, 6, 7, 8],
              [9, 10, 11, 12],
            ])
              Row(
                spacing: 8,
                children: [
                  for (final month in row)
                    Expanded(
                      child: _MonthButton(
                        month: YearMonth(_year, month),
                        selected: widget.selected == YearMonth(_year, month),
                        current: widget.current == YearMonth(_year, month),
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

class _MonthButton extends StatelessWidget {
  const _MonthButton({
    required this.month,
    required this.selected,
    required this.current,
  });

  final YearMonth month;
  final bool selected;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = '${month.month}월';
    final style = OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      padding: EdgeInsets.zero,
      backgroundColor: selected ? scheme.primary : null,
      foregroundColor: selected ? scheme.onPrimary : scheme.onSurface,
      side: BorderSide(
        color: selected || current ? scheme.primary : scheme.outline,
        width: current && !selected ? 1.5 : 1,
      ),
    );
    // 단추가 글자의 semantics를 합치므로, 읽을 이름과 골라진 상태는 글자 쪽에 단다
    // (단추 밖에서 excludeSemantics로 감싸면 누르기 동작까지 사라진다).
    return OutlinedButton(
      key: Key('month-picker-${month.month}'),
      style: style,
      onPressed: () => Navigator.of(context).pop(month),
      child: Semantics(
        selected: selected,
        label: '${month.year}년 $label${current ? ', 이번 달' : ''}',
        excludeSemantics: true,
        child: Text(label),
      ),
    );
  }
}
