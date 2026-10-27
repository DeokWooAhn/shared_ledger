import '../../model/auth_user.dart';
import '../../repository/auth_repository.dart';

/// 로그인한 사용자를 지켜본다. 로그아웃 상태면 null이 온다.
class WatchAuthUserUseCase {
  const WatchAuthUserUseCase(this._auth);

  final AuthRepository _auth;

  Stream<AuthUser?> call() => _auth.authStateChanges();
}
