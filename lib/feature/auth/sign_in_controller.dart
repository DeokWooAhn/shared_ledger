import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';

/// 로그인 방법.
enum SignInMethod { google, apple }

/// 로그인 화면 상태.
@immutable
class SignInState {
  const SignInState({this.pending, this.failed = false});

  /// 진행 중인 로그인. null이면 아무것도 진행 중이 아니다.
  final SignInMethod? pending;

  /// 로그인에 실패했다. 화면이 스낵바로 알린 뒤 [SignInController.failureShown]으로 끈다.
  final bool failed;

  bool get busy => pending != null;

  @override
  bool operator ==(Object other) =>
      other is SignInState &&
      other.pending == pending &&
      other.failed == failed;

  @override
  int get hashCode => Object.hash(pending, failed);
}

final signInControllerProvider =
    NotifierProvider.autoDispose<SignInController, SignInState>(
      SignInController.new,
    );

/// 로그인 화면의 컨트롤러.
///
/// 로그인에 성공하면 화면 이동 규칙(router.dart)이 다음 화면으로 옮기고, 이 컨트롤러는 해제된다.
/// 사용자가 로그인 창을 닫은 것은 실패가 아니라서 아무것도 알리지 않는다.
class SignInController extends Notifier<SignInState> {
  @override
  SignInState build() => const SignInState();

  /// [method]로 로그인한다. 진행 중이면 무시하고, 오류는 [SignInState.failed]로 알린다.
  Future<void> signIn(SignInMethod method) async {
    if (state.busy) return;
    state = SignInState(pending: method);
    final auth = ref.read(authRepositoryProvider);
    try {
      await switch (method) {
        SignInMethod.google => auth.signInWithGoogle(),
        SignInMethod.apple => auth.signInWithApple(),
      };
      if (!ref.mounted) return;
      state = const SignInState();
    } catch (e) {
      debugPrint('로그인 실패: $e');
      if (!ref.mounted) return;
      state = const SignInState(failed: true);
    }
  }

  /// 화면이 실패를 알린 뒤 부른다.
  void failureShown() => state = SignInState(pending: state.pending);
}
