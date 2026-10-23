/// 로그인에 쓴 방법. 설정 탭의 '로그인 방법'에 보인다.
enum SignInMethod { google, apple }

/// 로그인한 사용자. Firebase 타입을 feature에 퍼뜨리지 않으려고 필요한 값만 담는다.
class AuthUser {
  const AuthUser({
    required this.uid,
    this.displayName,
    this.email,
    this.signInMethod,
  });

  final String uid;
  final String? displayName;
  final String? email;

  /// 로그인에 쓴 방법. 모르는 제공자면 null.
  final SignInMethod? signInMethod;
}
