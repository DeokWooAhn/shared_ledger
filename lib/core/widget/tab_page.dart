import 'package:flutter/material.dart';

import 'keep_all.dart';

/// 탭 화면 본문의 최대 폭. 아이패드·Mac에서는 이 폭으로 가운데 둔다.
const tabPageMaxWidth = 640.0;

/// 탭 화면 본문 양옆의 최소 여백.
const tabPageSidePadding = 20.0;

/// 탭 화면의 공통 틀. 머리말 아래로 내용을 세로로 쌓는다.
///
/// 넓은 화면에서는 본문을 [maxWidth]로 가운데 두되, 양옆 여백에서도 스크롤되게 목록은 화면 전체 폭으로 둔다.
/// 좁은 화면에서는 아래 탭 막대가 내용 위에 떠 있어(HomeShell의 extendBody) 그 높이만큼 아래 여백을 둔다.
class TabPage extends StatelessWidget {
  const TabPage({
    required this.header,
    this.children = const [],
    this.maxWidth = tabPageMaxWidth,
    super.key,
  });

  final Widget header;
  final List<Widget> children;

  /// 본문의 최대 폭. 두 칸으로 놓는 화면(월 요약)만 넓힌다.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = ((constraints.maxWidth - maxWidth) / 2).clamp(
              tabPageSidePadding,
              double.infinity,
            );
            return ListView(
              padding: EdgeInsets.fromLTRB(side, 4, side, 24 + bottom),
              children: [header, const SizedBox(height: 16), ...children],
            );
          },
        ),
      ),
    );
  }
}

/// 고정 지출·설정 탭 맨 위의 제목. [description]이 있으면 아래에 설명을 둔다.
class TabTitle extends StatelessWidget {
  const TabTitle(this.title, {this.description, super.key});

  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = this.description;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.headlineMedium),
          ),
          if (description != null) ...[
            const SizedBox(height: 6),
            Text(
              keepAll(description),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 아직 만들지 않은 탭 내용 자리. 해당 화면을 만들면 지운다.
class TabPlaceholder extends StatelessWidget {
  const TabPlaceholder(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Text(
          keepAll(message),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ),
    );
  }
}
