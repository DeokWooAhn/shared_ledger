import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/model/ledger_entries.dart';
import '../../core/model/member.dart';
import '../../core/model/month_ledger.dart';
import '../../core/model/payment_method.dart';
import '../../core/model/year_month.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widget/back_circle_button.dart';
import '../../core/widget/keep_all.dart';
import '../../core/widget/month_header.dart';
import '../../core/widget/month_picker_sheet.dart';
import '../../core/widget/won.dart';
import 'calendar_days.dart';
import 'entries_controller.dart';
import 'entry_form_controller.dart';
import 'entry_row.dart';
import 'korean_holidays.dart';

/// 화면 폭이 이 폭 이상이면 달력과 고른 날 목록을 두 칸으로 놓는다.
const calendarTwoColumnMinWidth = 720.0;

/// 6주인 달의 한 주 높이. 날짜 판은 늘 6주 높이라 주가 적은 달은 한 주가 그만큼 높아진다.
/// (삼성 캘린더처럼 판 높이가 달마다 같아서 밀 때 아래 칸이 들썩이지 않는다.)
const calendarWeekMinHeight = 68.0;

// 날짜 판의 쪽 번호. 0년 1월부터 센 달 수다.
int _pageOf(YearMonth month) => month.year * 12 + month.month - 1;

YearMonth _monthOfPage(int page) => YearMonth(page ~/ 12, page % 12 + 1);

const _weekdayNames = ['일', '월', '화', '수', '목', '금', '토'];

/// [date]의 요일 이름. 예: '일'
String weekdayName(DateTime date) => _weekdayNames[date.weekday % 7];

/// 고른 날의 제목. 예: '10월 18일 일요일'
String calendarDayTitle(DateTime date) =>
    '${date.month}월 ${date.day}일 ${weekdayName(date)}요일';

/// 달력 화면(design/app/08). 보고 있는 달의 항목을 날짜별로 보여주고, 고른 날의 항목을 아래(넓으면 옆)에 둔다.
///
/// 날짜 판은 손가락을 따라 밀리고 옆 달이 붙어 들어온다. 반 넘게 밀거나 빠르게 튕기면 그 달에 멈추고, 멈춘 달을 본다.
/// 항목을 누르면 고치는 화면, 항목이 없는 날은 빈 칸 안내를 누르면 그날로 새 항목(추가지출)을 연다.
/// 달을 옮기면 요약·항목 탭의 달도 같이 옮긴다. 공휴일은 일요일처럼 빨간색이다. 왼쪽 위 뒤로 단추로 닫는다.
/// 저장소를 부르는 동작이 없어 컨트롤러 없이 공급자만 읽고, 고른 날과 판 위치는 이 화면에서만 쓰는 상태라 위젯에 둔다.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({required this.openForm, super.key});

  final OpenEntryForm openForm;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  // 고른 날. 보는 달 밖이면(달을 옮긴 뒤) 쓰지 않고 그달의 처음 날을 고른다.
  DateTime? _picked;

  late final _pages = PageController(
    initialPage: _pageOf(ref.read(selectedMonthProvider)),
  );

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  DateTime get _today {
    final now = ref.read(clockProvider)();
    return DateTime(now.year, now.month, now.day);
  }

  // 이번 달이면 오늘, 다른 달이면 1일이 처음 고른 날이다.
  DateTime _selectedDay(YearMonth month) {
    final picked = _picked;
    if (picked != null && YearMonth.of(picked) == month) return picked;
    final today = _today;
    return YearMonth.of(today) == month
        ? today
        : DateTime(month.year, month.month);
  }

  void _pick(DateTime day) => setState(() => _picked = day);

  void _goToday() {
    final today = _today;
    ref.read(selectedMonthProvider.notifier).select(YearMonth.of(today));
    _pick(today);
  }

  Future<void> _pickMonth() async {
    // 시트가 떠 있는 동안 이 화면이 닫힐 수 있어서, 기다리기 전에 공급자를 잡아 둔다(앱 내내 살아 있음).
    final selectedMonth = ref.read(selectedMonthProvider.notifier);
    final picked = await showMonthPicker(
      context,
      selected: ref.read(selectedMonthProvider),
      current: YearMonth.of(_today),
    );
    if (picked != null) selectedMonth.select(picked);
  }

  // 판을 밀어 다른 달에 멈추면 그 달을 본다. 미는 도중에는 달을 바꾸지 않는다.
  bool _settled(ScrollEndNotification notification) {
    final page = _pages.page?.round();
    if (notification.depth != 0 || page == null) return false;
    final month = _monthOfPage(page);
    if (month != ref.read(selectedMonthProvider)) {
      ref.read(selectedMonthProvider.notifier).select(month);
    }
    return false;
  }

  // 달 이름·오늘·연월 고르기로 달이 바뀌면 판도 그 달로 넘긴다. 바로 옆 달이면 넘기는 모습을 보이고, 먼 달은 바로 간다.
  void _showMonth(YearMonth month) {
    final current = _pages.hasClients ? _pages.page?.round() : null;
    final target = _pageOf(month);
    if (current == null || current == target) return;
    if ((target - current).abs() == 1 &&
        !MediaQuery.disableAnimationsOf(context)) {
      unawaited(
        _pages.animateToPage(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        ),
      );
    } else {
      _pages.jumpToPage(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(selectedMonthProvider);
    ref.listen(selectedMonthProvider, (_, month) => _showMonth(month));
    ref.listen(entriesControllerProvider.select((s) => s.failure), (
      _,
      failure,
    ) {
      if (failure == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(keepAll(entriesFailureMessage(failure)))),
      );
      ref.read(entriesControllerProvider.notifier).failureShown();
    });
    final ledger = ref.watch(monthLedgerProvider);
    final paymentMethods = ref.watch(paymentMethodsProvider);
    final selectedMonth = ref.read(selectedMonthProvider.notifier);
    // 새 달 항목을 받는 동안에는 고른 날 목록 자리에 불러오는 중을 둔다. 판의 앞뒤 달은 미리 받아 두어서 보통은 바로 온다.
    // (이전 달 값은 쓰지 않는다. AsyncData일 때만 새 달 값이다.)
    final loaded = switch ((ledger, paymentMethods)) {
      (AsyncData(value: final ledger), AsyncData(value: final methods)) => (
        ledger,
        methods,
      ),
      _ => null,
    };
    final calendar = CalendarMonth.of(loaded?.$1 ?? const MonthLedger(), month);
    final selected = _selectedDay(month);
    final Widget body = ledger.hasError || paymentMethods.hasError
        ? const _CalendarFailed()
        : _CalendarBody(
            grid: _CalendarCard(
              pages: _pages,
              onSettled: _settled,
              undated: calendar.undatedCount,
              page: (month) => _MonthGrid(
                month: month,
                selected: _selectedDay(month),
                today: _today,
                onPick: _pick,
              ),
            ),
            panel: loaded == null
                ? const _CalendarLoading()
                : _DayPanel(
                    key: ValueKey('calendar-panel-${selected.day}'),
                    day: calendar.dayOf(selected.day),
                    month: month,
                    methods: {
                      for (final method in loaded.$2) method.id: method,
                    },
                    openForm: widget.openForm,
                  ),
          );
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _CalendarTopBar(
              month: month,
              current: YearMonth.of(_today),
              onPrevious: selectedMonth.previous,
              onNext: selectedMonth.next,
              onPickMonth: _pickMonth,
              onToday: _goToday,
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// 뒤로, 달 이름(밀어서 달 옮기기, 누르면 연·월 고르기), 오늘. 달 이름은 가운데에 둔다.
class _CalendarTopBar extends StatelessWidget {
  const _CalendarTopBar({
    required this.month,
    required this.current,
    required this.onPrevious,
    required this.onNext,
    required this.onPickMonth,
    required this.onToday,
  });

  final YearMonth month;
  final YearMonth current;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPickMonth;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // 양옆을 같은 폭으로 둬서 달 이름을 가운데에 둔다.
    const sideWidth = 64.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          SizedBox(
            width: sideWidth,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: BackCircleButton(
                key: const Key('calendar-back'),
                background: scheme.surfaceContainerLowest,
              ),
            ),
          ),
          Expanded(
            child: MonthSwipeTitle(
              month: month,
              label: monthLabel(month, current: current),
              onNext: onNext,
              onPrevious: onPrevious,
              onTap: onPickMonth,
              tapHint: '연·월 고르기',
              titleKey: const Key('calendar-month-title'),
              tapKey: const Key('calendar-month'),
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 19),
            ),
          ),
          SizedBox(
            width: sideWidth,
            child: TextButton(
              key: const Key('calendar-today'),
              style: TextButton.styleFrom(
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: const StadiumBorder(),
              ),
              onPressed: onToday,
              // 글자를 키워도 '오/늘'로 줄이 갈리지 않게, 폭이 모자라면 줄여서 한 줄로 둔다.
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('오늘', maxLines: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 달력과 고른 날 목록. 넓으면 두 칸, 좁으면 위아래로 놓는다.
class _CalendarBody extends StatelessWidget {
  const _CalendarBody({required this.grid, required this.panel});

  final Widget grid;

  /// 고른 날 목록. 그달 항목을 아직 받지 못했으면 불러오는 중이다.
  final Widget panel;

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.fromLTRB(16, 0, 16, 24);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= calendarTwoColumnMinWidth) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: ListView(padding: padding, children: [grid]),
                  ),
                  Expanded(
                    flex: 2,
                    child: ListView(padding: padding, children: [panel]),
                  ),
                ],
              ),
            ),
          );
        }
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: padding,
              children: [grid, const SizedBox(height: 14), panel],
            ),
          ),
        );
      },
    );
  }
}

/// 요일 머리, 좌우로 넘기는 날짜 판, 범례, 날짜 없는 항목 안내. 요일 머리와 범례는 판을 밀어도 그대로 있다.
class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.pages,
    required this.onSettled,
    required this.undated,
    required this.page,
  });

  final PageController pages;

  /// 판이 멈췄을 때. 멈춘 달을 보게 한다.
  final NotificationListenerCallback<ScrollEndNotification> onSettled;

  /// 보고 있는 달의 날짜 없는 항목 수.
  final int undated;

  /// 한 달의 날짜 판.
  final Widget Function(YearMonth month) page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                child: Row(
                  children: [
                    for (final (index, name) in _weekdayNames.indexed)
                      Expanded(
                        child: Text(
                          name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _weekdayColor(context, index),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // 판은 카드 폭 끝까지 밀리고, 날짜 칸의 여백은 쪽마다 둔다.
            SizedBox(
              height: calendarWeekMinHeight * 6,
              child: NotificationListener<ScrollEndNotification>(
                onNotification: onSettled,
                // 앞뒤 달 쪽을 미리 만들어 두어(그달 항목 구독도 같이) 미는 동안 옆 달 금액이 바로 보인다.
                child: PageView.builder(
                  key: const Key('calendar-swipe'),
                  controller: pages,
                  allowImplicitScrolling: true,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: page(_monthOfPage(index)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const _Legend(),
            if (undated > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  keepAll('날짜 없는 항목 $undated건은 항목 탭에서 볼 수 있어요.'),
                  key: const Key('calendar-undated'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 한 달의 날짜 칸. 쪽마다 그달 항목을 따로 읽어서, 판을 미는 동안 옆 달도 금액이 보인다.
/// 그달 항목을 아직 받지 못했으면 날짜만 그린다.
class _MonthGrid extends ConsumerWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.today,
    required this.onPick,
  });

  final YearMonth month;
  final DateTime selected;
  final DateTime today;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger =
        ref.watch(monthLedgerOfProvider(month)).value ?? const MonthLedger();
    final calendar = CalendarMonth.of(ledger, month);
    // 일요일이 첫 칸이다. DateTime.weekday는 월요일이 1, 일요일이 7이다.
    final leading = DateTime(month.year, month.month).weekday % 7;
    final weeks = (leading + calendar.length + 6) ~/ 7;
    final isSelectedMonth = YearMonth.of(selected) == month;
    final isTodayMonth = YearMonth.of(today) == month;
    return Column(
      children: [
        for (var week = 0; week < weeks; week++)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var column = 0; column < 7; column++)
                  Expanded(
                    child: switch (week * 7 + column - leading + 1) {
                      final day when day >= 1 && day <= calendar.length =>
                        _DayCell(
                          key: ValueKey('calendar-day-$day'),
                          day: calendar.dayOf(day),
                          selected: isSelectedMonth && selected.day == day,
                          today: isTodayMonth && today.day == day,
                          onTap: () => onPick(calendar.dayOf(day).date),
                        ),
                      _ => const SizedBox.shrink(),
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

// 요일 머리의 색. 일요일은 빨강, 토요일은 파랑, 나머지는 [fallback](없으면 흐린 글자).
Color _weekdayColor(BuildContext context, int index, {Color? fallback}) =>
    switch (index) {
      0 => Theme.of(context).colorScheme.error,
      6 => context.appColors.accentText,
      _ => fallback ?? context.appColors.textMuted,
    };

/// 날짜 한 칸: 날짜 숫자, 들어온 돈·나간 돈, 예정 표시. 공휴일은 일요일처럼 빨간 숫자다.
///
/// 칸은 주 높이를 다 채우고, 내용이 칸보다 크면(6주인 달에 금액·예정이 다 있는 날) 통째로 줄여 다 보여준다.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.today,
    required this.onTap,
    super.key,
  });

  final CalendarDay day;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final date = day.date;
    final holiday = koreanHoliday(date);
    final numberColor = selected
        ? scheme.onPrimary
        : today
        ? colors.accentText
        : holiday != null
        ? scheme.error
        : _weekdayColor(context, date.weekday % 7, fallback: scheme.onSurface);
    Widget amount(String text, Color color, FontWeight weight) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(fontSize: 10, fontWeight: weight, color: color),
      ),
    );
    final label = [
      '${date.month}월 ${date.day}일 ${weekdayName(date)}요일',
      ?holiday,
      if (today) '오늘',
      if (day.income > 0) '들어온 돈 ${won(day.income)}',
      if (day.spending > 0) '나간 돈 ${won(day.spending)}',
      if (day.scheduled.isNotEmpty) '예정 ${day.scheduled.length}건',
    ].join(', ');
    // 칸 안의 숫자·금액 대신 한 문장으로 읽는다. excludeSemantics가 InkWell의 누르기 동작도 숨기므로
    // 누르기는 Semantics.onTap으로 다시 단다.
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        excludeFromSemantics: true,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
          child: LayoutBuilder(
            builder: (context, constraints) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: constraints.maxWidth,
                child: Column(
                  spacing: 2,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? scheme.primary : null,
                        border: today && !selected
                            ? Border.all(color: scheme.primary, width: 1.5)
                            : null,
                      ),
                      child: Text(
                        '${date.day}',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: selected || today
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: numberColor,
                        ),
                      ),
                    ),
                    if (day.income > 0)
                      amount(
                        calendarAmount(day.income),
                        colors.income,
                        FontWeight.w600,
                      ),
                    if (day.spending > 0)
                      amount(
                        calendarAmount(-day.spending),
                        scheme.onSurfaceVariant,
                        FontWeight.w500,
                      ),
                    if (day.scheduled.isNotEmpty) const _PlanTag(),
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

/// 지급 전 기본 월 지출의 예정일 표시. 테두리만 있는 작은 '예정'.
class _PlanTag extends StatelessWidget {
  const _PlanTag();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.textMuted),
      ),
      child: Text(
        '예정',
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 칸에 쓰는 색의 뜻. 글자로도 적어서 색만으로 구분하지 않는다.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final style = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);
    Widget item(String label, BoxDecoration dot) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 5,
      children: [
        Container(width: 7, height: 7, decoration: dot),
        Text(label, style: style),
      ],
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 4,
      children: [
        item(
          '들어온 돈',
          BoxDecoration(shape: BoxShape.circle, color: colors.income),
        ),
        item(
          '나간 돈',
          BoxDecoration(shape: BoxShape.circle, color: scheme.onSurfaceVariant),
        ),
        item(
          '예정',
          BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colors.textMuted, width: 1.5),
          ),
        ),
      ],
    );
  }
}

/// 고른 날의 항목 목록. 항목이 없는 날은 안내 전체가 그날로 항목을 추가하는 단추다.
class _DayPanel extends ConsumerWidget {
  const _DayPanel({
    required this.day,
    required this.month,
    required this.methods,
    required this.openForm,
    super.key,
  });

  final CalendarDay day;
  final YearMonth month;
  final Map<String, PaymentMethod> methods;
  final OpenEntryForm openForm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;
    final members = ref.watch(membersProvider).value ?? const [];
    final canWrite = ref.watch(myRoleProvider)?.canWrite ?? false;
    final date = day.date;
    final holiday = koreanHoliday(date);
    final rows = <LedgerEntry>[...day.entries, ...day.scheduled];
    final counts = [
      if (day.entries.isNotEmpty) '항목 ${day.entries.length}건',
      if (day.scheduled.isNotEmpty) '예정 ${day.scheduled.length}건',
    ].join(' · ');
    final String? total;
    if (day.entries.isNotEmpty) {
      total = day.net > 0 ? '+${won(day.net)}' : won(day.net);
    } else if (day.scheduled.isNotEmpty) {
      total = '${won(-day.scheduledTotal)} 예정';
    } else {
      total = null;
    }
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: scheme.outlineVariant,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              spacing: 8,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          calendarDayTitle(date),
                          key: const Key('calendar-day-title'),
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (holiday != null || counts.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          children: [
                            if (holiday != null)
                              Text(
                                holiday,
                                key: const Key('calendar-day-holiday'),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.error,
                                ),
                              ),
                            if (counts.isNotEmpty)
                              Text(
                                counts,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.textMuted,
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (total != null)
                  Text(
                    total,
                    key: const Key('calendar-day-total'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      color: day.entries.isEmpty ? colors.textMuted : null,
                    ),
                  ),
              ],
            ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _EmptyDay(
                  onAdd: canWrite
                      ? () => unawaited(
                          openForm(
                            context,
                            EntryFormArgs.add(
                              kind: EntryKind.extra,
                              month: month,
                              date: date,
                            ),
                          ),
                        )
                      : null,
                ),
              )
            else
              for (final (index, entry) in rows.indexed) ...[
                if (index > 0) divider,
                EntryRow(
                  key: ValueKey('calendar-entry-${entry.id}'),
                  entry: entry,
                  member: memberIn(members, entryMemberSlot(entry.memberId)),
                  methods: methods,
                  showKind: true,
                  onTap: canWrite
                      ? () => editEntryWithUndo(context, openForm, entry, month)
                      : null,
                ),
              ],
            if (canWrite && day.scheduled.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  keepAll('예정 항목을 누르면 지급 완료로 바꿀 수 있어요.'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 항목이 없는 날의 안내. 적을 수 있으면 안내 전체가 그날로 새 항목(추가지출)을 여는 단추다.
class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.onAdd});

  /// null이면 누를 수 없다(보기 전용).
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: onAdd != null,
      hint: onAdd == null ? null : '이 날로 항목 추가',
      child: InkWell(
        key: const Key('calendar-day-empty'),
        onTap: onAdd,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            spacing: 10,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: scheme.primaryContainer,
                child: Icon(
                  Icons.edit_calendar_outlined,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              Text(
                keepAll('이 날 적은 항목이 없어요'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarLoading extends StatelessWidget {
  const _CalendarLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: Key('calendar-loading'),
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _CalendarFailed extends StatelessWidget {
  const _CalendarFailed();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        key: const Key('calendar-failed'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: Text(
            keepAll('이 달 항목을 불러오지 못했어요. 잠시 후 다시 열어 주세요.'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ),
    );
  }
}
