import 'package:flutter/material.dart';

import '../../core/widget/month_header.dart';
import '../../core/widget/tab_page.dart';

/// 항목 탭. 수입·기본 지출·추가지출·카드대금 목록과 입력은 다음 단계에서 채운다.
class EntriesScreen extends StatelessWidget {
  const EntriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabPage(
      header: MonthHeader(),
      children: [TabPlaceholder('이번 달 항목은 다음 업데이트에서 볼 수 있어요.')],
    );
  }
}
