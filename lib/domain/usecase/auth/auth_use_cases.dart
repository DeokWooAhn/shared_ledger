import '../../repository/auth_repository.dart';
import 'sign_in_with_apple_use_case.dart';
import 'sign_in_with_google_use_case.dart';
import 'sign_out_use_case.dart';
import 'watch_auth_user_use_case.dart';

/// 로그인·로그아웃 UseCase 묶음. 로그인 상태 공급자, 로그인 화면, 로그아웃 도우미가 읽는다.
class AuthUseCases {
  AuthUseCases(AuthRepository auth)
    : watchAuthUser = WatchAuthUserUseCase(auth),
      signInWithGoogle = SignInWithGoogleUseCase(auth),
      signInWithApple = SignInWithAppleUseCase(auth),
      signOut = SignOutUseCase(auth);

  final WatchAuthUserUseCase watchAuthUser;
  final SignInWithGoogleUseCase signInWithGoogle;
  final SignInWithAppleUseCase signInWithApple;
  final SignOutUseCase signOut;
}
