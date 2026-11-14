import 'package:flutter/material.dart';

import '../../domain/format/won.dart';
import '../theme/app_theme.dart';

// 홈(월 요약)과 통계 탭이 같이 쓰는 카드 조각.

/// 본문(양옆 여백을 뺀 폭)이 이 폭 이상이면 홈·통계를 두 칸으로 놓는다.
/// 아이패드를 가로로 놓은 정도다(세로는 한 칸).
const summaryTwoColumnMinWidth = 840.0;

/// 두 칸일 때 본문의 최대 폭.
const summaryTwoColumnMaxWidth = 960.0;

/// 진한 코발트 큰 카드(홈의 남는 현금). 라이트·다크 모두 같은 색이고, 장식 없이 바탕색만 깐다.
///
/// [onTap]을 주면 카드 전체가 단추 하나가 되고, 누른 자리의 물결이 안쪽 여백에 갇히지 않고 카드 끝까지 퍼진다.
class HeroCard extends StatelessWidget {
  const HeroCard({required this.child, this.onTap, this.tapKey, super.key});

  final Widget child;
  final VoidCallback? onTap;

  /// 테스트에서 누를 자리를 찾을 키.
  final Key? tapKey;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: const EdgeInsets.all(22), child: child);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.appColors.hero,
        borderRadius: BorderRadius.circular(24),
      ),
      child: onTap == null
          ? content
          // 물결이 코발트 바탕 위에 보이게 투명한 Material을 깐다. 둥근 모서리 밖은 Container가 자른다.
          : Material(
              type: MaterialType.transparency,
              child: Semantics(
                button: true,
                child: InkWell(key: tapKey, onTap: onTap, child: content),
              ),
            ),
    );
  }
}

/// 카드 맨 위의 제목. 보조 글자색 아이콘을 앞에 둔다(설정 줄의 아이콘과 같은 색).
class SectionTitle extends StatelessWidget {
  const SectionTitle({required this.icon, required this.title, super.key});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        Flexible(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}

/// 큰 금액. 글자를 키우거나 금액이 길어도 잘리지 않게 폭이 모자라면 줄인다.
class AmountText extends StatelessWidget {
  const AmountText(
    this.amount, {
    required this.style,
    this.textKey,
    this.identifier,
    super.key,
  });

  final int amount;
  final TextStyle? style;

  /// 테스트에서 금액 글자를 찾을 키.
  final Key? textKey;

  /// 실제 기기의 접근성 계층에서 금액을 찾을 식별자.
  final String? identifier;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        won(amount),
        semanticsIdentifier: identifier,
        key: textKey,
        maxLines: 1,
        style: style?.tabularFigures,
      ),
    );
  }
}

/// 비율 막대. 숫자는 옆 글자로 읽으므로 화면 읽기 도구에는 알리지 않는다.
class ShareBar extends StatelessWidget {
  const ShareBar({required this.share, required this.color, super.key});

  final double share;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(4));
    return ExcludeSemantics(
      child: SizedBox(
        height: 8,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outlineVariant,
            borderRadius: radius,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: share.clamp(0.0, 1.0),
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color, borderRadius: radius),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
