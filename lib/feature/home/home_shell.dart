import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/providers.dart';
import '../../core/model/ledger_entries.dart';
import '../../core/model/year_month.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widget/keep_all.dart';
import 'month_fill_controller.dart';

/// 이 폭부터 아래 탭 막대 대신 옆 탭 막대를 쓴다. 아이패드·Mac, 가로로 눕힌 휴대폰이 해당한다.
const wideLayoutMinWidth = 600.0;

/// 홈의 네 탭. 순서가 router.dart의 탭 경로(branch) 순서다.
enum HomeTab {
  summary('요약', Icons.pie_chart_outline),
  entries('항목', Icons.format_list_bulleted),
  templates('고정 지출', Icons.repeat),
  settings('설정', Icons.settings_outlined);

  const HomeTab(this.label, this.icon);

  final String label;
  final IconData icon;

  /// 테스트에서 탭을 찾을 키.
  Key get key => Key('tab-$name');
}

/// [month]에 [kind] 항목을 더하는 입력 화면을 연다. 화면 이동은 router.dart가 정해서 넘겨준다.
typedef AddEntry =
    void Function(BuildContext context, EntryKind kind, YearMonth month);

/// 홈의 탭 틀. 좁은 화면에서는 아래에 떠 있는 탭 막대, 넓은 화면에서는 옆 탭 막대를 둔다.
///
/// 달을 보는 탭(요약·항목)에서는 + 버튼을 둔다. 좁은 화면은 탭 막대 오른쪽, 넓은 화면은 옆 탭 막대 맨 위다.
/// 탭마다 화면 상태(스크롤 위치 등)를 [StatefulNavigationShell]이 따로 지킨다.
/// 보고 있는 달(이번 달·다음 달)에 빠진 기본 월 지출은 어느 탭에 있든 고정 지출로 채운다.
class HomeShell extends ConsumerWidget {
  const HomeShell({
    required this.navigationShell,
    required this.onAddEntry,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final AddEntry onAddEntry;

  HomeTab get _current => HomeTab.values[navigationShell.currentIndex];

  // 지금 탭을 다시 누르면 그 탭의 첫 화면으로 돌아간다.
  void _select(HomeTab tab) => navigationShell.goBranch(
    tab.index,
    initialLocation: tab.index == navigationShell.currentIndex,
  );

  // + 버튼은 쓸 수 있는 사람에게 요약·항목 탭에서만 보인다. 항목 탭에서는 보던 종류, 요약 탭에서는 추가지출로 연다.
  VoidCallback? _addEntry(BuildContext context, WidgetRef ref) {
    final canWrite = ref.watch(myRoleProvider)?.canWrite ?? false;
    final tab = _current;
    if (!canWrite) return null;
    return switch (tab) {
      HomeTab.summary || HomeTab.entries => () => onAddEntry(
        context,
        tab == HomeTab.entries
            ? ref.read(selectedEntryKindProvider)
            : EntryKind.extra,
        ref.read(selectedMonthProvider),
      ),
      HomeTab.templates || HomeTab.settings => null,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 그달을 처음 열거나 고정 지출이 늘면 빠진 기본 월 지출을 만든다. 탭 화면보다 먼저 듣기 시작해서
    // 처음 값은 늘 불러오는 중(null)이고, 그달 항목과 고정 지출을 받은 뒤 바뀐 값으로 불린다.
    ref.listen(plannedFillProvider, (_, fill) {
      if (fill == null) return;
      ref.read(monthFillControllerProvider.notifier).fill(fill);
    });
    // 기다리지 않고 더한 항목을 서버가 거부하면 목록에서 조용히 빠지므로, 어느 탭에 있든 알린다.
    ref.listen(rejectedEntriesProvider, (_, rejected) {
      if (rejected is! AsyncData) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('entry-rejected'),
          content: Text(
            keepAll('저장한 항목을 서버가 받지 않아 목록에서 빠졌어요. 쓰기 권한이 있는지 확인해 주세요.'),
          ),
        ),
      );
    });
    final onAdd = _addEntry(context, ref);
    if (MediaQuery.sizeOf(context).width >= wideLayoutMinWidth) {
      return Scaffold(
        body: Row(
          children: [
            _SideTabBar(selected: _current, onSelect: _select, onAdd: onAdd),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }
    return Scaffold(
      // 탭 막대가 내용 위에 떠 있도록 본문을 막대 뒤까지 늘린다. 본문은 그 높이만큼 아래 여백을 둔다(TabPage).
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: _BottomTabBar(
        selected: _current,
        onSelect: _select,
        onAdd: onAdd,
      ),
    );
  }
}

/// 항목을 더하는 + 버튼. 포인트 색으로 채운 58 원이다.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: scheme.tertiary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Tooltip(
        message: '항목 추가',
        child: Semantics(
          button: true,
          child: Material(
            color: scheme.tertiary,
            shape: const CircleBorder(),
            child: InkWell(
              key: const Key('add-entry'),
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox.square(
                dimension: 58,
                child: Icon(Icons.add, size: 26, color: scheme.onTertiary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 좁은 화면의 아래 탭 막대. 둥근 막대 안에서 고른 탭만 포인트 색으로 채운다. [onAdd]가 있으면 오른쪽에 + 버튼을 둔다.
class _BottomTabBar extends StatelessWidget {
  const _BottomTabBar({
    required this.selected,
    required this.onSelect,
    required this.onAdd,
  });

  final HomeTab selected;
  final ValueChanged<HomeTab> onSelect;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          spacing: 10,
          children: [
            Expanded(
              child: _FloatingTabBar(selected: selected, onSelect: onSelect),
            ),
            ?switch (onAdd) {
              final onAdd? => _AddButton(onPressed: onAdd),
              null => null,
            },
          ],
        ),
      ),
    );
  }
}

/// 아래 탭 막대의 둥근 막대 부분.
class _FloatingTabBar extends StatelessWidget {
  const _FloatingTabBar({required this.selected, required this.onSelect});

  final HomeTab selected;
  final ValueChanged<HomeTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(31),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      // 고른 탭의 바탕(Ink)은 가장 가까운 Material 위에 그려진다. 막대 바탕을 Material로 둬야 가려지지 않는다.
      child: Material(
        // 뒤로 지나가는 내용이 살짝 비치게 카드 색을 95%로 둔다.
        color: scheme.surfaceContainer.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(31),
          side: BorderSide(color: scheme.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          // 막대 높이가 정해져 있어 글자 크기 설정은 1.3배까지만 따른다.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: SizedBox(
              height: 50,
              child: Row(
                spacing: 2,
                children: [
                  for (final tab in HomeTab.values)
                    Expanded(
                      child: _TabButton(
                        tab: tab,
                        selected: tab == selected,
                        onTap: () => onSelect(tab),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final HomeTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.onTertiary : context.appColors.textMuted;
    const radius = BorderRadius.all(Radius.circular(25));
    return Semantics(
      button: true,
      selected: selected,
      child: Ink(
        decoration: BoxDecoration(
          color: selected ? scheme.tertiary : null,
          borderRadius: radius,
        ),
        child: InkWell(
          key: tab.key,
          borderRadius: radius,
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(tab.icon, size: 22, color: color),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  tab.label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 넓은 화면의 옆 탭 막대. [onAdd]가 있으면 맨 위에 + 버튼을 둔다.
class _SideTabBar extends StatelessWidget {
  const _SideTabBar({
    required this.selected,
    required this.onSelect,
    required this.onAdd,
  });

  final HomeTab selected;
  final ValueChanged<HomeTab> onSelect;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = context.appColors.textMuted;
    final label = theme.textTheme.labelMedium?.copyWith(fontSize: 12);
    return NavigationRail(
      selectedIndex: selected.index,
      onDestinationSelected: (index) => onSelect(HomeTab.values[index]),
      labelType: NavigationRailLabelType.all,
      groupAlignment: -0.9,
      backgroundColor: scheme.surface,
      indicatorColor: scheme.tertiary,
      selectedIconTheme: IconThemeData(color: scheme.onTertiary, size: 22),
      unselectedIconTheme: IconThemeData(color: muted, size: 22),
      selectedLabelTextStyle: label?.copyWith(color: scheme.tertiary),
      unselectedLabelTextStyle: label?.copyWith(color: muted),
      // + 버튼이 없는 탭에서도 자리를 비워 둬서, 탭을 옮길 때 탭 막대가 위아래로 움직이지 않게 한다.
      leading: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: SizedBox.square(
          dimension: 58,
          child: switch (onAdd) {
            final onAdd? => _AddButton(onPressed: onAdd),
            null => null,
          },
        ),
      ),
      destinations: [
        for (final tab in HomeTab.values)
          NavigationRailDestination(
            icon: Icon(tab.icon, key: tab.key),
            label: Text(tab.label),
          ),
      ],
    );
  }
}
