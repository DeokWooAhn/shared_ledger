import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../model/year_month.dart';
import 'member_avatar.dart';

/// 화면에 보이는 달 이름. 예: '2026년 10월'
String yearMonthLabel(YearMonth month) => '${month.year}년 ${month.month}월';

/// 요약·항목 탭 맨 위의 머리말. 보고 있는 달을 앞뒤로 옮기고, 두 사람의 이름표를 보여준다.
/// [openCalendar]를 주면 달 이름을 눌러 달력을 연다.
///
/// 보고 있는 달은 [selectedMonthProvider]라서 두 탭이 같은 달을 본다.
class MonthHeader extends ConsumerWidget {
  const MonthHeader({this.openCalendar, super.key});

  /// 달력을 연다. 화면 이동은 router.dart가 정해서 넘겨준다. null이면 달 이름을 누를 수 없다.
  final void Function(BuildContext context)? openCalendar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final month = ref.watch(selectedMonthProvider);
    final members = ref.watch(membersProvider).value ?? const [];
    final arrowColor = theme.colorScheme.onSurfaceVariant;
    // 달 이름은 남는 폭을 다 쓸 수 있고, 다음 달 화살표는 이름 바로 뒤에 붙는다.
    // (Flexible과 Spacer를 한 줄에 같이 두면 남는 폭을 반씩 나눠 '2026…'처럼 잘린다.)
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              IconButton(
                key: const Key('previous-month'),
                tooltip: '이전 달',
                onPressed: () =>
                    ref.read(selectedMonthProvider.notifier).previous(),
                icon: Icon(Icons.chevron_left, size: 22, color: arrowColor),
              ),
              // 글자를 크게 해도 달 숫자가 잘리지 않게, 폭이 모자라면 줄여서 다 보여준다.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  // 따로 한 덩어리로 둬서 옆 이름표(두 사람 이름)와 합쳐 읽지 않게 한다.
                  child: Semantics(
                    container: true,
                    header: true,
                    liveRegion: true,
                    button: openCalendar != null,
                    hint: openCalendar == null ? null : '달력 열기',
                    child: _Tappable(
                      onTap: switch (openCalendar) {
                        final open? => () => open(context),
                        null => null,
                      },
                      child: Text(
                        yearMonthLabel(month),
                        key: const Key('month-title'),
                        maxLines: 1,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontSize: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                key: const Key('next-month'),
                tooltip: '다음 달',
                onPressed: () =>
                    ref.read(selectedMonthProvider.notifier).next(),
                icon: Icon(Icons.chevron_right, size: 22, color: arrowColor),
              ),
            ],
          ),
        ),
        for (final member in members)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: MemberAvatar(member: member),
          ),
      ],
    );
  }
}

/// 달 이름을 누를 수 있게 감싼다. 누를 곳이 없으면 그대로 둔다.
class _Tappable extends StatelessWidget {
  const _Tappable({required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final onTap = this.onTap;
    if (onTap == null) return child;
    return InkWell(
      key: const Key('open-calendar'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: child,
      ),
    );
  }
}
