import '../../repository/auth_repository.dart';

/// 로그아웃한다. 성공하면 화면 이동 규칙(router.dart)이 로그인 화면으로 옮긴다.
class SignOutUseCase {
  const SignOutUseCase(this._auth);

  final AuthRepository _auth;

  Future<void> call() => _auth.signOut();
}
