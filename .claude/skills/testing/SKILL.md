---
name: testing
description: 심플 공유 가계부(shared_ledger)의 테스트를 쓰거나 고칠 때 쓴다. 단위 테스트, 컨트롤러 테스트(ProviderContainer), 화면 흐름 위젯 테스트, Firestore 보안 규칙 테스트, test/support/fakes.dart의 가짜 저장소 작성이 해당된다. "테스트 추가해줘", "이 버그 테스트로 막아줘", "가짜 저장소 고쳐줘" 같은 요청에 쓴다. 층별 정석 레퍼런스와 자주 틀리는 점이 들어 있다. 실행 명령은 verification 스킬.
---

# 테스트 작성 규칙

새 테스트는 아래 정석 레퍼런스의 구조를 복사해서 시작한다.

## 층별 테스트

| 대상 | 방법 | 정석 레퍼런스 |
| --- | --- | --- |
| 계산 규칙, 모델 | 실제 객체로 단위 테스트 | `test/core/budget/budget_calculator_test.dart`, `test/core/model/ledger_test.dart` |
| Firestore 변환·쓰기 데이터 | 순수 함수 단위 테스트 | `test/core/data/ledger_repository_test.dart` |
| 컨트롤러 | `ProviderContainer` + 가짜 저장소 | `test/feature/ledger/ledger_start_controller_test.dart` |
| 화면 흐름, 화면 이동 | 위젯 테스트 | `test/widget_test.dart`, `test/router_test.dart` |
| 보안 규칙 | Firestore 에뮬레이터 | `firestore-tests/rules.test.js` |

## 공통

- 테스트 설명은 한국어로, 읽기만 해도 상황과 기대 결과가 드러나게 쓴다(`'로그인을 취소하면 로그인 화면에 그대로 있다'`). `group`으로 기능을 묶는다.
- 준비-실행-확인 순서로, 테스트 하나에 한 가지 개념만 본다. 테스트 사이에 가변 상태를 공유하지 않는다(필요하면 테스트 안에서 새로 만든다).
- 테스트 데이터는 가상이다. 실제 금액·이름·이메일을 쓰지 않는다.
- **버그를 고치면 그 버그를 재현하는 테스트를 같이 넣는다.** 고치기 전 코드에서 실패하는지 생각해 보고, 아니면 테스트를 바꾼다.
- **초기값과 기대값이 같은 단언을 조심한다.** "실패하면 그대로 둔다"를 볼 때 처음부터 그 값이면 아무것도 검증하지 못한다.
- 경계값을 빠뜨리지 않는다: 0원, 음수, 빈 문자열, 최대 길이(40자), 모르는 enum 값, 두 명이 찬 가계부.
- 시간·난수에 기대지 않는다. 저장소는 `now:`·`random:`을 주입하고, 위젯 테스트는 `tester.pump(duration)`으로 시간을 넘긴다.
  오늘 날짜는 `createContainer`·`pumpApp`이 `clockProvider`를 `testNow`(2026-10-15)로 고정한다.
- 모킹 라이브러리를 쓰지 않는다. Firebase도 모킹하지 않는다.

## 컨트롤러 테스트

```dart
test('…', () async {
  final ledgers = FakeLedgerRepository()..nextJoinFailure = JoinFailure.expired;
  final container = createContainer(
    auth: FakeAuthRepository(signedIn: me),
    ledgers: ledgers,
  );
  await loadSignedInUser(container);                          // authUserProvider 값을 먼저 받는다
  final states = recordStates(container, xxxControllerProvider); // autoDispose를 살려 두고 상태를 기록

  await container.read(xxxControllerProvider.notifier).join('ABCDEFGH23');

  expect(container.read(xxxControllerProvider).codeProblem, InviteCodeProblem.expired);
});
```

- 도우미는 `test/support/provider_container.dart`: `createContainer`, `loadSignedInUser`, `recordStates`.
- Riverpod 3은 듣는 곳이 없는 공급자를 멈춘다. `container.read(xxxProvider.future)` 전에 `container.listen`으로 붙잡아 둔다
  (`loadSignedInUser`가 로그인 상태에 이렇게 한다). 붙잡지 않으면 값이 오지 않아 테스트가 30초 뒤 시간 초과로 끝난다.
- 다른 공급자에 기대는 공급자는 앞 공급자의 값이 온 뒤에 읽는다. 가계부 목록이 오기 전의 `membersProvider`는 빈 목록이다(`providers_test.dart`).
- 상태가 거쳐 간 순서(진행 중 → 끝)는 `recordStates`가 돌려준 목록으로 확인한다. State는 `==`가 있어서 `expect(states, [...])`로 비교된다.
- 진행 중 두 번 눌림은 `Future.wait([vm.x(), vm.x()])`로 두 번 부르고 저장소 호출 수를 본다(`sign_in_controller_test.dart`).
- 일회성 실패는 켜지는 것과 `failureShown()`으로 꺼지는 것을 둘 다 본다.
- 문구가 아니라 enum 값을 단언한다. 문구는 위젯 테스트에서 본다.

## 위젯 테스트

- `pumpApp`이 `ProviderScope(overrides:)`로 가짜 저장소를 끼운 앱 전체를 띄운다. 실제 사용 순서대로 누른다.
- `pumpApp`은 디자인과 같은 휴대폰 크기(390×844)로 띄운다. 테스트 기본 크기(800×600)는 넓은 화면 배치가 된다. 넓은 화면은 `size: tabletSize`.
- 탭은 `openTab(tester, HomeTab.settings)`로 옮긴다. 탭 막대 배치와 상관없이 `HomeTab.key`로 찾는다.
- 불러오는 중 화면의 진행 표시가 계속 돌아서 `pumpAndSettle`은 끝나지 않는다. `settle()`처럼 정해진 횟수만 그린다.
  화면 전환(300ms)이 끝날 만큼 그려야 한다. 짧으면 이전 화면의 Scaffold가 남아 스낵바가 두 개 보인다.
- 위젯은 화면 문구가 아니라 `Key`로 찾는다. `keepAll()`로 그린 문장은 `findSentence('…')`(`find.text(keepAll(…))`)로 찾는다.
- 스크롤되는 화면은 `scrollTo`·`tapVisible`·`enterVisible`로 위젯이 나올 때까지 스크롤한 뒤 다룬다. 화면 밖 항목은 아직 만들어지지 않았을 수 있다.
- 플랫폼 분기(Apple 버튼)는 `variant: TargetPlatformVariant.only(TargetPlatform.iOS)`로 본다.
  `debugDefaultTargetPlatformOverride`를 직접 바꾸면 const 위젯이 다시 그려지지 않아 다른 테스트까지 깨진다.
- 접근성은 `tester.ensureSemantics()` 후 `tester.getSemantics(find.byKey(…))`로 이름표와 입력란 속성을 본다. 끝나면 `dispose()`.
- 화면 이동 결과는 다음 화면의 고유한 문구나 위젯 타입(`find.byType(LedgerStartScreen)`)으로 확인한다.

## 가짜 저장소 (`test/support/fakes.dart`)

- 실제 인터페이스를 `implements`한다. 인터페이스가 바뀌면 컴파일 에러로 드러나야 한다.
- **실제 구현의 약속을 지킨다.** 다르면 테스트가 거짓으로 통과한다(PR #3에서 실제로 겪음).
  - 로그아웃 상태면 빈 목록, 로그인 창을 닫으면 `false`
  - 두 명이 찬 가계부·이미 구성원이면 참여를 `JoinFailure.unavailable`로 거부
  - 같은 id의 문서를 다시 쓰면 바꾸고, 새로 더하지 않는다
- 호출 기록을 남긴다(`created`, `invites`, `joins`, `googleCalls`, 설정을 구독한 가계부 `watched`).
- 실패 스위치는 다음 한 번만 실패하고 스스로 꺼진다: 도메인 실패(`nextJoinFailure`), 예상 못 한 오류(`failNextCreate`, `failNextInvite`, `failNextJoin`, `failNextSignIn`, `failNextSignOut`).

## Firestore 변환 테스트

- 쓰기 데이터는 필드 목록 전체를 단언한다. 보안 규칙이 받는 필드와 맞는지 확인하는 장치다.
- 서버 시간은 `isA<FieldValue>()`, 필드 경로는 `FieldPath(['roles', uid])`로 비교한다.
- 읽기 변환은 모르는 값·빠진 필드·타입이 다른 값이 와도 죽지 않는지 본다.

## 보안 규칙 테스트 (`firestore-tests/rules.test.js`)

- 기본 데이터는 `beforeEach`에서 `withSecurityRulesDisabled`로 넣는다. 가계부마다 구성원 수를 정해 둔다(가득 참, 혼자).
- 바뀐 규칙마다 허용 테스트와 거부 테스트를 둘 다 둔다. `assertFails`만 있으면 규칙이 전부 막아도 통과한다.
- '막혀야 한다' 테스트는 통과하는 경우와 한 가지만 다르게 만든다. 여러 군데가 다르면 엉뚱한 이유로 막혀도 통과한다.
- 프로젝트 id는 `demo-`로 시작한다. 실행 명령은 verification 스킬.
