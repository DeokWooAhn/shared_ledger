import 'package:flutter/material.dart';

import '../../core/widget/tab_page.dart';

/// 고정 지출 탭. 매달 나가는 돈 목록과 편집은 다음 단계에서 채운다.
class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabPage(
      header: TabTitle(
        '고정 지출',
        description: '새 달을 처음 열면 이 목록으로 그달 기본 지출이 만들어져요.',
      ),
      children: [TabPlaceholder('고정 지출 목록은 다음 업데이트에서 볼 수 있어요.')],
    );
  }
}
