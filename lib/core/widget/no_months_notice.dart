import 'package:flutter/material.dart';

import 'keep_all.dart';

/// 가계부가 있는 달이 하나도 없을 때 요약·항목 탭에 보이는 안내. 가계부는 가계부 탭에서 추가한다.
///
/// 새 가계부는 처음 고른 달과 함께 만들어져서 보통은 보이지 않는다. 항목이 하나도 없던 옛 가계부만 해당한다.
class NoMonthsNotice extends StatelessWidget {
  const NoMonthsNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('no-months'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Column(
          spacing: 6,
          children: [
            Text(
              keepAll('아직 추가한 가계부가 없어요.'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            Text(
              keepAll('가계부 탭에서 쓸 달을 추가해 주세요.'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
