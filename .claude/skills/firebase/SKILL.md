---
name: firebase
description: 심플 공유 가계부(shared_ledger)의 Firebase 설정을 다룰 때 쓴다. Firestore 보안 규칙 배포, 로그인 제공자(Google·Apple) 설정, FlutterFire 설정 파일 다시 만들기, Firebase CLI 계정, Firebase 패키지 버전 올리기, 비용·예산이 해당된다. "규칙 배포해줘", "Android에서 Apple 로그인 되게 해줘", "flutterfire configure 다시 해줘", "Firebase 패키지 올려도 돼?" 같은 요청에 쓴다.
---

# Firebase

데이터 구조와 역할별 권한은 `docs/firestore.md`, 비용·예산 결정은 `docs/plan.md`의 '출시 요건과 비용'이 원본이다.

## 프로젝트

- 프로젝트 ID `simple-shared-ledger`, Blaze(종량제). 앱은 Android `com.ahn.sharedledger`, iOS `com.ahn.SharedLedger`로 등록돼 있다.
- Firestore는 `(default)` 하나, asia-northeast3(서울), Standard, 삭제 보호 켬. 위치는 바꿀 수 없다.
- Firestore는 지출 한도(cap) 대상이 아니다. 읽기 횟수가 곧 비용이라 리스너 범위와 쿼리를 좁게 짠다.

## CLI 계정

이 폴더는 `firebase login:use`로 프로젝트 소유 계정이 지정돼 있다. 이 컴퓨터의 로컬 설정이라 저장소에는 없고,
명령에 `--account`를 붙이지 않아도 된다.

- 새 컴퓨터에서는 프로젝트 소유 계정으로 `firebase login`한 뒤 이 폴더에서 `firebase login:use <그 계정>`을 한 번 실행한다.
- 다른 프로젝트가 쓰는 전역 기본 계정은 바꾸지 않는다. 계정 이메일을 저장소에 적지 않는다.

## 설정 파일 다시 만들기

`lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, `firebase.json`은
아래 명령으로 다시 만든다. 비밀 값은 아니며, 출시 전에 App Check로 보호한다.

```bash
flutterfire configure --project=simple-shared-ledger --platforms=android,ios --ios-bundle-id=com.ahn.SharedLedger --android-package-name=com.ahn.sharedledger --yes
```

- `flutterfire configure`는 `firebase.json`을 한 줄로 압축해 다시 쓴다. 실행한 뒤 펼친다.

```bash
node -e "const f=require('fs');f.writeFileSync('firebase.json',JSON.stringify(JSON.parse(f.readFileSync('firebase.json','utf8')),null,2)+'\n')"
```

- 다시 만든 뒤 iOS `Info.plist`의 URL 스킴이 새 `GoogleService-Info.plist`의 `REVERSED_CLIENT_ID`와 같은지 확인한다.

## 패키지 버전

Firebase 패키지는 4.x 세대에 고정했다(firebase_core 4.15, firebase_auth 6.7, cloud_firestore 6.10).

- firebase_core 5(Firebase iOS SDK 13)는 google_sign_in_ios 6.3.8(GoogleSignIn 9)과 `gtm-session-fetcher` 버전 범위가
  겹치지 않아 Swift Package Manager가 의존성을 풀지 못하고 iOS 빌드가 실패한다(2026-10-21 확인).
- 올리려면 google_sign_in_ios가 GoogleSignIn 10(gtm-session-fetcher 4 이상)을 지원하는지 먼저 확인하고,
  `fvm flutter build ios --simulator --debug`까지 통과시킨다.
- iOS 최소 버전은 15.0이다(Firebase 요구). Xcode 프로젝트와 `ios/Flutter/AppFrameworkInfo.plist`를 같이 맞춘다.

## 보안 규칙 배포

저장소의 `firestore.rules`가 실제 프로젝트에 배포돼 있다. 마지막 배포는 2026-10-22, PR #9의 기본 설정 일괄 만들기(getAfter)·이름표 규칙이다.

1. 규칙 테스트를 먼저 고치고 통과시킨다(명령은 verification 스킬).
2. PR이 `main`에 합쳐진 뒤 배포한다. 합쳐지기 전 브랜치의 규칙을 배포하지 않는다.

```bash
firebase deploy --only firestore:rules --project simple-shared-ledger
```

색인을 바꿨으면 `--only firestore:indexes`도 배포한다.

## 로그인 제공자

| 제공자 | Android | iOS | 설정 |
| --- | --- | --- | --- |
| Google | 됨 | 됨 | Firebase Authentication에서 켬 |
| Apple | 안 됨 | 됨 | Firebase에서 켬(서비스 ID 없이) |

- **Android Google 로그인**은 앱 서명 키의 SHA-1·SHA-256이 Firebase Android 앱에 등록돼 있어야 한다.
  이 컴퓨터의 디버그 키는 등록했다. 출시용(Play 앱 서명) 키 지문은 Play Console에서 받아 따로 등록한다.
- **iOS Google 로그인**은 `Info.plist`의 URL 스킴(`REVERSED_CLIENT_ID`)으로 돌아온다.
- **iOS Apple 로그인** 권한은 `ios/Runner/Runner.entitlements`에 있다. 기기 빌드에는 Sign in with Apple을 켠 개발 팀이 필요하다.
- **Android Apple 로그인**은 웹 방식(OAuth)이라 Apple 개발자 사이트의 Services ID, 반환 URL, 키(.p8)가 필요하고,
  그 값을 Firebase Authentication의 Apple 제공자에 넣는다. 키 파일과 키 ID는 저장소에 넣지 않는다.
- Apple 개발자 사이트·Firebase 콘솔 설정은 사용자가 직접 한다. 필요한 값과 순서를 안내하고, 계정 정보를 대신 입력하지 않는다.
