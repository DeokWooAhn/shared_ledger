import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../../domain/model/year_month.dart';

/// 연도까지 붙인 달 이름. 예: '2026년 10월'
String yearMonthLabel(YearMonth month) => '${month.year}년 ${month.month}월';

/// 화면에 보이는 달 이름. 올해면 달만, 다른 해면 연도도 붙인다. 예: '10월', '2025년 10월'
String monthLabel(YearMonth month, {required YearMonth current}) =>
    month.year == current.year ? '${month.month}월' : yearMonthLabel(month);

/// 홈·내역 탭(과 휴지통) 맨 위의 머리말. 달 이름(`11월 ▾`)을 누르면 달 고르기를 열고([openMonths]),
/// 달 이름을 좌우로 밀어 옆 달로 옮긴다. [trailing]은 오른쪽 끝에 둔다(내역 탭의 달력 단추).
///
/// 보고 있는 달은 [selectedMonthProvider]라서 탭들이 같은 달을 본다. 옮기는 달은 [ledgerMonthsProvider]의 달(추가한 달)이라
/// 사이의 빈 달은 건너뛰고, 끝 달에서는 그쪽으로 밀어도 옮기지 않는다.
class MonthHeader extends ConsumerWidget {
  const MonthHeader({this.openMonths, this.trailing, super.key});

  /// 달 고르기를 연다. 화면 이동은 router.dart가 정해서 넘겨준다. null이면 달 이름을 누를 수 없다.
  final void Function(BuildContext context)? openMonths;

  /// 머리말 오른쪽 끝에 둘 단추.
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final month = ref.watch(selectedMonthProvider);
    final current = YearMonth.of(ref.watch(clockProvider)());
    final selectedMonth = ref.read(selectedMonthProvider.notifier);
    // 목록을 아직 모으지 않은 가계부면 바로 앞뒤 달로 간다.
    final months = ref.watch(ledgerMonthsProvider);
    final previous = months == null
        ? month.previous
        : monthBefore(months, month);
    final next = months == null ? month.next : monthAfter(months, month);
    final trailing = this.trailing;
    return Row(
      children: [
        // 달 이름은 남는 폭을 다 쓰고, 그 폭 어디를 밀어도 달을 옮긴다.
        Expanded(
          child: MonthSwipeTitle(
            month: month,
            label: monthLabel(month, current: current),
            onNext: next == null ? null : () => selectedMonth.select(next),
            onPrevious: previous == null
                ? null
                : () => selectedMonth.select(previous),
            onTap: switch (openMonths) {
              final open? => () => open(context),
              null => null,
            },
            tapHint: '달 고르기',
            tapIcon: Icons.keyboard_arrow_down,
            titleKey: const Key('month-title'),
            tapKey: const Key('open-months'),
            alignment: AlignmentDirectional.centerStart,
            style: theme.textTheme.headlineSmall?.copyWith(fontSize: 24),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// 이만큼 빨리(초당 논리 픽셀) 또는 멀리(논리 픽셀) 밀면 달을 옮긴다.
const monthSwipeVelocity = 250.0;
const monthSwipeDistance = 48.0;

/// 좌우로 밀어서 달을 옮기는 달 이름. 왼쪽으로 밀면 다음 달, 오른쪽으로 밀면 이전 달이다.
/// [onNext]·[onPrevious]가 null이면 그쪽으로는 옮기지 않는다(머리말의 끝 달).
///
/// 달이 바뀌면 이름이 민 방향으로 미끄러진다. 화면 읽기 도구에서는 조절(위·아래로 쓸기)로 달을 옮기고,
/// [onTap]이 있으면 눌러서 그 동작([tapHint])을 한다. [tapIcon]이 있으면 달 이름 뒤에 붙여 누를 수 있다는 걸 보여준다.
/// 머리말과 달력이 같이 쓴다.
class MonthSwipeTitle extends StatefulWidget {
  const MonthSwipeTitle({
    required this.month,
    required this.label,
    required this.onNext,
    required this.onPrevious,
    this.onTap,
    this.tapHint,
    this.tapIcon,
    this.titleKey,
    this.tapKey,
    this.alignment = AlignmentDirectional.center,
    this.style,
    super.key,
  });

  final YearMonth month;
  final String label;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onTap;
  final String? tapHint;
  final IconData? tapIcon;

  /// 테스트에서 달 이름 글자와 누르는 곳을 찾을 키.
  final Key? titleKey;
  final Key? tapKey;
  final AlignmentDirectional alignment;
  final TextStyle? style;

  @override
  State<MonthSwipeTitle> createState() => _MonthSwipeTitleState();
}

class _MonthSwipeTitleState extends State<MonthSwipeTitle> {
  double _dragged = 0;

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -monthSwipeVelocity || _dragged < -monthSwipeDistance) {
      widget.onNext?.call();
    } else if (velocity > monthSwipeVelocity || _dragged > monthSwipeDistance) {
      widget.onPrevious?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    final tapIcon = widget.tapIcon;
    // 달 이름만 미끄러지고, 붙인 아이콘은 제자리에 있다.
    Widget title = MonthSlide(
      month: widget.month,
      alignment: widget.alignment,
      child: Text(
        widget.label,
        key: widget.titleKey,
        maxLines: 1,
        style: widget.style,
      ),
    );
    if (onTap != null && tapIcon != null) {
      title = Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: [
          title,
          Icon(
            tapIcon,
            size: 26,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      );
    }
    if (onTap != null) {
      title = InkWell(
        key: widget.tapKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          // 누르는 곳이 높이 48 이상이 되게 위아래 여백을 둔다.
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: title,
        ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _dragged = 0,
      onHorizontalDragUpdate: (details) => _dragged += details.delta.dx,
      onHorizontalDragEnd: _onDragEnd,
      // 남는 폭을 꼭 채워야 할 때(Expanded)만 넓어지고, 아니면 달 이름 폭만큼만 차지한다.
      child: Align(
        alignment: widget.alignment,
        widthFactor: 1,
        // 따로 한 덩어리로 둬서 옆 단추와 합쳐 읽지 않게 한다.
        child: Semantics(
          container: true,
          header: true,
          liveRegion: true,
          button: onTap != null,
          hint: onTap == null ? null : widget.tapHint,
          onIncrease: widget.onNext,
          onDecrease: widget.onPrevious,
          // 글자를 크게 해도 달 이름이 잘리지 않게, 폭이 모자라면 줄여서 다 보여준다.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: widget.alignment,
            child: title,
          ),
        ),
      ),
    );
  }
}

/// 달이 바뀌면 [child]를 미끄러지게 바꾼다. 다음 달이면 오른쪽에서, 이전 달이면 왼쪽에서 들어온다.
///
/// 움직임 줄이기를 켠 기기에서는 바로 바꾼다. 나가는 쪽은 화면 읽기 도구가 읽지 않는다.
class MonthSlide extends StatefulWidget {
  const MonthSlide({
    required this.month,
    required this.child,
    this.alignment = AlignmentDirectional.center,
    super.key,
  });

  final YearMonth month;
  final Widget child;
  final AlignmentDirectional alignment;

  @override
  State<MonthSlide> createState() => _MonthSlideState();
}

class _MonthSlideState extends State<MonthSlide> {
  bool _forward = true;

  @override
  void didUpdateWidget(MonthSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.month != widget.month) {
      _forward = widget.month.compareTo(oldWidget.month) > 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ValueKey(widget.month);
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: widget.alignment,
        children: [...previousChildren, ?currentChild],
      ),
      transitionBuilder: (child, animation) {
        final incoming = child.key == current;
        // 들어오는 쪽은 민 방향 반대편에서, 나가는 쪽은 민 방향으로 움직인다.
        final side = (_forward ? 1.0 : -1.0) * (incoming ? 1 : -1);
        final slid = SlideTransition(
          position: Tween(
            begin: Offset(side * 0.35, 0),
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        );
        return incoming ? slid : ExcludeSemantics(child: slid);
      },
      child: KeyedSubtree(key: current, child: widget.child),
    );
  }
}
