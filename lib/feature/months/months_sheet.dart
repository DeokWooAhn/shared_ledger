import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/widget/keep_all.dart';
import '../../core/widget/month_picker_sheet.dart';
import '../../domain/model/year_month.dart';
import 'months_notifier.dart';

String monthsFailureMessage(MonthsFailure failure) => switch (failure) {
  MonthsFailure.addOffline => '연결되지 않아 새 달을 추가하지 못했어요. 연결된 뒤에 다시 해 주세요.',
  MonthsFailure.add => '새 달을 추가하지 못했어요. 잠시 후 다시 시도해 주세요.',
};

/// 달 고르기 시트의 최대 폭. 넓은 화면에서는 이 폭으로 가운데 둔다.
const monthsSheetMaxWidth = 560.0;

/// 달 고르기 시트를 연다. 머리말의 달 이름을 누르면 열리고, 탭 막대까지 덮게 앱 맨 위에 띄운다.
Future<void> showMonthsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: monthsSheetMaxWidth),
      builder: (_) => const MonthsSheet(),
    );

/// 달 목록·새 달 추가 단계가 같이 쓰는 높이. 단계를 바꿔도 시트 크기와 아래 단추 자리가 그대로다.
/// 새 달 추가의 휠과 단추가 다 보이는 높이이고, 달이 많으면 목록이 이 안에서 스크롤한다.
const monthsSheetStepHeight = 400.0;

/// 달 고르기(예전 가계부 탭, design/app/06). 제목은 '월별 가계부'이고, 추가한 달만 해(年)별로 최근 달부터 보여준다.
///
/// 이번 달이라도 추가하지 않았으면 없다. 달을 누르면 그달로 바꾸고 닫는다. 보던 탭은 그대로다.
/// 관리자·편집자는 '새 달 추가'를 누르면 같은 시트 안에서 연·월 휠 단계로 넘어가 달을 골라 더한다(시트를 겹쳐 띄우지 않는다).
/// 휠 단계에서는 왼쪽 위 뒤로 단추나 뒤로가기로 달 목록으로 돌아간다. 이미 있는 달을 고르면 그달로 간다.
/// 실패는 시트 안에 보여준다(스낵바는 시트 뒤에 가린다). 줄마다 합계는 보이지 않는다(달마다 항목을 읽어야 해서).
/// 달 목록을 아직 모으지 않은 옛 가계부([ledgerMonthsProvider]가 null)는 달을 가리지 않아서, 목록 대신 연·월 휠로 아무 달이나 고른다.
/// 보기 전용은 목록을 모을 수 없어 이 상태로 남는다.
class MonthsSheet extends ConsumerStatefulWidget {
  const MonthsSheet({super.key});

  @override
  ConsumerState<MonthsSheet> createState() => _MonthsSheetState();
}

class _MonthsSheetState extends ConsumerState<MonthsSheet> {
  // 달 추가 단계에서 휠이 가리키는 달. null이면 달 목록 단계다. 화면에서만 쓰는 상태라 위젯이 갖는다.
  YearMonth? _toAdd;

  // 옛 가계부에서 휠이 가리키는 달. 아직 굴리지 않았으면 null이고 보고 있는 달을 연다.
  YearMonth? _anyMonth;

  // 그달로 바꾸고 시트를 닫는다.
  void _open(YearMonth month) {
    ref.read(selectedMonthProvider.notifier).select(month);
    Navigator.of(context).pop();
  }

  // 달 추가 단계로 넘어간다. 이번 달이 없으면 이번 달, 있으면 마지막 달의 다음 달을 먼저 가리킨다.
  void _startAdd(List<YearMonth> months, YearMonth thisMonth) => setState(
    () => _toAdd = months.contains(thisMonth) ? months.last.next : thisMonth,
  );

  void _backToList() => setState(() => _toAdd = null);

  Future<void> _add(YearMonth month) async {
    final months = ref.read(ledgerMonthsProvider) ?? const [];
    final added =
        months.contains(month) ||
        await ref.read(monthsNotifierProvider.notifier).add(month);
    if (!added || !mounted) return;
    _open(month);
  }

  @override
  Widget build(BuildContext context) {
    final months = ref.watch(ledgerMonthsProvider);
    final selected = ref.watch(selectedMonthProvider);
    final thisMonth = YearMonth.of(ref.watch(clockProvider)());
    final toAdd = _toAdd;
    final Widget step;
    if (months == null) {
      step = _PickAnyMonthStep(
        selected: selected,
        current: thisMonth,
        onChanged: (month) => _anyMonth = month,
        onOpen: () => _open(_anyMonth ?? selected),
      );
    } else if (toAdd != null) {
      step = _AddMonthStep(
        month: toAdd,
        exists: months.contains(toAdd),
        current: thisMonth,
        onChanged: (month) => setState(() => _toAdd = month),
        onBack: _backToList,
        onAdd: () => _add(toAdd),
      );
    } else {
      step = _MonthListStep(
        months: months,
        selected: selected,
        thisMonth: thisMonth,
        canWrite: ref.watch(myRoleProvider)?.canWrite ?? false,
        onOpen: _open,
        onAdd: () => _startAdd(months, thisMonth),
      );
    }
    return PopScope(
      // 달 추가 단계에서 뒤로 가면 시트를 닫지 않고 달 목록으로 돌아간다. 아래로 끌어 내리면 시트를 닫는다.
      canPop: toAdd == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToList();
      },
      child: SafeArea(
        child: SizedBox(
          // 가로로 눕힌 휴대폰처럼 낮은 화면에서는 위쪽을 남겨 두고, 단계 안에서 스크롤한다.
          height: min(
            monthsSheetStepHeight,
            MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: step,
        ),
      ),
    );
  }
}

/// 시트의 한 단계. 위에 머리말, 가운데 스크롤되는 내용, 맨 아래 단추를 둔다.
/// 단계마다 높이가 같아서 단계를 바꿔도 아래 단추 자리가 그대로다.
class _SheetStep extends StatelessWidget {
  const _SheetStep({
    required this.header,
    required this.body,
    this.action,
    super.key,
  });

  final Widget header;
  final List<Widget> body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: body,
          ),
        ),
        if (action != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: action,
          )
        else
          const SizedBox(height: 20),
      ],
    );
  }
}

/// 시트의 제목('월별 가계부')과 설명.
class _MonthsTitle extends StatelessWidget {
  const _MonthsTitle({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('월별 가계부', style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: 4),
          Text(keepAll(description), style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// 달 목록 단계. 해별 달 목록과, 쓸 수 있는 사람에게는 맨 아래에 '새 달 추가'를 둔다.
class _MonthListStep extends StatelessWidget {
  const _MonthListStep({
    required this.months,
    required this.selected,
    required this.thisMonth,
    required this.canWrite,
    required this.onOpen,
    required this.onAdd,
  });

  final List<YearMonth> months;
  final YearMonth selected;
  final YearMonth thisMonth;
  final bool canWrite;
  final ValueChanged<YearMonth> onOpen;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final years = <int, List<YearMonth>>{};
    for (final month in months.reversed) {
      years.putIfAbsent(month.year, () => []).add(month);
    }
    return _SheetStep(
      key: const Key('months-sheet'),
      header: const _MonthsTitle(description: '추가한 달만 보여요.'),
      body: [
        if (months.isEmpty)
          const _NoMonths()
        else
          for (final MapEntry(key: year, value: inYear) in years.entries)
            _YearGroup(
              key: ValueKey('year-$year'),
              year: year,
              months: inYear,
              selected: selected,
              thisMonth: thisMonth,
              onOpen: onOpen,
            ),
      ],
      action: canWrite
          ? FilledButton.tonal(
              key: const Key('add-month'),
              onPressed: onAdd,
              child: const Text('새 달 추가'),
            )
          : null,
    );
  }
}

/// 새 달 추가 단계. 달 목록 자리에 연·월 휠을 두고, 고른 달을 더한다. 이미 있는 달이면 그달로 간다.
/// 왼쪽 위 뒤로 단추는 달 목록으로 돌아간다(시트를 닫지 않는다). 추가하지 못하면 단추 바로 위에 알린다.
class _AddMonthStep extends ConsumerWidget {
  const _AddMonthStep({
    required this.month,
    required this.exists,
    required this.current,
    required this.onChanged,
    required this.onBack,
    required this.onAdd,
  });

  final YearMonth month;
  final bool exists;
  final YearMonth current;
  final ValueChanged<YearMonth> onChanged;
  final VoidCallback onBack;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(monthsNotifierProvider);
    final failure = state.failure;
    return _SheetStep(
      key: const Key('add-month-step'),
      header: Padding(
        padding: const EdgeInsetsDirectional.only(start: 8, end: 20),
        child: Row(
          children: [
            IconButton(
              key: const Key('months-back'),
              tooltip: '달 목록으로',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
            ),
            Expanded(
              child: Semantics(
                header: true,
                child: Text('새 달 추가', style: theme.textTheme.titleMedium),
              ),
            ),
          ],
        ),
      ),
      body: [
        const SizedBox(height: 8),
        MonthWheels(initial: month, current: current, onChanged: onChanged),
      ],
      action: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (failure != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                keepAll(monthsFailureMessage(failure)),
                key: const Key('months-failure'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          FilledButton(
            key: const Key('add-month-done'),
            onPressed: state.adding ? null : onAdd,
            child: Text(exists ? '이 달 보기' : '추가'),
          ),
        ],
      ),
    );
  }
}

/// 달 목록을 모르는 옛 가계부. 목록 대신 연·월 휠로 아무 달이나 골라 본다(달을 더하지는 않는다).
class _PickAnyMonthStep extends StatelessWidget {
  const _PickAnyMonthStep({
    required this.selected,
    required this.current,
    required this.onChanged,
    required this.onOpen,
  });

  final YearMonth selected;
  final YearMonth current;
  final ValueChanged<YearMonth> onChanged;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return _SheetStep(
      key: const Key('months-sheet'),
      header: const _MonthsTitle(description: '보고 싶은 달을 골라 주세요.'),
      body: [
        const SizedBox(height: 8),
        MonthWheels(initial: selected, current: current, onChanged: onChanged),
      ],
      action: FilledButton(
        key: const Key('pick-any-month'),
        onPressed: onOpen,
        child: const Text('이 달 보기'),
      ),
    );
  }
}

/// 한 해의 달들. 연도 아래로 최근 달부터 줄마다 달 이름을 두고, 이번 달 표시와 보고 있는 달 체크를 단다.
class _YearGroup extends StatelessWidget {
  const _YearGroup({
    required this.year,
    required this.months,
    required this.selected,
    required this.thisMonth,
    required this.onOpen,
    super.key,
  });

  final int year;
  final List<YearMonth> months;
  final YearMonth selected;
  final YearMonth thisMonth;
  final ValueChanged<YearMonth> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              '$year년',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final (index, month) in months.indexed) ...[
            if (index > 0)
              Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
            _MonthRow(
              key: ValueKey('month-${month.id}'),
              month: month,
              isThisMonth: month == thisMonth,
              viewing: month == selected,
              onTap: () => onOpen(month),
            ),
          ],
        ],
      ),
    );
  }
}

/// 달 한 줄. 보고 있는 달은 강조하고 체크를 단다.
class _MonthRow extends StatelessWidget {
  const _MonthRow({
    required this.month,
    required this.isThisMonth,
    required this.viewing,
    required this.onTap,
    super.key,
  });

  final YearMonth month;
  final bool isThisMonth;
  final bool viewing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: viewing,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Row(
            spacing: 8,
            children: [
              Text(
                '${month.month}월',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: viewing ? FontWeight.w700 : FontWeight.w600,
                  color: viewing ? scheme.primary : null,
                ),
              ),
              if (isThisMonth) const _ThisMonthPill(),
              const Spacer(),
              if (viewing)
                ExcludeSemantics(
                  child: Icon(Icons.check, color: scheme.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThisMonthPill extends StatelessWidget {
  const _ThisMonthPill();

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
        '이번 달',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

/// 추가한 달이 하나도 없을 때. 달 추가로 시작하게 알린다.
class _NoMonths extends StatelessWidget {
  const _NoMonths();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: const Key('months-empty'),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        keepAll('아직 추가한 달이 없어요.'),
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium,
      ),
    );
  }
}
