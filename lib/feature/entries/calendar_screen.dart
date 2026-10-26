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
import '../../core/widget/keep_all.dart';
import '../../core/widget/month_header.dart';
import '../../core/widget/month_picker_sheet.dart';
import '../../core/widget/won.dart';
import 'calendar_days.dart';
import 'entries_controller.dart';
import 'entry_form_controller.dart';
import 'entry_row.dart';

/// 화면 폭이 이 폭 이상이면 달력과 고른 날 목록을 두 칸으로 놓는다.
const calendarTwoColumnMinWidth = 720.0;

const _weekdayNames = ['일', '월', '화', '수', '목', '금', '토'];

/// [date]의 요일 이름. 예: '일'
String weekdayName(DateTime date) => _weekdayNames[date.weekday % 7];

/// 고른 날의 제목. 예: '10월 18일 일요일'
String calendarDayTitle(DateTime date) =>
    '${date.month}월 ${date.day}일 ${weekdayName(date)}요일';

/// 달력 화면(design/app/08). 보고 있는 달의 항목을 날짜별로 보여주고, 고른 날의 항목을 아래(넓으면 옆)에 둔다.
///
/// 항목을 누르면 고치는 화면, 아래 단추는 고른 날로 새 항목(추가지출)을 연다. 달을 옮기면 요약·항목 탭의 달도 같이 옮긴다.
/// 저장소를 부르는 동작이 없어 컨트롤러 없이 공급자만 읽고, 고른 날은 이 화면에서만 쓰는 상태라 위젯에 둔다.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({required this.openForm, super.key});

  final OpenEntryForm openForm;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  // 고른 날. 보는 달 밖이면(달을 옮긴 뒤) 쓰지 않고 그달의 처음 날을 고른다.
  DateTime? _picked;

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

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(selectedMonthProvider);
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
    final Widget body;
    if (ledger.hasError || paymentMethods.hasError) {
      body = const _CalendarFailed();
    } else if ((ledger, paymentMethods) case (
      AsyncData(value: final ledger),
      AsyncData(value: final paymentMethods),
    )) {
      body = _CalendarBody(
        month: month,
        ledger: ledger,
        paymentMethods: paymentMethods,
        selected: _selectedDay(month),
        today: _today,
        onPick: _pick,
        openForm: widget.openForm,
      );
    } else {
      body = const _CalendarLoading();
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _CalendarTopBar(
              month: month,
              onPrevious: ref.read(selectedMonthProvider.notifier).previous,
              onNext: ref.read(selectedMonthProvider.notifier).next,
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

/// 닫기, 달 옮기기(달 이름을 누르면 달 고르기), 오늘.
class _CalendarTopBar extends StatelessWidget {
  const _CalendarTopBar({
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.onPickMonth,
    required this.onToday,
  });

  final YearMonth month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPickMonth;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final arrowColor = context.appColors.accentText;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          IconButton(
            key: const Key('calendar-close'),
            tooltip: '닫기',
            style: IconButton.styleFrom(
              backgroundColor: scheme.surfaceContainerLowest,
              fixedSize: const Size(40, 40),
            ),
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.close, size: 20, color: scheme.onSurface),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  key: const Key('calendar-previous-month'),
                  tooltip: '이전 달',
                  onPressed: onPrevious,
                  icon: Icon(Icons.chevron_left, color: arrowColor),
                ),
                // 글자를 크게 해도 잘리지 않게, 폭이 모자라면 줄인다.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Semantics(
                      container: true,
                      header: true,
                      liveRegion: true,
                      button: true,
                      hint: '달 고르기',
                      child: InkWell(
                        key: const Key('calendar-month'),
                        onTap: onPickMonth,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          child: Text(
                            yearMonthLabel(month),
                            maxLines: 1,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 19,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('calendar-next-month'),
                  tooltip: '다음 달',
                  onPressed: onNext,
                  icon: Icon(Icons.chevron_right, color: arrowColor),
                ),
              ],
            ),
          ),
          TextButton(
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
            child: const Text('오늘'),
          ),
        ],
      ),
    );
  }
}

/// 달력과 고른 날 목록. 넓으면 두 칸, 좁으면 위아래로 놓는다.
class _CalendarBody extends ConsumerWidget {
  const _CalendarBody({
    required this.month,
    required this.ledger,
    required this.paymentMethods,
    required this.selected,
    required this.today,
    required this.onPick,
    required this.openForm,
  });

  final YearMonth month;
  final MonthLedger ledger;
  final List<PaymentMethod> paymentMethods;
  final DateTime selected;
  final DateTime today;
  final ValueChanged<DateTime> onPick;
  final OpenEntryForm openForm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendar = CalendarMonth.of(ledger, month);
    final grid = _CalendarCard(
      calendar: calendar,
      selected: selected,
      today: today,
      onPick: onPick,
    );
    final panel = _DayPanel(
      key: ValueKey('calendar-panel-${selected.day}'),
      day: calendar.dayOf(selected.day),
      month: month,
      methods: {for (final method in paymentMethods) method.id: method},
      openForm: openForm,
    );
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

/// 요일 머리, 날짜 칸, 범례, 날짜 없는 항목 안내.
class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.calendar,
    required this.selected,
    required this.today,
    required this.onPick,
  });

  final CalendarMonth calendar;
  final DateTime selected;
  final DateTime today;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final month = calendar.month;
    // 일요일이 첫 칸이다. DateTime.weekday는 월요일이 1, 일요일이 7이다.
    final leading = DateTime(month.year, month.month).weekday % 7;
    final cells = leading + calendar.length;
    final weeks = (cells + 6) ~/ 7;
    final undated = calendar.undatedCount;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: Row(
                children: [
                  for (final (index, name) in _weekdayNames.indexed)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
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
                    ),
                ],
              ),
            ),
            for (var week = 0; week < weeks; week++)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var column = 0; column < 7; column++)
                    Expanded(
                      child: switch (week * 7 + column - leading + 1) {
                        final day when day >= 1 && day <= calendar.length =>
                          _DayCell(
                            key: ValueKey('calendar-day-$day'),
                            day: calendar.dayOf(day),
                            selected: selected.day == day,
                            today:
                                YearMonth.of(today) == month &&
                                today.day == day,
                            onTap: () => onPick(calendar.dayOf(day).date),
                          ),
                        _ => const SizedBox.shrink(),
                      },
                    ),
                ],
              ),
            const SizedBox(height: 8),
            const _Legend(),
            if (undated > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
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

// 일요일은 빨강, 토요일은 파랑, 나머지는 [fallback](없으면 흐린 글자).
Color _weekdayColor(BuildContext context, int index, {Color? fallback}) =>
    switch (index) {
      0 => Theme.of(context).colorScheme.error,
      6 => context.appColors.accentText,
      _ => fallback ?? context.appColors.textMuted,
    };

/// 날짜 한 칸: 날짜 숫자, 들어온 돈·나간 돈, 예정 표시.
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

  String get _semanticsLabel {
    final date = day.date;
    return [
      '${date.month}월 ${date.day}일 ${weekdayName(date)}요일',
      if (today) '오늘',
      if (day.income > 0) '들어온 돈 ${won(day.income)}',
      if (day.spending > 0) '나간 돈 ${won(day.spending)}',
      if (day.scheduled.isNotEmpty) '예정 ${day.scheduled.length}건',
    ].join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final index = day.date.weekday % 7;
    final numberColor = selected
        ? scheme.onPrimary
        : today
        ? colors.accentText
        : _weekdayColor(context, index, fallback: scheme.onSurface);
    Widget amount(String text, Color color, FontWeight weight) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(fontSize: 10, fontWeight: weight, color: color),
      ),
    );
    // 칸 안의 숫자·금액 대신 한 문장으로 읽는다. excludeSemantics가 InkWell의 누르기 동작도 숨기므로
    // 누르기는 Semantics.onTap으로 다시 단다.
    return Semantics(
      label: _semanticsLabel,
      selected: selected,
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        excludeFromSemantics: true,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
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
                    '${day.date.day}',
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

/// 고른 날의 항목 목록과 그날로 항목 추가.
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
                      if (counts.isNotEmpty)
                        Text(
                          counts,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.textMuted,
                          ),
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
                key: const Key('calendar-day-empty'),
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 4),
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
                      ? () => editEntryWithUndo(
                          context,
                          ref,
                          openForm,
                          entry,
                          month,
                        )
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
            if (canWrite)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FilledButton(
                  key: const Key('calendar-add'),
                  onPressed: () => unawaited(
                    openForm(
                      context,
                      EntryFormArgs.add(
                        kind: EntryKind.extra,
                        month: month,
                        date: date,
                      ),
                    ),
                  ),
                  child: Text('${date.month}월 ${date.day}일에 항목 추가'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CalendarLoading extends StatelessWidget {
  const _CalendarLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: Key('calendar-loading'),
      child: CircularProgressIndicator(),
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
