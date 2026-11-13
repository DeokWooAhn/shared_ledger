import '../model/auth_user.dart';

/// 탈퇴하지 못한 이유 가운데 화면이 따로 알려 줄 것.
enum AccountDeletionFailure {
  /// 다시 로그인할 때 지금 계정이 아닌 다른 계정을 골랐다.
  wrongAccount,
}

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.reason);

  final AccountDeletionFailure reason;

  @override
  String toString() => 'AccountDeletionException($reason)';
}

/// 로그인·로그아웃·탈퇴. 화면은 이 인터페이스만 알고, 테스트에서는 가짜로 바꾼다.
abstract interface class AuthRepository {
  Stream<AuthUser?> authStateChanges();

  /// 로그인했으면 true, 사용자가 취소했으면 false.
  Future<bool> signInWithGoogle();

  /// 로그인했으면 true, 사용자가 취소했으면 false. iOS에서만 쓴다.
  Future<bool> signInWithApple();

  Future<void> signOut();

  /// 탈퇴하기 전에 지금 로그인 방법(Google·Apple)으로 한 번 더 로그인해 본인인지 확인한다.
  /// Firebase는 최근에 로그인한 계정만 지울 수 있게 한다.
  ///
  /// 확인했으면 true, 사용자가 취소했으면 false. 다른 계정을 골랐으면
  /// [AccountDeletionException]([AccountDeletionFailure.wrongAccount])을 던진다.
  Future<bool> reauthenticate();

  /// 로그인한 계정을 지운다. 바로 전에 [reauthenticate]해야 한다.
  ///
  /// Apple로 로그인했으면 Apple 토큰을 취소하고, Google이면 앱과의 연결을 끊은 뒤 지운다.
  /// 지우면 로그아웃 상태가 된다([authStateChanges]가 null을 보낸다).
  Future<void> deleteAccount();
}
