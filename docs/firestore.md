# Firestore 데이터 구조와 권한

규칙 원본은 [`firestore.rules`](../firestore.rules), 규칙 테스트는 [`firestore-tests/`](../firestore-tests).
이 문서와 규칙이 어긋나면 규칙이 기준이다.

## 역할

| 역할 | 누가 | 할 수 있는 것 |
|---|---|---|
| 관리자(owner) | 가계부를 만든 사람, 가계부마다 한 명 | 읽기·쓰기, 이름 변경, 구성원 역할 변경·내보내기, 초대 만들기·지우기, 가계부 삭제 |
| 편집자(editor) | 초대로 들어온 사람 | 읽기·쓰기, 스스로 나가기 |
| 보기 전용(viewer) | 초대로 들어온 사람 | 읽기, 스스로 나가기 |

- 커플·부부 가계부라 **한 가계부에는 두 명까지** 들어온다. 관리자 한 명과 초대로 들어온 한 명이다(규칙의 `maxMembers()`, 앱의 `ledgerMaxMembers`).
- 구성원은 **초대 코드로만** 들어온다. 관리자도 다른 사람을 직접 추가할 수 없다.
- 관리자는 자기 역할을 내려놓을 수 없다. 관리자 넘기기는 나중에 만든다.

## 컬렉션

```
ledgers/{ledgerId}
  members/{id}
  categories/{id}
  paymentMethods/{id}
  templates/{id}
  months/{yyyy-MM}/
    incomes/{id}
    planned/{templateId}
    extras/{id}
    cardBills/{id}
  activity/{id}
invites/{code}
```

### `ledgers/{ledgerId}`

| 필드 | 타입 | 설명 |
|---|---|---|
| `name` | string (1~40자) | 가계부 이름 |
| `ownerUid` | string | 관리자 uid |
| `roles` | map uid → `'editor'` \| `'viewer'` | 관리자를 뺀 구성원의 역할 |
| `memberUids` | list<string> | 관리자 + `roles`의 uid 전부. '내 가계부 목록' 조회(`array-contains`)용. 두 명까지 |
| `inviteCode` | string (선택) | 마지막으로 참여에 쓰인 초대 코드. 참여 규칙 확인용 |
| `createdAt`, `updatedAt` | timestamp | 서버 시간 |

`memberUids`는 항상 `ownerUid` + `roles`의 키와 같아야 하고, 규칙이 이를 확인한다.

### `invites/{code}`

문서 id가 초대 코드다. 앱이 추측하기 어려운 무작위 문자열로 만든다.

| 필드 | 타입 | 설명 |
|---|---|---|
| `ledgerId` | string | 초대할 가계부 |
| `role` | `'editor'` \| `'viewer'` | 들어오면 받을 역할 |
| `createdBy` | string | 만든 관리자 uid |
| `createdAt` | timestamp | 서버 시간 |
| `expiresAt` | timestamp | 만든 때부터 7일 이내 |

- 코드를 아는 사람만 한 건씩 읽을 수 있고, 목록 조회는 막는다.
- 관리자만, 자리가 남은(혼자인) 가계부에만 만들 수 있다.
- 유효기간 안에는 다시 쓸 수 있지만, 가계부가 두 명으로 차면 더는 들어올 수 없다. 관리자가 지우면 바로 못 쓴다.

참여는 가계부 문서 하나를 고치는 것으로 한다(자리가 남아 있을 때만): `memberUids`에 자기 uid 추가, `roles`에 초대의 역할로 자기 추가, `inviteCode`에 코드, `updatedAt`에 서버 시간.

### 가계부 설정: `members`, `categories`, `paymentMethods`, `templates`

가계부를 만들 때 가계부 문서와 **같은 일괄 쓰기(WriteBatch)** 로 이름표 두 장, 기본 분류, 기본 결제수단을 넣는다
(`LedgerRepository.create`, 기본값은 `defaultSettingDocs`). 설정을 만드는 규칙은 `getAfter`로 일괄 쓰기가 끝난 뒤의
가계부를 보고 권한을 확인한다. 그래서 아직 없는 가계부의 설정도 같은 일괄 쓰기 안에서는 만들 수 있고, 남의 가계부에는 만들 수 없다.

규칙은 공통 기록 필드와 이름표의 id·이름 길이, 고정 지출(`templates`)의 필드를 확인한다. 분류·결제수단의 나머지 필드는
앱의 모델([`lib/core/model`](../lib/core/model))과 변환 함수(`lib/core/data/settings_repository.dart`)를 따르고, 모르는 값은 앱이 건너뛴다.

**`members/{owner|partner}`**: 두 사람의 이름표

| 필드 | 타입 | 설명 |
|---|---|---|
| `name` | string (1~10자) | 화면에 보일 이름. 관리자는 로그인 이름(10자까지, 없으면 '나'), 상대는 '상대'로 시작한다 |

- 문서 id는 `owner`(관리자)와 `partner`(초대로 들어온 사람) 두 개뿐이다(규칙의 `validMember`, 앱의 `MemberSlot`).
- 항목의 '누가'는 이 id로 적는다. 그래서 상대가 들어오기 전에도 상대 몫을 적을 수 있다.

**`categories/{id}`**: 지출 분류

| 필드 | 타입 | 설명 |
|---|---|---|
| `name` | string | 분류 이름 |
| `countsAsSaving` | bool | 이 분류의 기본 지출을 월 요약의 '저축'에 넣을지 |
| `order` | int | 보여줄 순서. 앱이 정렬한다(없으면 맨 뒤) |

기본값은 시트와 같은 4개다: 대출원금(저축), 대출이자, 저축/투자(저축), 소비.

**`paymentMethods/{id}`**: 결제수단

| 필드 | 타입 | 설명 |
|---|---|---|
| `name` | string | 결제수단 이름 |
| `kind` | `'account'` \| `'autoTransfer'` \| `'card'` | 계산에서는 카드인지만 본다 |
| `order` | int | 보여줄 순서 |

기본값은 공동 통장(`account`)과 자동이체(`autoTransfer`)다. 카드는 사람마다 달라 직접 추가한다.

**`templates/{id}`**: 고정 지출. 매달 나가는 돈이고, 이 목록으로 그달 기본 월 지출을 만든다

| 필드 | 타입 | 설명 |
|---|---|---|
| `title` | string (1~40자) | 이름. 그달 기본 월 지출의 제목이 된다 |
| `amount` | int (0 이상, 선택) | 매달 금액(원). 없으면 금액 미정 |
| `categoryId` | string | 분류 문서 id |
| `paymentMethodId` | string | 결제수단 문서 id |
| `memberId` | `'owner'` \| `'partner'` | 누구 몫인지 |
| `dueDay` | int (1~31) | 매달 예정일. 31은 말일이고, 그달에 없는 날(2월 30일)은 그달 말일이 된다 |

- 규칙(`validTemplate`)이 위 필드와 공통 기록 필드만 받고 값의 범위를 확인한다. 앱의 쓰기 데이터는 `newTemplateData`·`templateUpdateData`
  (`lib/core/data/templates_repository.dart`, 고칠 때 비운 금액은 `FieldValue.delete()`)다.
- 고정 지출은 온라인에서만 바꾼다. 더하기·고치기·지우기·되돌리기(같은 id로 다시 만들기)가 모두 트랜잭션이라 연결이 없으면 실패한다.
- 고치거나 지워도 이미 만든 달의 기본 월 지출은 그대로다. 지운 고정 지출은 새 달에 만들지 않는다.

설정 문서가 생기기 전(2026-10-22 이전)에 만든 가계부에는 이름표가 없다. 앱은 이름표가 없으면 역할 이름('관리자', '상대')으로 보여준다.

### 가계부 항목: `months/{yyyy-MM}/incomes|planned|extras|cardBills`

- 한 달은 달력 1일~말일이다(앱의 `YearMonth`).
- 달 문서(`months/{yyyy-MM}`) 자체는 만들지 않고 하위 컬렉션만 쓴다. 달 id는 `2026-10` 형식이어야 한다.
- `planned`의 문서 id는 템플릿 id다. 두 사람이 동시에 그달을 처음 열어도 같은 문서를 만들어 중복이 생기지 않는다.
  + 버튼으로 직접 더한 기본 월 지출은 새 id를 쓴다.
- `amount`: 0 이상의 정수(원). `planned`만 비어 있을 수 있다(금액 미정).
- `deletedAt`: 휴지통에 넣은 시간. 비어 있으면 정상 항목. **휴지통에 있는 항목만 완전히 지울 수 있다.**
  - 휴지통에 넣을 때만 서버 시간으로 쓰고, 꺼낼 때는 필드를 지운다(`FieldValue.delete()`). `null`로 쓰지 않는다.
  - 방금 넣어 아직 서버에 닿지 않은 문서는 서버 시간이 null로 읽힌다. 앱은 고친 내용이 서버에 닿기 전이면
    필드가 있기만 해도 휴지통으로 본다(`entryIsTrashed`).
- 휴지통 항목은 합계에서 뺀다. 앱은 그달 네 컬렉션을 구독해 휴지통 항목을 앱에서 거른다
  (`where('deletedAt', isNull)`은 필드가 없는 문서를 빼 버린다). 휴지통 항목도 읽기 횟수에 들어간다.

규칙(`validEntry`)은 아래 표의 필드만 받고(종류마다 `keys().hasOnly`), 만들 때와 고칠 때 모두 고친 뒤의 문서 전체를 본다.

- `memberId`는 `owner`·`partner`만, 표에서 ✓인 id 칸(`categoryId`·`paymentMethodId`·`cardId`)은 비지 않은 문자열이어야 한다.
- `title`은 카드대금 말고 꼭 있어야 하고 1~40자, `memo`는 200자까지, 날짜는 `yyyy-MM-dd` 형식 문자열이다.
  규칙의 문자열 길이는 UTF-16 단위로 세서 이모지는 한 개가 두 글자다. 앱도 `String.length`로 센다(`entryTitleMaxLength`).
- 앱의 쓰기 데이터는 `newEntryData`·`entryUpdateData`(고칠 때 비운 칸은 `FieldValue.delete()`)·`trashEntryUpdate`·`restoreEntryUpdate`다.
- 그래도 앱은 읽을 때 계산에 쓰는 값(누가·금액·분류·결제수단·카드)이 없거나 잘못된 문서는 건너뛰고, 제목·메모·날짜는 잘못돼도 비워 두고 항목을 살린다.

오프라인에서는 새 항목만 더할 수 있다(`docs/plan.md`). 앱은 새 항목을 서버 응답을 기다리지 않고 기기 캐시에 넣고,
서버가 나중에 거부하면(`permission-denied`) 저장소의 `rejectedAdds`로 알려 홈 화면이 스낵바로 알린다(항목은 목록에서 빠진다).
고치기·휴지통·꺼내기는 트랜잭션으로 해서 연결이 없으면 실패하게 하고, 그사이 상대가 휴지통에 넣은(꺼낸) 항목은 고치지 않는다.

| 필드 | `incomes` | `planned` | `extras` | `cardBills` | 설명 |
|---|---|---|---|---|---|
| `memberId` | ✓ | ✓ | ✓ | ✓ | 누구 몫인지. 이름표 id(`owner`·`partner`) |
| `amount` | ✓ | 비울 수 있음 | ✓ | ✓ | 0 이상의 정수(원) |
| `title` | ✓ | ✓ | ✓ | | 항목 이름 |
| `categoryId` | | ✓ | | | 분류 문서 id |
| `paymentMethodId` | | ✓ | ✓ | | 결제수단 문서 id. 카드면 그달 현금 유출이 아니라 다음 달 청구 예정이다 |
| `cardId` | | | | ✓ | 출금된 카드의 결제수단 문서 id |
| 날짜 | `receivedOn` 받은 날 | `paidOn` 지급한 날 | `spentOn` 쓴 날 | `paidOn` 출금일 | `2026-10-25` 형식 문자열(선택). 날짜만 필요해서 두 사람의 시간대가 달라도 바뀌지 않게 문자열로 둔다 |
| `dueOn` | | 선택 | | | 고정 지출에서 옮긴 그달 예정일(`2026-10-31` 형식). 계산에는 쓰지 않고, 지급 전 줄에 '말일 예정'처럼 보여준다 |
| `memo` | 선택 | 선택 | 선택 | 선택 | 메모 |
| `deletedAt` | 선택 | 선택 | 선택 | 선택 | 휴지통에 넣은 시간 |

- `planned`의 `paidOn`이 있어야 카드가 아닌 기본 지출이 현금 유출에 들어간다(`docs/plan.md`의 '계산 규칙').

### 고정 지출로 그달 기본 월 지출 만들기

- 요약·항목 탭에서 **이번 달이나 다음 달**을 보면, 그달에 아직 없는 고정 지출의 기본 월 지출을 만든다(홈 틀의 `MonthFillController`).
  지난 달과 다음 달보다 먼 달은 만들지 않는다(필요하면 + 버튼으로 직접 적는다).
- '아직 없는'은 그달 `planned`에 그 템플릿 id의 문서가 없다는 뜻이다. 휴지통에 넣은 문서도 있는 것으로 보고 다시 만들지 않는다.
  그래서 새로 더한 고정 지출은 그달을 볼 때 바로 들어가고, 고친 값은 앞으로 만들 달부터 쓴다.
- 앱은 그달 구독(`MonthLedger.plannedIds`, 휴지통 포함)으로 빠진 것을 고르고, 빠진 것이 있을 때만
  `EntriesRepository.fillPlanned` 트랜잭션에서 그 문서들을 서버에서 다시 읽어 없을 때만 만든다. 이미 있는 문서는 덮어쓰지 않는다.
  규칙으로도 이미 있는 문서를 새로 만드는 값(`createdNow`)으로 덮어쓸 수 없다.
- 만든 기본 월 지출은 지급 전이고, 제목·금액·분류·결제수단·누가와 그달 예정일(`dueOn`)을 옮긴다.
- 트랜잭션이라 오프라인에서는 만들지 못한다. 연결이 없으면 다음에 그달을 다시 볼 때 만든다.
- 휴지통의 기본 월 지출을 완전히 지우면(설정 단계에서 만든다) 그 템플릿의 문서가 없어져 이번 달·다음 달이면 다시 만들어진다.

### 공통 기록 필드 (설정·항목 모두)

| 필드 | 만들 때 | 고칠 때 |
|---|---|---|
| `createdBy` | 내 uid | 바꿀 수 없음 |
| `createdAt` | 서버 시간 | 바꿀 수 없음 |
| `updatedBy` | 내 uid | 내 uid |
| `updatedAt` | 서버 시간 | 서버 시간 |

앱에서는 시간 필드에 `FieldValue.serverTimestamp()`를 넣어야 규칙을 통과한다.

### `activity/{id}`: 변경 기록

| 필드 | 타입 | 설명 |
|---|---|---|
| `actorUid` | string | 바꾼 사람 (내 uid만 가능) |
| `at` | timestamp | 서버 시간 |
| `action` | string | 예: `entry.create`, `entry.trash` |
| `summary` | string | 화면에 보일 한 줄 |

추가만 가능하고 고치거나 지울 수 없다.

## 비용 메모

- 하위 컬렉션 규칙은 가계부 문서를 한 번 읽어 권한을 확인한다. 이 읽기도 Firestore 읽기 횟수에 들어간다.
- 가계부를 지워도 하위 컬렉션은 남는다. 정리는 나중에 함수나 앱에서 처리한다.
- 보기 전용 구성원은 그달의 기본 지출을 만들 수 없다. 편집자나 관리자가 먼저 그달을 열어야 생긴다.
- 그달을 열 때마다 기본 월 지출 문서를 따로 읽지 않는다. 빠진 고정 지출이 있을 때만 그 문서 수만큼 트랜잭션에서 읽는다.
