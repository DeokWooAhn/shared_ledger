import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
