/// 로그인한 사용자. Firebase 타입을 feature에 퍼뜨리지 않으려고 필요한 값만 담는다.
class AuthUser {
  const AuthUser({required this.uid, this.displayName, this.email});

  final String uid;
  final String? displayName;
  final String? email;
}
