import '../../repository/auth_repository.dart';

/// Apple로 로그인한다. 로그인했으면 true, 사용자가 로그인 창을 닫았으면 false다(실패가 아니다). iOS에서만 쓴다.
class SignInWithAppleUseCase {
  const SignInWithAppleUseCase(this._auth);

  final AuthRepository _auth;

  Future<bool> call() => _auth.signInWithApple();
}
