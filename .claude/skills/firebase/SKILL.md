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

저장소의 `firestore.rules`가 실제 프로젝트에 배포돼 있다. 마지막 배포는 2026-10-26, PR #23의 항목 있는 달 목록(`months`) 규칙
(`recordsMonths`, 가계부 만들기의 빈 `months`)이다. 같은 날 앞서 PR #21의 공휴일(`holidays`) 읽기 규칙을 배포했다.
`months` 규칙을 배포하기 전에는 앱이 달 목록을 저장하지 못해(permission-denied) 모든 달을 그대로 보여준다.
TTL 정책 5개(`firestore:indexes`)는 2026-10-23 PR #15 때 배포했다.

1. 규칙 테스트를 먼저 고치고 통과시킨다(명령은 verification 스킬).
2. PR이 `main`에 합쳐진 뒤 배포한다. 합쳐지기 전 브랜치의 규칙을 배포하지 않는다.

```bash
firebase deploy --only firestore:rules --project simple-shared-ledger
```

색인을 바꿨으면 `--only firestore:indexes`도 배포한다.

## Cloud Functions

`functions/`(TypeScript, Node 22, 서울 지역). 지금은 공휴일을 받아 두는 `syncHolidays` 하나다(`docs/firestore.md`의 holidays).

- 검사: `npm --prefix functions test`(타입 검사·빌드 + 응답 해석 테스트). CI의 'Cloud Functions 빌드·테스트' job과 같다.
- 공공데이터포털 인증키는 Secret Manager의 `HOLIDAY_API_KEY`에 있다. 저장소·로그에 남기지 않는다. 처음이나 키를 바꿀 때 사용자가 직접 넣는다.
  포털 마이페이지의 일반 인증키는 Encoding·Decoding 어느 쪽이든 된다(화면에 Encoding만 보이기도 한다. 함수가 `%`가 든 키를 풀어 쓴다).
- 새로 넣은 키는 **함수를 다시 배포해야** 쓴다. 함수는 배포할 때의 비밀 버전에 고정되고, `secrets:set --force`도 함수를 바꾸지 않는다
  (CLI가 'stale version'이라고 알린다).

```bash
firebase functions:secrets:set HOLIDAY_API_KEY --project simple-shared-ledger
firebase deploy --only functions --project simple-shared-ledger
```

- 배포는 PR이 `main`에 합쳐진 뒤 한다. 비밀을 먼저 넣어야 배포가 된다. 처음 배포 때 필요한 Google Cloud API(Functions, Cloud Build,
  Artifact Registry, Cloud Scheduler, Cloud Run, Eventarc)는 CLI가 켰고(2026-10-26), 함수 이미지 정리 정책(1일)도 설정했다
  (`firebase functions:artifacts:setpolicy --location asia-northeast3`).
- Google Cloud 콘솔은 프로젝트 소유 계정(CLI 계정과 같다)으로 열어야 이 프로젝트가 보인다. 다른 계정이면 목록에 다른 프로젝트만 나온다.
- 배포 직후에는 다음 날 새벽 4시 전까지 공휴일이 없다. 바로 채우려면 Google Cloud 콘솔 → Cloud Scheduler에서
  `firebase-schedule-syncHolidays-asia-northeast3` 작업을 '강제 실행'한다. 함수를 배포하는 도중에 누르면 거부되니 배포가 끝난 뒤 누른다.
- 실행 결과: 스케줄러 쪽은 로그 탐색기의 `resource.type="cloud_scheduler_job"`(AttemptFinished가 '정보'면 성공, '오류'면 실패),
  함수 쪽은 `firebase functions:log --only syncHolidays`. 실패 로그에는 특일 API의 거부 사유(`SERVICE_KEY_IS_NOT_REGISTERED_ERROR` 등)가 남는다.
  `SERVICE_KEY_IS_NOT_REGISTERED_ERROR`는 키가 틀렸거나 아직 활성화 전(발급 뒤 1~2시간)이다.
- 앱에서 확인: 달력 2026년 10월의 3일(토, 개천절)이 빨간색이면 `holidays/2026`을 받은 것이다(앱 안에 공휴일 표는 없다).
- 특일 API 개발계정은 하루 10,000건이다. 함수는 하루 24건(두 해 × 12달)을 부른다.

## 비용·예산

- Google Cloud 콘솔 → 결제 → 예산 및 알림(Budgets & alerts). 지금은 '알림만' 예산(₩5,000, 프로젝트 전체)과
  Cloud Run functions 지출 한도 예산(2026-10-26) 두 개가 있다(`docs/plan.md`의 '출시 요건과 비용').
- 지출 한도(spend cap) 예산: '예산 만들기' → **Spend cap enforcement** → 범위에 프로젝트 `simple-shared-ledger` 1개와 서비스 1개
  → 금액 → 완료. 추정 비용이 금액을 넘으면 그 서비스의 새 사용을 그달 끝까지 멈추고 다음 달 1일에 풀린다.
  - 바로 멈추지는 않는다. 비용 보고가 늦어 멈추기 전까지 넘은 금액은 그대로 청구되니, 금액은 넘어도 괜찮은 선보다 낮게 잡는다.
  - 수동으로 풀 수도 있다(예산 편집 → Lift spend cap). 풀고 나서 정상으로 돌아오기까지 최대 1시간 걸린다.
  - 한 예산에 프로젝트·서비스가 하나씩이다. 공휴일 함수는 서비스 **Cloud Run functions**로 건다.
  - Firestore, Cloud Build, Cloud Scheduler, Artifact Registry, Secret Manager는 한도 대상이 아니다(2026-10 기준). 알림 예산과 읽기 관리로 막는다.
  - 권한: 결제 계정 관리자(또는 결제 계정 비용 관리자 + 프로젝트 편집자)이거나, 프로젝트 수준의
    `billing.resourcebudgets.read`·`write`·`configureSpendCap` 권한이 있으면 된다. 예산은 사용자가 프로젝트 소유 계정으로 콘솔에서 직접 만든다.

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
