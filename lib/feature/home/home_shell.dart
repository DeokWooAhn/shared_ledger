import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

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

/// 홈의 탭 틀. 좁은 화면에서는 아래에 떠 있는 탭 막대, 넓은 화면에서는 옆 탭 막대를 둔다.
///
/// 탭마다 화면 상태(스크롤 위치 등)를 [StatefulNavigationShell]이 따로 지킨다.
class HomeShell extends StatelessWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  HomeTab get _current => HomeTab.values[navigationShell.currentIndex];

  // 지금 탭을 다시 누르면 그 탭의 첫 화면으로 돌아간다.
  void _select(HomeTab tab) => navigationShell.goBranch(
    tab.index,
    initialLocation: tab.index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= wideLayoutMinWidth) {
      return Scaffold(
        body: Row(
          children: [
            _SideTabBar(selected: _current, onSelect: _select),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }
    return Scaffold(
      // 탭 막대가 내용 위에 떠 있도록 본문을 막대 뒤까지 늘린다. 본문은 그 높이만큼 아래 여백을 둔다(TabPage).
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: _BottomTabBar(selected: _current, onSelect: _select),
    );
  }
}

/// 좁은 화면의 아래 탭 막대. 둥근 막대 안에서 고른 탭만 포인트 색으로 채운다.
class _BottomTabBar extends StatelessWidget {
  const _BottomTabBar({required this.selected, required this.onSelect});

  final HomeTab selected;
  final ValueChanged<HomeTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: DecoratedBox(
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

/// 넓은 화면의 옆 탭 막대.
class _SideTabBar extends StatelessWidget {
  const _SideTabBar({required this.selected, required this.onSelect});

  final HomeTab selected;
  final ValueChanged<HomeTab> onSelect;

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
