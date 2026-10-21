# 심플 공유 가계부 (shared_ledger)

구글 시트로 쓰던 공동 가계부를 Flutter 앱으로 옮겨 공개 배포하려는 프로젝트. 계획·결정 사항은 `docs/plan.md`.

## 구조

```
lib/
  core/      여러 기능이 같이 쓰는 것. 계산 규칙(core/budget)과 모델(core/model)은 순수 Dart
  feature/   기능별 폴더 (auth, household, summary, entry, template, settings …)
```

- feature끼리 서로 import하지 않는다. 둘 이상이 쓰게 되면 core로 올린다.
- `core/budget`, `core/model`에는 Flutter·Firebase import를 넣지 않는다 (테스트가 쉬워야 함).

## 명령

```bash
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator --debug
```

Flutter는 fvm 전역 버전(3.35.5)을 쓴다. CocoaPods가 UTF-8 경고를 내면 `export LANG=en_US.UTF-8`을 먼저 한다.

### Xcode 27에서 iOS 빌드 (2026-10-21 확인, Xcode 27.1)

- Xcode 27의 `lipo`는 `-verify_arch`에 아키텍처를 하나만 받는다. Flutter 3.35는 시뮬레이터 빌드에서 `arm64 x86_64`를 한꺼번에 확인하다 `debug_unpack_ios`가 실패한다. 그래서 Runner 프로젝트에 `ARCHS[sdk=iphonesimulator*] = arm64`를 두었다(Apple Silicon 전용). 기기 빌드는 원래 arm64 하나라 영향이 없다.
- Xcode 27은 iOS 15.0 미만 대상을 빌드하지 않는다. `ios/Podfile`의 `post_install`에서 모든 Pod의 최소 버전을 15.0으로 맞추고 시뮬레이터 x86_64를 뺀다.
- Flutter를 올렸을 때 이 문제가 고쳐졌으면 위 두 설정은 지워도 된다.

## Firebase

- 프로젝트 ID `simple-shared-ledger`, Blaze(종량제). 앱은 Android `com.ahn.sharedledger`, iOS `com.ahn.SharedLedger`로 등록돼 있다.
- **CLI 계정:** 이 폴더는 `firebase login:use`로 프로젝트 소유 계정이 지정돼 있다. 이 컴퓨터의 로컬 설정이라 저장소에는 없고, 명령에 `--account`를 붙이지 않아도 된다. 새 컴퓨터에서는 프로젝트 소유 계정으로 `firebase login`한 뒤 이 폴더에서 `firebase login:use <그 계정>`을 한 번 실행한다. 다른 프로젝트가 쓰는 전역 기본 계정은 바꾸지 않는다.
- 설정 파일(`lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, `firebase.json`)은 아래 명령으로 다시 만든다. 비밀 값은 아니지만, 출시 전에 App Check로 보호한다.

```bash
flutterfire configure --project=simple-shared-ledger --platforms=android,ios --ios-bundle-id=com.ahn.SharedLedger --android-package-name=com.ahn.sharedledger --yes
```

- iOS 최소 버전은 15.0이다(Firebase 요구). Podfile, Xcode 프로젝트, `ios/Flutter/AppFrameworkInfo.plist`를 같이 맞춘다.
- Firestore는 `(default)` 하나, asia-northeast3(서울), Standard, 삭제 보호 켬. 위치는 바꿀 수 없다.
- 보안 규칙은 `firestore.rules`, 색인은 `firestore.indexes.json`. 배포는 이렇게 한다.

```bash
firebase deploy --only firestore:rules --project simple-shared-ledger
```

- Firestore는 Google Cloud 지출 한도(cap) 대상이 아니다. 읽기가 폭주하지 않게 리스너 범위와 쿼리를 좁게 짠다.
- 데이터 구조와 역할별 권한은 `docs/firestore.md`. 관리자는 `ownerUid`, 나머지 구성원은 `roles`(editor·viewer), 목록 조회용 `memberUids`.
- **실제 프로젝트에는 아직 '전부 막기' 규칙이 올라가 있다.** 저장소의 `firestore.rules`는 로그인을 붙일 때 배포한다.

### 보안 규칙 테스트

`firestore.rules`를 고치면 반드시 돌린다. `firestore-tests/`에 있고, `demo-` 프로젝트로 에뮬레이터에서만 돌아 실제 프로젝트에 닿지 않는다. 에뮬레이터는 Java 21이 필요한데 이 컴퓨터의 기본 Java는 19라서 Android Studio의 Java를 쓴다.

```bash
npm --prefix firestore-tests install
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" firebase emulators:exec --only firestore --project demo-shared-ledger "npm --prefix firestore-tests test"
```

- 테스트 설명은 한국어로, '막혀야 한다' 테스트는 통과하는 경우와 한 가지만 다르게 만든다(엉뚱한 이유로 막혀도 통과하는 일을 막기 위해).
- 앱 쪽 권한 판단(`lib/core/model/household.dart`)은 규칙과 같은 내용이어야 한다.

## 규칙

- 주석·문서·테스트 설명은 한국어, 코드 식별자는 영어.
- **계산 규칙을 바꾸면 `test/core/budget/sheet_golden_test.dart`가 계속 통과해야 한다.** 정답이 달라지는 변경이면 시트 수식과 어긋나는 게 의도한 것인지 먼저 확인한다.
- **공개 저장소다. 실제 가계부 금액·이름·개인 이메일을 넣지 않는다.** 시트 픽스처는 기존 시트와 같은 구성(항목 수, 분류, 결제수단, 지급 여부)에 금액만 가상으로 넣은 것이다.
- 서버는 Firebase Blaze(종량제)만 쓴다. 고정 월 요금이 드는 서비스(Supabase Pro 등)는 제안하지 않는다.
- 패키지는 그 기능을 만드는 단계에서 추가한다. 미리 넣어 두지 않는다.
