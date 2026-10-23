import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/data/auth_repository.dart';
import 'package:shared_ledger/core/model/auth_user.dart';

void main() {
  test('로그인 제공자 id로 로그인 방법을 정하고, 모르는 제공자면 null이다', () {
    expect(signInMethodOf(['google.com']), SignInMethod.google);
    expect(signInMethodOf(['apple.com']), SignInMethod.apple);
    // 아는 제공자를 먼저 만나는 것을 쓴다.
    expect(signInMethodOf(['password', 'apple.com']), SignInMethod.apple);
    expect(signInMethodOf(['password']), isNull);
    expect(signInMethodOf(const []), isNull);
  });
}
