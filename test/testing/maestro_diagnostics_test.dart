import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../testing/maestro_diagnostics.dart';

void main() {
  test('진단은 로딩 상태만 기록하고 데이터 값은 출력하지 않는다', () {
    expect(maestroStateLabel(const AsyncLoading<String>()), 'loading');
    expect(maestroStateLabel(const AsyncData('개인 입력 12345')), 'data');
    expect(maestroStateLabel(null), 'empty');
  });

  test('Firebase 오류는 메시지나 사용자 값 없이 코드만 기록한다', () {
    final error = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
      message: '개인 정보',
    );
    expect(
      maestroStateLabel(AsyncError<Object>(error, StackTrace.current)),
      'error:unavailable',
    );
  });
}
