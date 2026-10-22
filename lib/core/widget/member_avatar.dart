import 'package:flutter/material.dart';

import '../model/member.dart';
import '../theme/app_theme.dart';

/// 두 사람을 구분하는 동그라미. 관리자(owner)는 채운 원, 상대(partner)는 테두리만 있는 원이다.
///
/// 색만으로 구분하지 않게 이름의 첫 글자를 넣고, 화면 읽기 도구에는 이름을 읽어 준다.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({required this.member, this.size = 32, super.key});

  final Member member;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final (fill, border, text) = switch (member.slot) {
      MemberSlot.owner => (colors.skySoft, null, scheme.onPrimary),
      MemberSlot.partner => (colors.seaSoft, colors.memberLine, colors.sea),
    };
    return Semantics(
      label: member.name,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill,
          border: border == null ? null : Border.all(color: border),
        ),
        // 원 크기가 정해져 있어 글자 크기 설정을 따르지 않는다. 이름은 화면 읽기 도구와 옆 글자로 전한다.
        child: Text(
          member.initial,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontSize: size * 13 / 32,
            fontWeight: FontWeight.w700,
            height: 1,
            color: text,
          ),
        ),
      ),
    );
  }
}
