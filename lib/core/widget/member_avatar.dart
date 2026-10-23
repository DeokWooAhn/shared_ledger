import 'package:flutter/material.dart';

import '../model/member.dart';
import '../theme/app_theme.dart';

/// 두 사람의 프로필 동그라미. 둘 다 같은 회색 원에 이름의 첫 글자로 구분한다(나중에 프로필 사진으로 바꾼다).
///
/// 화면 읽기 도구에는 이름을 읽어 준다.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({required this.member, this.size = 32, super.key});

  final Member member;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: member.name,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.appColors.avatar,
        ),
        // 원 크기가 정해져 있어 글자 크기 설정을 따르지 않는다. 이름은 화면 읽기 도구와 옆 글자로 전한다.
        child: Text(
          member.initial,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontSize: size * 13 / 32,
            fontWeight: FontWeight.w700,
            height: 1,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
