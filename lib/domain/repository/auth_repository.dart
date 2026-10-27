import '../model/auth_user.dart';

/// 로그인·로그아웃. 화면은 이 인터페이스만 알고, 테스트에서는 가짜로 바꾼다.
abstract interface class AuthRepository {
  Stream<AuthUser?> authStateChanges();

  /// 로그인했으면 true, 사용자가 취소했으면 false.
  Future<bool> signInWithGoogle();

  /// 로그인했으면 true, 사용자가 취소했으면 false. iOS에서만 쓴다.
  Future<bool> signInWithApple();

  Future<void> signOut();
}
