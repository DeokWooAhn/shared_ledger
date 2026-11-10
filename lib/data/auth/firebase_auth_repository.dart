import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../domain/model/auth_user.dart';
import '../../domain/repository/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    required FirebaseAuth auth,
    required GoogleSignIn googleSignIn,
    String? iosClientId,
  }) : _auth = auth,
       _googleSignIn = googleSignIn,
       _iosClientId = iosClientId;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final String? _iosClientId;
  Future<void>? _googleInitialization;

  /// 탈퇴 직전 [reauthenticate]에서 확인한 로그인 방법과, Apple이면 토큰을 취소할 때 쓸 인증 코드.
  SignInMethod? _reauthenticatedWith;
  String? _appleAuthorizationCode;

  @override
  Stream<AuthUser?> authStateChanges() => _auth.authStateChanges().map(
    (user) => user == null
        ? null
        : AuthUser(
            uid: user.uid,
            displayName: user.displayName,
            email: user.email,
            signInMethod: signInMethodOf([
              for (final info in user.providerData) info.providerId,
            ]),
          ),
  );

  // GoogleSignIn.initialize는 앱에서 한 번만 불러야 한다.
  Future<void> _initializeGoogle() => _googleInitialization ??= _googleSignIn
      .initialize(clientId: _iosClientId);

  @override
  Future<bool> signInWithGoogle() async {
    await _initializeGoogle();
    final GoogleSignInAccount account;
    try {
      account = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      rethrow;
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google 로그인에서 idToken을 받지 못했습니다.');
    }
    await _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
    return true;
  }

  @override
  Future<bool> signInWithApple() async {
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    try {
      await _auth.signInWithProvider(provider);
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'canceled') return false;
      rethrow;
    }
  }

  @override
  Future<bool> reauthenticate() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('로그인하지 않아 다시 확인할 계정이 없다');
    final method = signInMethodOf([
      for (final info in user.providerData) info.providerId,
    ]);
    try {
      switch (method) {
        case SignInMethod.google:
          await _initializeGoogle();
          final GoogleSignInAccount account;
          try {
            account = await _googleSignIn.authenticate();
          } on GoogleSignInException catch (e) {
            if (e.code == GoogleSignInExceptionCode.canceled) return false;
            rethrow;
          }
          final idToken = account.authentication.idToken;
          if (idToken == null) {
            throw StateError('Google 로그인에서 idToken을 받지 못했습니다.');
          }
          await user.reauthenticateWithCredential(
            GoogleAuthProvider.credential(idToken: idToken),
          );
        case SignInMethod.apple:
          final credential = await user.reauthenticateWithProvider(
            AppleAuthProvider(),
          );
          _appleAuthorizationCode =
              credential.additionalUserInfo?.authorizationCode;
        case null:
          // 모르는 로그인 방법이면 다시 확인할 수 없다. 최근에 로그인했으면 지우기가 되고, 아니면 지우기가 실패한다.
          break;
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'canceled' || e.code == 'web-context-canceled') {
        return false;
      }
      if (e.code == 'user-mismatch') {
        throw const AccountDeletionException(
          AccountDeletionFailure.wrongAccount,
        );
      }
      rethrow;
    }
    _reauthenticatedWith = method;
    return true;
  }

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('로그인하지 않아 지울 계정이 없다');
    final method = _reauthenticatedWith;
    final appleCode = _appleAuthorizationCode;
    _reauthenticatedWith = null;
    _appleAuthorizationCode = null;
    // 토큰 취소는 지금 로그인한 사용자로 하므로 계정을 지우기 전에 한다(App Store 심사 지침의 Apple 토큰 취소).
    switch (method) {
      case SignInMethod.apple when appleCode != null:
        await _auth.revokeTokenWithAuthorizationCode(appleCode);
      case SignInMethod.google:
        await _googleSignIn.disconnect();
      case SignInMethod.apple || null:
        break;
    }
    await user.delete();
  }

  @override
  Future<void> signOut() async {
    if (_googleInitialization != null) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }
}

/// Firebase 로그인 제공자 id(`google.com`, `apple.com`)로 로그인 방법을 정한다. 아는 것이 없으면 null.
SignInMethod? signInMethodOf(List<String> providerIds) {
  for (final id in providerIds) {
    switch (id) {
      case 'google.com':
        return SignInMethod.google;
      case 'apple.com':
        return SignInMethod.apple;
    }
  }
  return null;
}
