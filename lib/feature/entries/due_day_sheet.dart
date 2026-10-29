import 'package:flutter/material.dart';

import '../../domain/model/expense_template.dart';
import '../../core/widget/keep_all.dart';

/// 예정일 이름. 31일은 '말일'이다. 예: '25일', '말일'
String dueDayLabel(int dueDay) => dueDay == lastDueDay ? '말일' : '$dueDay일';

/// 고정 지출의 매달 예정일 칸. 누르면 날짜를 고르는 시트([showDueDaySheet])가 뜬다.
///
/// 칸 전체가 하나의 버튼이라 이름표와 고른 값을 함께 읽게 직접 알린다.
class DueDayField extends StatelessWidget {
  const DueDayField({
    required this.dueDay,
    required this.errorText,
    required this.onTap,
    super.key,
  });

  final int? dueDay;
  final String? errorText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dueDay = this.dueDay;
    final text = dueDay == null ? null : '매월 ${dueDayLabel(dueDay)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        ExcludeSemantics(
          child: Text('매달 예정일', style: theme.textTheme.labelMedium),
        ),
        Semantics(
          container: true,
          button: true,
          label: '매달 예정일',
          value: text ?? '고르지 않음',
          child: InkWell(
            key: const Key('entry-due-day'),
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: InputDecorator(
              isEmpty: text == null,
              decoration: InputDecoration(
                hintText: '매달 빠져나가는 날을 골라 주세요',
                errorText: errorText,
                enabled: onTap != null,
                suffixIcon: const ExcludeSemantics(
                  child: Icon(Icons.keyboard_arrow_down, size: 22),
                ),
              ),
              child: ExcludeSemantics(
                child: Text(text ?? '', style: theme.textTheme.bodyLarge),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 매달 예정일을 고르는 시트를 띄우고 고른 날을 돌려준다. 고르지 않고 닫으면 null.
Future<int?> showDueDaySheet(BuildContext context, {required int? selected}) =>
    showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (_) => _DueDaySheet(selected: selected),
    );

/// 매달 예정일을 고르는 시트. 1~30일과 말일을 한 주 7칸씩 놓는다. 고른 날을 돌려주며 닫힌다.
class _DueDaySheet extends StatelessWidget {
  const _DueDaySheet({required this.selected});

  final int? selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            Semantics(
              header: true,
              child: Text('매달 예정일', style: theme.textTheme.titleMedium),
            ),
            Text(
              keepAll('그달에 없는 날(2월 30일 같은)은 그달 말일로 만들어져요.'),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: 48,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: lastDueDay,
              itemBuilder: (context, index) {
                final day = index + 1;
                return _DayButton(
                  key: Key('due-day-$day'),
                  label: day == lastDueDay ? dueDayLabel(day) : '$day',
                  selected: day == selected,
                  onTap: () => Navigator.of(context).pop(day),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 예정일 시트의 날짜 한 칸. 고른 날은 채워서 보여주고 화면 읽기 도구에 고른 상태를 알린다.
class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const radius = BorderRadius.all(Radius.circular(12));
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? scheme.primary : scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: selected ? scheme.primary : scheme.outline),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? scheme.onPrimary : scheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
