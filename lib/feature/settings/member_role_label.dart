import '../../domain/model/ledger.dart';

/// 화면에 보이는 역할 이름.
String memberRoleLabel(MemberRole role) => switch (role) {
  MemberRole.owner => '관리자',
  MemberRole.editor => '편집자',
  MemberRole.viewer => '보기 전용',
};

/// 역할 이름에 '(으)로'를 붙인다. 예: '편집자로', '보기 전용으로'
String memberRoleWithRo(MemberRole role) => switch (role) {
  MemberRole.owner => '관리자로',
  MemberRole.editor => '편집자로',
  MemberRole.viewer => '보기 전용으로',
};
