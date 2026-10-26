import 'dart:math';

import 'package:flutter/material.dart';

import '../model/year_month.dart';
import '../theme/app_theme.dart';

/// 달 고르기 시트의 최대 폭. 넓은 화면에서도 휠이 너무 벌어지지 않게 한다.
const monthPickerMaxWidth = 480.0;

/// 휠 한 칸의 높이. 고른 칸과 위아래 한 칸씩, 세 칸이 보인다.
const monthPickerItemExtent = 64.0;

/// 달 고르기 시트를 열고 고른 달을 돌려준다. 취소하거나 고르지 않고 닫으면 null.
///
/// [selected]는 지금 보고 있는 달, [current]는 이번 달이다. 연도는 둘 중 이른 해 10년 전부터 늦은 해 10년 뒤까지 고른다.
Future<YearMonth?> showMonthPicker(
  BuildContext context, {
  required YearMonth selected,
  required YearMonth current,
}) => showModalBottomSheet<YearMonth>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: monthPickerMaxWidth),
  builder: (_) => MonthPickerSheet(selected: selected, current: current),
);

/// 연·월 휠을 굴려 고르고 '완료'로 돌려준다. 맨 위에는 지금 휠이 가리키는 달을 보여준다.
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
  late final List<int> _years = [
    for (
      var year = min(widget.selected.year, widget.current.year) - 10;
      year <= max(widget.selected.year, widget.current.year) + 10;
      year++
    )
      year,
  ];
  late int _year = widget.selected.year;
  late int _month = widget.selected.month;
  late final _yearWheel = FixedExtentScrollController(
    initialItem: _years.indexOf(_year),
  );
  late final _monthWheel = FixedExtentScrollController(initialItem: _month - 1);

  @override
  void dispose() {
    _yearWheel.dispose();
    _monthWheel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final actionStyle = TextButton.styleFrom(
      foregroundColor: scheme.onSurface,
      minimumSize: const Size.fromHeight(52),
      textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              liveRegion: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 4,
                children: [
                  Text(
                    '$_year년 $_month월',
                    key: const Key('month-picker-title'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 19,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  ExcludeSemantics(
                    child: Icon(
                      Icons.arrow_drop_up,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: monthPickerItemExtent * 3,
              child: Row(
                children: [
                  Expanded(
                    child: _Wheel(
                      key: const Key('month-picker-years'),
                      name: '연도',
                      labels: [for (final year in _years) '$year년'],
                      selected: _years.indexOf(_year),
                      controller: _yearWheel,
                      onChanged: (index) =>
                          setState(() => _year = _years[index]),
                    ),
                  ),
                  Expanded(
                    child: _Wheel(
                      key: const Key('month-picker-months'),
                      name: '월',
                      labels: [for (var m = 1; m <= 12; m++) '$m월'],
                      selected: _month - 1,
                      controller: _monthWheel,
                      onChanged: (index) => setState(() => _month = index + 1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    key: const Key('month-picker-cancel'),
                    style: actionStyle,
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('취소'),
                  ),
                ),
                Container(width: 1, height: 20, color: scheme.outline),
                Expanded(
                  child: TextButton(
                    key: const Key('month-picker-done'),
                    style: actionStyle,
                    onPressed: () =>
                        Navigator.of(context).pop(YearMonth(_year, _month)),
                    child: const Text('완료'),
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

/// 굴려서 고르는 휠 하나. 고른 칸은 크고 진하게, 나머지는 흐리게 보인다.
///
/// 화면 읽기 도구에는 '연도 2026년'처럼 한 값으로 읽히고, 조절(위·아래로 쓸기)로 한 칸씩 옮긴다.
class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.name,
    required this.labels,
    required this.selected,
    required this.controller,
    required this.onChanged,
    super.key,
  });

  final String name;
  final List<String> labels;
  final int selected;
  final FixedExtentScrollController controller;
  final ValueChanged<int> onChanged;

  void _moveTo(int index) => controller.animateToItem(
    index,
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = context.appColors.textMuted;
    return Semantics(
      container: true,
      label: name,
      value: labels[selected],
      increasedValue: selected + 1 < labels.length
          ? labels[selected + 1]
          : null,
      decreasedValue: selected > 0 ? labels[selected - 1] : null,
      onIncrease: selected + 1 < labels.length
          ? () => _moveTo(selected + 1)
          : null,
      onDecrease: selected > 0 ? () => _moveTo(selected - 1) : null,
      child: ExcludeSemantics(
        child: ListWheelScrollView.useDelegate(
          controller: controller,
          itemExtent: monthPickerItemExtent,
          diameterRatio: 2.4,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: onChanged,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: labels.length,
            builder: (context, index) => Center(
              child: Text(
                labels[index],
                style: index == selected
                    ? TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      )
                    : TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w400,
                        color: muted,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
