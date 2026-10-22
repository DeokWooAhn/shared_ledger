import 'package:flutter/material.dart';

import '../../core/widget/month_header.dart';
import '../../core/widget/tab_page.dart';

/// 월 요약 탭. 남는 현금, 이번 달 지출, 카드, 분류별 기본 지출은 다음 단계에서 채운다.
class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabPage(
      header: MonthHeader(),
      children: [TabPlaceholder('이번 달 요약은 다음 업데이트에서 볼 수 있어요.')],
    );
  }
}
