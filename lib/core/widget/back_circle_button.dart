import 'package:flutter/material.dart';

/// 왼쪽 위의 뒤로 단추. 설정의 하위 화면, 입력 화면, 달력이 같이 쓴다.
///
/// 바탕색이 화면 바탕과 같으면 동그라미가 보이지 않으니, 바탕과 다른 색을 [background]로 준다.
/// [filled]가 false면 바탕 없이 화살표만 둔다(달력).
class BackCircleButton extends StatelessWidget {
  const BackCircleButton({
    this.tooltip = '뒤로',
    this.background,
    this.filled = true,
    super.key,
  });

  final String tooltip;

  /// 동그라미 바탕. 없으면 화면 바탕(surface)이다.
  final Color? background;

  /// 동그라미 바탕을 칠하는지.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: filled ? background ?? scheme.surface : null,
        fixedSize: const Size(40, 40),
      ),
      onPressed: () => Navigator.of(context).maybePop(),
      icon: Icon(Icons.arrow_back, size: 20, color: scheme.onSurface),
    );
  }
}
