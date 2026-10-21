---
name: new-feature
description: 심플 공유 가계부(shared_ledger)에 새 화면이나 기능을 추가하거나 화면 구조를 바꿀 때 쓴다. "초대 화면 만들어줘", "항목 입력 기능 추가해줘", "설정 화면 넣어줘" 같은 요청이 해당된다. 모델·저장소·공급자·화면·경로·가짜·테스트를 어떤 순서로 어디에 두는지와, Firestore 필드·컬렉션을 바꿀 때 같이 고칠 파일 목록이 들어 있다.
---

# 새 화면·기능 추가

기준 코드는 로그인(`lib/feature/auth/`)과 가계부 만들기(`lib/feature/household/`)다. 폴더 간 의존 규칙은 AGENTS.md의 '구조'가 원본이다.

## 순서

1. **모델** — `lib/core/model/<이름>.dart`. 역할·권한 판단은 모델에 둔다(`HouseholdRole.canWrite`).
2. **저장소** — `lib/core/data/<이름>_repository.dart`
   - `abstract interface class XxxRepository`와 `FirestoreXxxRepository` 구현을 같은 파일에 둔다.
   - Firestore 문서 ↔ 모델 변환은 최상위 함수로 빼서 테스트한다(`newHouseholdData`, `householdFromFirestore`).
   - 알 수 없는 값은 앱을 죽이지 말고 건너뛴다(`householdFromFirestore`의 역할 처리).
   - 시간 필드는 `docs/firestore.md`의 감사 필드 규칙을 따른다.
3. **공급자** — `lib/core/data/providers.dart`에 `Provider`(저장소)와 `StreamProvider`(구독)를 추가한다.
   로그인하지 않았으면 빈 값을 내보낸다(`myHouseholdsProvider`).
4. **화면** — `lib/feature/<기능>/<이름>_screen.dart`
   - 비동기 작업은 `_busy`로 버튼을 막고, 실패는 `SnackBar`로 알리고, 사용자가 취소한 것은 오류로 보여주지 않는다(`SignInScreen._signIn`).
   - 테스트에서 찾을 위젯에는 `Key`를 준다(이름 규칙은 verification 스킬).
   - 아이패드·Mac(아이패드 앱)에서도 쓰므로 넓은 화면에서 깨지지 않는지 본다(`docs/plan.md`의 '화면').
5. **경로** — `lib/router.dart`의 `Routes`에 경로를 추가하고 `GoRoute`를 등록한다.
   - 로그인·가계부 상태에 따라 반드시 거쳐야 하는 화면이면 `AppGate`와 `redirectFor`를 고치고 `test/router_test.dart`에 경우를 추가한다.
   - 그 밖의 화면은 `context.push`/`context.go`로 이동한다.
6. **가짜** — 저장소 인터페이스를 새로 만들었으면 `test/support/fakes.dart`에 가짜를 추가하고 호출 기록을 남긴다(`created`, `googleCalls`).
7. **테스트** — 변환 함수는 `test/core/data/`, 화면 흐름은 `pumpApp`으로 가짜를 끼워 실제 사용 순서대로 누른다. 작성 기준은 verification 스킬.

## Firestore 필드·컬렉션을 바꿀 때

한 곳만 바꾸면 앱 테스트는 가짜 저장소로 통과해도 실제 Firestore는 쓰기를 거부한다. 아래를 같이 바꾼다.

- [ ] `firestore-tests/rules.test.js` (먼저 고친다)
- [ ] `firestore.rules`
- [ ] 앱의 쓰기 데이터 함수와 그 필드 목록 테스트
- [ ] 권한 판단을 바꿨으면 `lib/core/model/household.dart`와 `test/core/model/household_test.dart`
- [ ] `docs/firestore.md`
- [ ] 새 쿼리에 복합 색인이 필요하면 `firestore.indexes.json`

리스너는 필요한 문서만 구독한다. 규칙 배포는 PR이 합쳐진 뒤에 한다(firebase 스킬).

## 마치기 전에

- verification 스킬대로 검사한다.
- 화면을 새로 만들었으면 기기나 시뮬레이터에서 한 번 띄워 본다.
- `docs/plan.md`의 단계 상태가 바뀌었으면 고친다.
