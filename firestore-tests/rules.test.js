// Firestore 보안 규칙 테스트. 에뮬레이터에서만 돈다 (demo- 프로젝트라 실제 프로젝트에 닿지 않음).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  arrayRemove,
  arrayUnion,
  collection,
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

const OWNER = 'owner-uid';
const EDITOR = 'editor-uid';
const VIEWER = 'viewer-uid';
const OUTSIDER = 'outsider-uid';
const NEWCOMER = 'newcomer-uid';

// 한 가계부에는 두 명까지 들어온다.
const LEDGER = 'ledger-1'; // 관리자 + 편집자 (가득 참)
const VIEWER_LEDGER = 'ledger-viewer'; // 관리자 + 보기 전용
const SOLO_LEDGER = 'ledger-solo'; // 관리자 혼자
const OTHER_LEDGER = 'ledger-2'; // OUTSIDER 혼자
const MONTH = '2026-10';
const DAY = 24 * 60 * 60 * 1000;

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-shared-ledger',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await seed(async (db) => {
    await setDoc(ledgerRef(db), ledgerData(OWNER, { [EDITOR]: 'editor' }));
    await setDoc(ledgerRef(db, VIEWER_LEDGER), ledgerData(OWNER, { [VIEWER]: 'viewer' }));
    await setDoc(ledgerRef(db, SOLO_LEDGER), ledgerData(OWNER, {}));
    await setDoc(ledgerRef(db, OTHER_LEDGER), ledgerData(OUTSIDER, {}));
  });
});

function firestoreAs(uid) {
  const context = uid ? env.authenticatedContext(uid) : env.unauthenticatedContext();
  return context.firestore();
}

function seed(callback) {
  return env.withSecurityRulesDisabled((context) => callback(context.firestore()));
}

function ledgerRef(db, id = LEDGER) {
  return doc(db, 'ledgers', id);
}

function ledgerData(ownerUid, roles, name = '우리 가계부') {
  return {
    name,
    ownerUid,
    roles,
    memberUids: [ownerUid, ...Object.keys(roles)],
    createdAt: Timestamp.fromMillis(0),
    updatedAt: Timestamp.fromMillis(0),
  };
}

function newLedger(ownerUid, fields = {}) {
  return {
    name: '새 가계부',
    ownerUid,
    roles: {},
    memberUids: [ownerUid],
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...fields,
  };
}

function entryRef(db, { type = 'extras', id = 'entry-1', month = MONTH, ledger = LEDGER } = {}) {
  return doc(db, 'ledgers', ledger, 'months', month, type, id);
}

// 종류마다 앱이 쓰는 필드(docs/firestore.md의 항목 표). 날짜·메모는 선택이라 뺐다.
const ENTRY_FIELDS = {
  incomes: { memberId: 'owner', title: '월급', amount: 3000000 },
  planned: { memberId: 'owner', title: '관리비', categoryId: 'c1', paymentMethodId: 'p1', amount: 200000 },
  extras: { memberId: 'owner', title: '장보기', paymentMethodId: 'card', amount: 10000 },
  cardBills: { memberId: 'owner', cardId: 'card', amount: 500000 },
};

function newEntryOf(type, uid, fields = {}) {
  return {
    ...ENTRY_FIELDS[type],
    createdBy: uid,
    updatedBy: uid,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...fields,
  };
}

// 추가지출 한 건.
function newEntry(uid, fields = {}) {
  return newEntryOf('extras', uid, fields);
}

function seedEntry({ ledger = LEDGER, ...fields } = {}) {
  return seed((db) =>
    setDoc(entryRef(db, { ledger }), {
      ...newEntry(OWNER),
      createdAt: Timestamp.fromMillis(1000),
      updatedAt: Timestamp.fromMillis(1000),
      ...fields,
    }),
  );
}

function inviteRef(db, code) {
  return doc(db, 'invites', code);
}

// 참여 테스트용 초대. 기본은 자리가 남은 OTHER_LEDGER.
function seedInvite(code, fields = {}) {
  return seed((db) =>
    setDoc(inviteRef(db, code), {
      ledgerId: OTHER_LEDGER,
      role: 'editor',
      createdBy: OUTSIDER,
      createdAt: Timestamp.now(),
      expiresAt: Timestamp.fromMillis(Date.now() + 3 * DAY),
      ...fields,
    }),
  );
}

function joinUpdate(uid, role, code) {
  return {
    [`roles.${uid}`]: role,
    memberUids: arrayUnion(uid),
    inviteCode: code,
    updatedAt: serverTimestamp(),
  };
}

describe('가계부 만들기와 읽기', () => {
  test('로그인하면 자기를 관리자로 하는 가계부를 만들 수 있다', async () => {
    await assertSucceeds(setDoc(ledgerRef(firestoreAs(NEWCOMER), 'new-ledger'), newLedger(NEWCOMER)));
  });

  test('다른 사람을 관리자로 하거나 구성원을 미리 넣어서 만들 수 없다', async () => {
    const db = firestoreAs(NEWCOMER);
    await assertFails(
      setDoc(ledgerRef(db, 'l-a'), newLedger(NEWCOMER, { ownerUid: OUTSIDER, memberUids: [OUTSIDER] })),
    );
    await assertFails(
      setDoc(
        ledgerRef(db, 'l-b'),
        newLedger(NEWCOMER, { roles: { [OUTSIDER]: 'editor' }, memberUids: [NEWCOMER, OUTSIDER] }),
      ),
    );
  });

  test('로그인하지 않으면 가계부를 만들 수 없다', async () => {
    await assertFails(setDoc(ledgerRef(firestoreAs(null), 'l-anon'), newLedger('anon')));
  });

  test('구성원은 가계부를 읽을 수 있고, 구성원이 아니면 읽을 수 없다', async () => {
    for (const uid of [OWNER, EDITOR]) {
      await assertSucceeds(getDoc(ledgerRef(firestoreAs(uid))));
    }
    await assertFails(getDoc(ledgerRef(firestoreAs(OUTSIDER))));
  });

  test('내가 속한 가계부만 목록으로 조회할 수 있다', async () => {
    const db = firestoreAs(EDITOR);
    const mine = await assertSucceeds(
      getDocs(query(collection(db, 'ledgers'), where('memberUids', 'array-contains', EDITOR))),
    );
    if (mine.size !== 1) throw new Error(`가계부 1개를 기대했지만 ${mine.size}개`);
    await assertFails(getDocs(collection(db, 'ledgers')));
  });
});

describe('구성원 관리', () => {
  test('관리자는 이름과 역할을 바꾸고 구성원을 내보낼 수 있다', async () => {
    const db = firestoreAs(OWNER);
    await assertSucceeds(
      updateDoc(ledgerRef(db), {
        name: '새 이름',
        [`roles.${EDITOR}`]: 'viewer',
        updatedAt: serverTimestamp(),
      }),
    );
    await assertSucceeds(
      updateDoc(ledgerRef(db), {
        [`roles.${EDITOR}`]: deleteField(),
        memberUids: arrayRemove(EDITOR),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('관리자도 자리가 남은 가계부에 구성원을 직접 추가할 수 없다 (초대로만)', async () => {
    await assertFails(
      updateDoc(ledgerRef(firestoreAs(OWNER), SOLO_LEDGER), {
        [`roles.${NEWCOMER}`]: 'editor',
        memberUids: arrayUnion(NEWCOMER),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('관리자를 늘리거나 관리자를 바꿀 수 없다', async () => {
    const db = firestoreAs(OWNER);
    await assertFails(
      updateDoc(ledgerRef(db), { [`roles.${EDITOR}`]: 'owner', updatedAt: serverTimestamp() }),
    );
    await assertFails(updateDoc(ledgerRef(db), { ownerUid: EDITOR, updatedAt: serverTimestamp() }));
  });

  test('편집자는 이름을, 보기 전용은 자기 역할을 바꿀 수 없다', async () => {
    await assertFails(
      updateDoc(ledgerRef(firestoreAs(EDITOR)), { name: '바꾼 이름', updatedAt: serverTimestamp() }),
    );
    await assertFails(
      updateDoc(ledgerRef(firestoreAs(VIEWER), VIEWER_LEDGER), {
        [`roles.${VIEWER}`]: 'editor',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('편집자와 보기 전용은 스스로 가계부에서 나갈 수 있다', async () => {
    for (const [uid, ledger] of [
      [EDITOR, LEDGER],
      [VIEWER, VIEWER_LEDGER],
    ]) {
      await assertSucceeds(
        updateDoc(ledgerRef(firestoreAs(uid), ledger), {
          [`roles.${uid}`]: deleteField(),
          memberUids: arrayRemove(uid),
          updatedAt: serverTimestamp(),
        }),
      );
    }
  });

  // 앱의 ledgerRenameUpdate(lib/core/data/ledger_repository.dart)와 같은 필드로 바꾼다.
  test('가계부 이름을 바꿀 때도 1~40자다', async () => {
    const rename = (name) => updateDoc(ledgerRef(firestoreAs(OWNER)), { name, updatedAt: serverTimestamp() });
    await assertSucceeds(rename('가'.repeat(40)));
    await assertFails(rename('가'.repeat(41)));
    await assertFails(rename(''));
  });

  test('관리자만 가계부를 삭제할 수 있다', async () => {
    await assertFails(deleteDoc(ledgerRef(firestoreAs(EDITOR))));
    await assertSucceeds(deleteDoc(ledgerRef(firestoreAs(OWNER))));
  });
});

describe('초대', () => {
  function newInvite(uid, fields = {}) {
    return {
      ledgerId: SOLO_LEDGER,
      role: 'editor',
      createdBy: uid,
      createdAt: serverTimestamp(),
      expiresAt: Timestamp.fromMillis(Date.now() + 3 * DAY),
      ...fields,
    };
  }

  test('관리자만 초대 코드를 만들 수 있다', async () => {
    await assertSucceeds(setDoc(inviteRef(firestoreAs(OWNER), 'INVITE0001'), newInvite(OWNER)));
    await assertFails(setDoc(inviteRef(firestoreAs(EDITOR), 'INVITE0002'), newInvite(EDITOR)));
  });

  test('두 명이 다 찬 가계부에는 초대 코드를 만들 수 없다', async () => {
    await assertFails(
      setDoc(inviteRef(firestoreAs(OWNER), 'INVITE0003'), newInvite(OWNER, { ledgerId: LEDGER })),
    );
  });

  test('유효기간은 7일을 넘길 수 없고, 너무 짧은 코드는 쓸 수 없다', async () => {
    const db = firestoreAs(OWNER);
    await assertFails(
      setDoc(
        inviteRef(db, 'INVITE0004'),
        newInvite(OWNER, { expiresAt: Timestamp.fromMillis(Date.now() + 8 * DAY) }),
      ),
    );
    await assertFails(setDoc(inviteRef(db, 'abc'), newInvite(OWNER)));
  });

  test('초대 코드로 초대에 적힌 역할로 참여할 수 있다', async () => {
    await seedInvite('JOINCODE01', { role: 'viewer' });
    await assertSucceeds(
      updateDoc(ledgerRef(firestoreAs(NEWCOMER), OTHER_LEDGER), joinUpdate(NEWCOMER, 'viewer', 'JOINCODE01')),
    );
  });

  test('초대보다 높은 역할로는 참여할 수 없다', async () => {
    await seedInvite('JOINCODE02', { role: 'viewer' });
    await assertFails(
      updateDoc(ledgerRef(firestoreAs(NEWCOMER), OTHER_LEDGER), joinUpdate(NEWCOMER, 'editor', 'JOINCODE02')),
    );
  });

  test('만료된 초대로는 참여할 수 없다', async () => {
    await seedInvite('JOINCODE03', { expiresAt: Timestamp.fromMillis(Date.now() - DAY) });
    await assertFails(
      updateDoc(ledgerRef(firestoreAs(NEWCOMER), OTHER_LEDGER), joinUpdate(NEWCOMER, 'editor', 'JOINCODE03')),
    );
  });

  test('다른 가계부의 초대 코드로는 참여할 수 없다', async () => {
    await seedInvite('JOINCODE04', { ledgerId: SOLO_LEDGER, createdBy: OWNER });
    await assertFails(
      updateDoc(ledgerRef(firestoreAs(NEWCOMER), OTHER_LEDGER), joinUpdate(NEWCOMER, 'editor', 'JOINCODE04')),
    );
  });

  test('두 명이 다 찬 가계부에는 초대 코드가 있어도 참여할 수 없다', async () => {
    // 자리가 있을 때 만든 초대가 남아 있는 경우.
    await seedInvite('JOINCODE05', { ledgerId: LEDGER, createdBy: OWNER });
    await assertFails(
      updateDoc(ledgerRef(firestoreAs(NEWCOMER), LEDGER), joinUpdate(NEWCOMER, 'editor', 'JOINCODE05')),
    );
  });

  test('초대 코드는 한 건씩만 읽을 수 있고 목록 조회는 막힌다', async () => {
    await seedInvite('JOINCODE06');
    const db = firestoreAs(NEWCOMER);
    await assertSucceeds(getDoc(inviteRef(db, 'JOINCODE06')));
    await assertFails(getDocs(collection(db, 'invites')));
  });

  test('관리자는 초대를 지울 수 있고, 다른 사람은 지울 수 없다', async () => {
    await seedInvite('JOINCODE07', { ledgerId: SOLO_LEDGER, createdBy: OWNER });
    await assertFails(deleteDoc(inviteRef(firestoreAs(EDITOR), 'JOINCODE07')));
    await assertSucceeds(deleteDoc(inviteRef(firestoreAs(OWNER), 'JOINCODE07')));
  });
});

describe('가계부 항목', () => {
  test('편집자는 항목을 추가하고, 관리자는 그 항목을 고칠 수 있다', async () => {
    await assertSucceeds(setDoc(entryRef(firestoreAs(EDITOR)), newEntry(EDITOR)));
    await assertSucceeds(
      updateDoc(entryRef(firestoreAs(OWNER)), {
        amount: 12000,
        updatedBy: OWNER,
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('보기 전용은 항목을 읽을 수 있지만 쓸 수 없다', async () => {
    await seedEntry({ ledger: VIEWER_LEDGER });
    const db = firestoreAs(VIEWER);
    await assertSucceeds(getDoc(entryRef(db, { ledger: VIEWER_LEDGER })));
    await assertFails(setDoc(entryRef(db, { ledger: VIEWER_LEDGER, id: 'entry-2' }), newEntry(VIEWER)));
    await assertFails(
      updateDoc(entryRef(db, { ledger: VIEWER_LEDGER }), {
        amount: 1,
        updatedBy: VIEWER,
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('다른 가계부 사람은 항목을 읽을 수도 쓸 수도 없다', async () => {
    await seedEntry();
    const db = firestoreAs(OUTSIDER);
    await assertFails(getDoc(entryRef(db)));
    await assertFails(getDocs(collection(db, 'ledgers', LEDGER, 'months', MONTH, 'extras')));
    await assertFails(setDoc(entryRef(db, { id: 'entry-2' }), newEntry(OUTSIDER)));
  });

  test('작성자와 시간을 위조할 수 없다', async () => {
    const db = firestoreAs(EDITOR);
    await assertFails(setDoc(entryRef(db), newEntry(EDITOR, { createdBy: OWNER })));
    await assertFails(setDoc(entryRef(db), newEntry(EDITOR, { createdAt: Timestamp.now() })));
  });

  test('고칠 때 처음 작성 기록을 바꾸거나 수정자를 남의 이름으로 둘 수 없다', async () => {
    await seedEntry({ createdBy: EDITOR, updatedBy: EDITOR });
    const db = firestoreAs(OWNER);
    await assertFails(
      updateDoc(entryRef(db), { createdBy: OWNER, updatedBy: OWNER, updatedAt: serverTimestamp() }),
    );
    await assertFails(updateDoc(entryRef(db), { amount: 5000, updatedAt: serverTimestamp() }));
  });

  test('금액은 0 이상의 정수여야 하고, 기본 월 지출만 비워 둘 수 있다', async () => {
    const db = firestoreAs(EDITOR);
    await assertFails(setDoc(entryRef(db, { id: 'a' }), newEntry(EDITOR, { amount: -1 })));
    await assertFails(setDoc(entryRef(db, { id: 'b' }), newEntry(EDITOR, { amount: '1000' })));
    await assertFails(setDoc(entryRef(db, { id: 'c' }), newEntry(EDITOR, { amount: 10.5 })));
    await assertFails(setDoc(entryRef(db, { id: 'd' }), newEntry(EDITOR, { amount: null })));
    await assertSucceeds(
      setDoc(entryRef(db, { type: 'planned', id: 'template-1' }), newEntryOf('planned', EDITOR, { amount: null })),
    );
  });

  test('휴지통에 넣은 항목만 완전히 지울 수 있다', async () => {
    await seedEntry();
    const db = firestoreAs(EDITOR);
    await assertFails(deleteDoc(entryRef(db)));
    await assertSucceeds(
      updateDoc(entryRef(db), {
        deletedAt: serverTimestamp(),
        updatedBy: EDITOR,
        updatedAt: serverTimestamp(),
      }),
    );
    await assertSucceeds(deleteDoc(entryRef(db)));
  });

  test('달 id가 yyyy-MM 형식이 아니면 항목을 만들 수 없다', async () => {
    const db = firestoreAs(EDITOR);
    await assertFails(setDoc(entryRef(db, { month: '2026-13' }), newEntry(EDITOR)));
    await assertFails(setDoc(entryRef(db, { month: '202610' }), newEntry(EDITOR)));
  });

  test('휴지통에서 꺼낼 때는 deletedAt 필드를 지운다', async () => {
    await seedEntry({ deletedAt: Timestamp.fromMillis(2000) });
    await assertSucceeds(
      updateDoc(entryRef(firestoreAs(EDITOR)), {
        deletedAt: deleteField(),
        updatedBy: EDITOR,
        updatedAt: serverTimestamp(),
      }),
    );
  });

  describe('종류별 필드', () => {
    test('네 종류 모두 앱이 쓰는 필드로 날짜·메모까지 넣어 만들 수 있다', async () => {
      const db = firestoreAs(EDITOR);
      const dates = { incomes: 'receivedOn', planned: 'paidOn', extras: 'spentOn', cardBills: 'paidOn' };
      for (const [type, dateField] of Object.entries(dates)) {
        await assertSucceeds(
          setDoc(entryRef(db, { type }), newEntryOf(type, EDITOR, { [dateField]: '2026-10-25', memo: '메모' })),
        );
      }
    });

    test('그 종류가 받지 않는 필드가 있으면 만들 수 없다', async () => {
      const db = firestoreAs(EDITOR);
      await assertFails(setDoc(entryRef(db), newEntry(EDITOR, { categoryId: 'c1' })));
      await assertFails(setDoc(entryRef(db), newEntry(EDITOR, { receivedOn: '2026-10-25' })));
      await assertFails(setDoc(entryRef(db), newEntry(EDITOR, { note: '모르는 필드' })));
      await assertFails(setDoc(entryRef(db, { type: 'cardBills' }), newEntryOf('cardBills', EDITOR, { title: '카드값' })));
    });

    test('누가는 owner·partner 이름표 자리만 받는다', async () => {
      const db = firestoreAs(EDITOR);
      await assertSucceeds(setDoc(entryRef(db, { id: 'a' }), newEntry(EDITOR, { memberId: 'partner' })));
      await assertFails(setDoc(entryRef(db, { id: 'b' }), newEntry(EDITOR, { memberId: EDITOR })));
      await assertFails(setDoc(entryRef(db, { id: 'c' }), newEntry(EDITOR, { memberId: null })));
    });

    test('종류마다 꼭 필요한 분류·결제수단·카드 칸이 있어야 한다', async () => {
      const db = firestoreAs(EDITOR);
      for (const [type, field] of [
        ['planned', 'categoryId'],
        ['planned', 'paymentMethodId'],
        ['extras', 'paymentMethodId'],
        ['cardBills', 'cardId'],
      ]) {
        await assertFails(setDoc(entryRef(db, { type, id: field }), newEntryOf(type, EDITOR, { [field]: null })));
        await assertFails(setDoc(entryRef(db, { type, id: field }), newEntryOf(type, EDITOR, { [field]: '' })));
      }
    });

    test('제목은 1~40자여야 한다', async () => {
      const db = firestoreAs(EDITOR);
      await assertSucceeds(setDoc(entryRef(db, { id: 'a' }), newEntry(EDITOR, { title: '가'.repeat(40) })));
      // 규칙의 size()는 UTF-16 단위로 센다. 이모지는 한 개가 두 칸이라 20개까지다(앱도 String.length로 센다).
      await assertSucceeds(setDoc(entryRef(db, { id: 'b' }), newEntry(EDITOR, { title: '🍚'.repeat(20) })));
      await assertFails(setDoc(entryRef(db, { id: 'f' }), newEntry(EDITOR, { title: '🍚'.repeat(21) })));
      await assertFails(setDoc(entryRef(db, { id: 'c' }), newEntry(EDITOR, { title: '가'.repeat(41) })));
      await assertFails(setDoc(entryRef(db, { id: 'd' }), newEntry(EDITOR, { title: '' })));
      await assertFails(setDoc(entryRef(db, { type: 'incomes', id: 'e' }), newEntryOf('incomes', EDITOR, { title: null })));
    });

    test('메모는 200자까지 받는다', async () => {
      const db = firestoreAs(EDITOR);
      await assertSucceeds(setDoc(entryRef(db, { id: 'a' }), newEntry(EDITOR, { memo: '가'.repeat(200) })));
      await assertFails(setDoc(entryRef(db, { id: 'b' }), newEntry(EDITOR, { memo: '가'.repeat(201) })));
      await assertFails(setDoc(entryRef(db, { id: 'c' }), newEntry(EDITOR, { memo: 3 })));
    });

    test('날짜는 yyyy-MM-dd 문자열이어야 한다', async () => {
      const db = firestoreAs(EDITOR);
      await assertSucceeds(setDoc(entryRef(db, { id: 'a' }), newEntry(EDITOR, { spentOn: '2026-10-18' })));
      await assertFails(setDoc(entryRef(db, { id: 'b' }), newEntry(EDITOR, { spentOn: '2026/10/18' })));
      await assertFails(setDoc(entryRef(db, { id: 'c' }), newEntry(EDITOR, { spentOn: Timestamp.now() })));
    });

    test('고칠 때도 고친 뒤의 문서를 같은 기준으로 본다', async () => {
      await seedEntry();
      const db = firestoreAs(EDITOR);
      const edit = (fields) => updateDoc(entryRef(db), { ...fields, updatedBy: EDITOR, updatedAt: serverTimestamp() });
      await assertSucceeds(edit({ title: '마트', memo: '우유', spentOn: '2026-10-18' }));
      await assertSucceeds(edit({ memo: deleteField(), spentOn: deleteField() }));
      await assertFails(edit({ memberId: 'someone' }));
      await assertFails(edit({ title: deleteField() }));
      await assertFails(edit({ cardId: 'card' }));
    });

    test('기본 월 지출은 고정 지출에서 옮긴 예정일(dueOn)을 받는다', async () => {
      const db = firestoreAs(EDITOR);
      await assertSucceeds(
        setDoc(entryRef(db, { type: 'planned', id: 'a' }), newEntryOf('planned', EDITOR, { dueOn: '2026-10-31' })),
      );
      await assertFails(
        setDoc(entryRef(db, { type: 'planned', id: 'b' }), newEntryOf('planned', EDITOR, { dueOn: '2026/10/31' })),
      );
      await assertFails(
        setDoc(entryRef(db, { type: 'planned', id: 'c' }), newEntryOf('planned', EDITOR, { dueOn: 31 })),
      );
    });

    test('예정일은 기본 월 지출만 받는다', async () => {
      await assertFails(setDoc(entryRef(firestoreAs(EDITOR)), newEntry(EDITOR, { dueOn: '2026-10-31' })));
    });
  });

  describe('고정 지출로 만든 그달 기본 지출', () => {
    // 문서 id가 고정 지출(템플릿) id다. 두 사람이 동시에 그달을 처음 열어도 같은 문서라 하나만 생긴다.
    const plannedRef = (db, id = 'template-1', ledger = LEDGER) => entryRef(db, { type: 'planned', id, ledger });
    const fromTemplate = (uid) => newEntryOf('planned', uid, { dueOn: '2026-10-25' });

    test('편집자는 없는 기본 지출을 템플릿 id로 만들 수 있다', async () => {
      await assertSucceeds(setDoc(plannedRef(firestoreAs(EDITOR)), fromTemplate(EDITOR)));
    });

    test('이미 있는 기본 지출을 새로 만드는 값으로 덮어쓸 수 없다', async () => {
      // 상대가 먼저 만들고 금액까지 고친 문서. 같은 id로 다시 만들려는 쓰기는 고치기로 검사돼 작성 기록이 달라 막힌다.
      await seed((db) =>
        setDoc(plannedRef(db), {
          ...fromTemplate(OWNER),
          amount: 210000,
          createdAt: Timestamp.fromMillis(1000),
          updatedAt: Timestamp.fromMillis(2000),
        }),
      );
      await assertFails(setDoc(plannedRef(firestoreAs(EDITOR)), fromTemplate(EDITOR)));
    });

    test('보기 전용은 그달 기본 지출을 만들 수 없다', async () => {
      await assertFails(setDoc(plannedRef(firestoreAs(VIEWER), 'template-1', VIEWER_LEDGER), fromTemplate(VIEWER)));
    });
  });
});

describe('고정 지출 템플릿', () => {
  function templateRef(db, { ledger = LEDGER, id = 'template-1' } = {}) {
    return doc(db, 'ledgers', ledger, 'templates', id);
  }

  // 앱이 쓰는 필드(lib/core/data/templates_repository.dart의 newTemplateData). 금액은 비우면 금액 미정이다.
  function newTemplate(uid, fields = {}) {
    return {
      title: '관리비',
      amount: 200000,
      categoryId: 'c1',
      paymentMethodId: 'p1',
      memberId: 'owner',
      dueDay: 25,
      createdBy: uid,
      updatedBy: uid,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      ...fields,
    };
  }

  function seedTemplate(fields = {}) {
    return seed((db) =>
      setDoc(templateRef(db), {
        ...newTemplate(OWNER),
        createdAt: Timestamp.fromMillis(1000),
        updatedAt: Timestamp.fromMillis(1000),
        ...fields,
      }),
    );
  }

  test('편집자와 관리자는 앱이 쓰는 필드로 고정 지출을 만들 수 있다', async () => {
    await assertSucceeds(setDoc(templateRef(firestoreAs(EDITOR)), newTemplate(EDITOR)));
    await assertSucceeds(
      setDoc(templateRef(firestoreAs(OWNER), { ledger: VIEWER_LEDGER }), newTemplate(OWNER, { memberId: 'partner' })),
    );
  });

  test('금액을 비우면 금액 미정 고정 지출이 된다', async () => {
    const { amount, ...unpriced } = newTemplate(EDITOR);
    await assertSucceeds(setDoc(templateRef(firestoreAs(EDITOR)), unpriced));
  });

  test('보기 전용과 다른 가계부 사람은 고정 지출을 만들 수 없다', async () => {
    await assertFails(setDoc(templateRef(firestoreAs(VIEWER), { ledger: VIEWER_LEDGER }), newTemplate(VIEWER)));
    await assertFails(setDoc(templateRef(firestoreAs(OUTSIDER)), newTemplate(OUTSIDER)));
  });

  test('받지 않는 필드가 있으면 만들 수 없다', async () => {
    const db = firestoreAs(EDITOR);
    await assertFails(setDoc(templateRef(db), newTemplate(EDITOR, { memo: '메모' })));
    await assertFails(setDoc(templateRef(db), newTemplate(EDITOR, { paidOn: '2026-10-25' })));
  });

  test('예정일은 1~31 정수만 받는다 (31은 말일)', async () => {
    const db = firestoreAs(EDITOR);
    await assertSucceeds(setDoc(templateRef(db, { id: 'a' }), newTemplate(EDITOR, { dueDay: 1 })));
    await assertSucceeds(setDoc(templateRef(db, { id: 'b' }), newTemplate(EDITOR, { dueDay: 31 })));
    for (const [id, dueDay] of [
      ['c', 0],
      ['d', 32],
      ['e', '25'],
      ['f', 10.5],
      ['g', null],
    ]) {
      await assertFails(setDoc(templateRef(db, { id }), newTemplate(EDITOR, { dueDay })));
    }
  });

  test('금액은 0 이상의 정수다', async () => {
    const db = firestoreAs(EDITOR);
    await assertSucceeds(setDoc(templateRef(db, { id: 'a' }), newTemplate(EDITOR, { amount: 0 })));
    await assertFails(setDoc(templateRef(db, { id: 'b' }), newTemplate(EDITOR, { amount: -1 })));
    await assertFails(setDoc(templateRef(db, { id: 'c' }), newTemplate(EDITOR, { amount: '1000' })));
  });

  test('누가는 owner·partner 이름표 자리만 받는다', async () => {
    const db = firestoreAs(EDITOR);
    await assertFails(setDoc(templateRef(db, { id: 'a' }), newTemplate(EDITOR, { memberId: EDITOR })));
    await assertFails(setDoc(templateRef(db, { id: 'b' }), newTemplate(EDITOR, { memberId: null })));
  });

  test('제목은 1~40자, 분류·결제수단은 비지 않은 문자열이어야 한다', async () => {
    const db = firestoreAs(EDITOR);
    await assertSucceeds(setDoc(templateRef(db, { id: 'a' }), newTemplate(EDITOR, { title: '가'.repeat(40) })));
    for (const [id, field, value] of [
      ['b', 'title', '가'.repeat(41)],
      ['c', 'title', ''],
      ['d', 'categoryId', ''],
      ['e', 'categoryId', null],
      ['f', 'paymentMethodId', ''],
      ['g', 'paymentMethodId', 7],
    ]) {
      await assertFails(setDoc(templateRef(db, { id }), newTemplate(EDITOR, { [field]: value })));
    }
  });

  test('고칠 때도 고친 뒤의 문서를 같은 기준으로 본다', async () => {
    await seedTemplate();
    const db = firestoreAs(EDITOR);
    const edit = (fields) => updateDoc(templateRef(db), { ...fields, updatedBy: EDITOR, updatedAt: serverTimestamp() });
    await assertSucceeds(edit({ amount: 210000, dueDay: 31 }));
    await assertSucceeds(edit({ amount: deleteField() }));
    await assertFails(edit({ dueDay: 0 }));
    await assertFails(edit({ title: deleteField() }));
  });

  test('편집자는 고정 지출을 지울 수 있고, 보기 전용은 지울 수 없다', async () => {
    await seed((db) =>
      setDoc(templateRef(db, { ledger: VIEWER_LEDGER }), {
        ...newTemplate(OWNER),
        createdAt: Timestamp.fromMillis(1000),
        updatedAt: Timestamp.fromMillis(1000),
      }),
    );
    await seedTemplate();
    await assertFails(deleteDoc(templateRef(firestoreAs(VIEWER), { ledger: VIEWER_LEDGER })));
    await assertSucceeds(deleteDoc(templateRef(firestoreAs(EDITOR))));
  });
});

describe('분류와 결제수단', () => {
  function settingRef(db, collectionName, { ledger = LEDGER, id = 'new' } = {}) {
    return doc(db, 'ledgers', ledger, collectionName, id);
  }

  // 앱이 쓰는 필드(lib/core/data/settings_repository.dart의 newCategoryData·newPaymentMethodData).
  // 숨김(hidden)은 숨기거나 다시 보이게 할 때만 쓴다.
  function newCategory(uid, fields = {}) {
    return {
      name: '경조사',
      countsAsSaving: false,
      order: 4,
      createdBy: uid,
      updatedBy: uid,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      ...fields,
    };
  }

  function newMethod(uid, fields = {}) {
    return {
      name: '하늘 카드',
      kind: 'card',
      order: 2,
      createdBy: uid,
      updatedBy: uid,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      ...fields,
    };
  }

  // 두 가계부(편집자·보기 전용)에 분류 c1과 결제수단 p1을 넣어 둔다.
  function seedSettings() {
    return seed(async (db) => {
      for (const ledger of [LEDGER, VIEWER_LEDGER]) {
        const written = { createdAt: Timestamp.fromMillis(1000), updatedAt: Timestamp.fromMillis(1000) };
        await setDoc(settingRef(db, 'categories', { ledger, id: 'c1' }), { ...newCategory(OWNER), ...written });
        await setDoc(settingRef(db, 'paymentMethods', { ledger, id: 'p1' }), { ...newMethod(OWNER), ...written });
      }
    });
  }

  function edit(uid, collectionName, fields, { ledger = LEDGER, id } = {}) {
    return updateDoc(settingRef(firestoreAs(uid), collectionName, { ledger, id }), {
      ...fields,
      updatedBy: uid,
      updatedAt: serverTimestamp(),
    });
  }

  test('편집자와 관리자는 앱이 쓰는 필드로 분류와 결제수단을 만들 수 있다', async () => {
    const editor = firestoreAs(EDITOR);
    await assertSucceeds(setDoc(settingRef(editor, 'categories'), newCategory(EDITOR, { countsAsSaving: true })));
    await assertSucceeds(setDoc(settingRef(editor, 'paymentMethods'), newMethod(EDITOR)));
    const owner = firestoreAs(OWNER);
    await assertSucceeds(setDoc(settingRef(owner, 'categories', { ledger: VIEWER_LEDGER }), newCategory(OWNER)));
    await assertSucceeds(
      setDoc(settingRef(owner, 'paymentMethods', { ledger: VIEWER_LEDGER }), newMethod(OWNER, { kind: 'account' })),
    );
  });

  test('보기 전용과 다른 가계부 사람은 분류와 결제수단을 만들 수 없다', async () => {
    const viewer = firestoreAs(VIEWER);
    await assertFails(setDoc(settingRef(viewer, 'categories', { ledger: VIEWER_LEDGER }), newCategory(VIEWER)));
    await assertFails(setDoc(settingRef(viewer, 'paymentMethods', { ledger: VIEWER_LEDGER }), newMethod(VIEWER)));
    const outsider = firestoreAs(OUTSIDER);
    await assertFails(setDoc(settingRef(outsider, 'categories'), newCategory(OUTSIDER)));
    await assertFails(setDoc(settingRef(outsider, 'paymentMethods'), newMethod(OUTSIDER)));
  });

  test('받지 않는 필드가 있으면 만들 수 없다', async () => {
    const db = firestoreAs(EDITOR);
    await assertFails(setDoc(settingRef(db, 'categories'), newCategory(EDITOR, { kind: 'card' })));
    await assertFails(setDoc(settingRef(db, 'paymentMethods'), newMethod(EDITOR, { countsAsSaving: false })));
  });

  test('이름은 1~20자다', async () => {
    const db = firestoreAs(EDITOR);
    await assertSucceeds(setDoc(settingRef(db, 'categories', { id: 'a' }), newCategory(EDITOR, { name: '가'.repeat(20) })));
    await assertSucceeds(setDoc(settingRef(db, 'paymentMethods', { id: 'a' }), newMethod(EDITOR, { name: '가'.repeat(20) })));
    for (const [id, name] of [
      ['b', '가'.repeat(21)],
      ['c', ''],
      ['d', 7],
    ]) {
      await assertFails(setDoc(settingRef(db, 'categories', { id }), newCategory(EDITOR, { name })));
      await assertFails(setDoc(settingRef(db, 'paymentMethods', { id }), newMethod(EDITOR, { name })));
    }
  });

  test('저축 집계는 참·거짓, 순서는 0 이상의 정수, 숨김은 참·거짓만 받는다', async () => {
    const db = firestoreAs(EDITOR);
    await assertSucceeds(setDoc(settingRef(db, 'categories', { id: 'a' }), newCategory(EDITOR, { hidden: true, order: 0 })));
    await assertSucceeds(setDoc(settingRef(db, 'paymentMethods', { id: 'a' }), newMethod(EDITOR, { hidden: false })));
    for (const [id, fields] of [
      ['b', { countsAsSaving: 'true' }],
      ['c', { countsAsSaving: null }],
      ['d', { order: -1 }],
      ['e', { order: '1' }],
      ['f', { order: null }],
      ['g', { hidden: 'true' }],
      ['h', { hidden: null }],
    ]) {
      await assertFails(setDoc(settingRef(db, 'categories', { id }), newCategory(EDITOR, fields)));
    }
    await assertFails(setDoc(settingRef(db, 'paymentMethods', { id: 'i' }), newMethod(EDITOR, { order: 1.5 })));
    await assertFails(setDoc(settingRef(db, 'paymentMethods', { id: 'j' }), newMethod(EDITOR, { hidden: 1 })));
  });

  test('결제수단 종류는 통장·자동이체·카드만 받는다', async () => {
    const db = firestoreAs(EDITOR);
    for (const [id, kind] of [
      ['a', 'account'],
      ['b', 'autoTransfer'],
      ['c', 'card'],
    ]) {
      await assertSucceeds(setDoc(settingRef(db, 'paymentMethods', { id }), newMethod(EDITOR, { kind })));
    }
    await assertFails(setDoc(settingRef(db, 'paymentMethods', { id: 'd' }), newMethod(EDITOR, { kind: 'cash' })));
    await assertFails(setDoc(settingRef(db, 'paymentMethods', { id: 'e' }), newMethod(EDITOR, { kind: null })));
  });

  test('편집자는 이름·저축 집계를 고치고 숨기거나 다시 보이게 할 수 있다', async () => {
    await seedSettings();
    await assertSucceeds(edit(EDITOR, 'categories', { name: '경조사비', countsAsSaving: true }, { id: 'c1' }));
    await assertSucceeds(edit(EDITOR, 'categories', { hidden: true }, { id: 'c1' }));
    await assertSucceeds(edit(EDITOR, 'categories', { hidden: false }, { id: 'c1' }));
    await assertSucceeds(edit(EDITOR, 'paymentMethods', { name: '바다 카드' }, { id: 'p1' }));
    await assertSucceeds(edit(EDITOR, 'paymentMethods', { hidden: true }, { id: 'p1' }));
  });

  test('고칠 때도 같은 기준으로 본다', async () => {
    await seedSettings();
    await assertFails(edit(EDITOR, 'categories', { name: '가'.repeat(21) }, { id: 'c1' }));
    await assertFails(edit(EDITOR, 'categories', { countsAsSaving: deleteField() }, { id: 'c1' }));
    await assertFails(edit(EDITOR, 'paymentMethods', { hidden: 'yes' }, { id: 'p1' }));
  });

  test('결제수단 종류는 바꿀 수 없다 (카드인지에 따라 지난 달 계산이 달라진다)', async () => {
    await seedSettings();
    await assertSucceeds(edit(EDITOR, 'paymentMethods', { name: '하늘 카드', kind: 'card' }, { id: 'p1' }));
    await assertFails(edit(EDITOR, 'paymentMethods', { kind: 'account' }, { id: 'p1' }));
  });

  test('보기 전용은 분류와 결제수단을 고칠 수 없다', async () => {
    await seedSettings();
    await assertFails(edit(VIEWER, 'categories', { hidden: true }, { ledger: VIEWER_LEDGER, id: 'c1' }));
    await assertFails(edit(VIEWER, 'paymentMethods', { hidden: true }, { ledger: VIEWER_LEDGER, id: 'p1' }));
    await assertSucceeds(edit(OWNER, 'categories', { hidden: true }, { ledger: VIEWER_LEDGER, id: 'c1' }));
    await assertSucceeds(edit(OWNER, 'paymentMethods', { hidden: true }, { ledger: VIEWER_LEDGER, id: 'p1' }));
  });

  test('이름표·분류·결제수단은 지울 수 없다 (숨기기만 한다)', async () => {
    await seedSettings();
    await seed((db) =>
      setDoc(doc(db, 'ledgers', LEDGER, 'members', 'partner'), {
        name: '바다',
        createdBy: OWNER,
        updatedBy: OWNER,
        createdAt: Timestamp.fromMillis(0),
        updatedAt: Timestamp.fromMillis(0),
      }),
    );
    for (const uid of [OWNER, EDITOR]) {
      const db = firestoreAs(uid);
      await assertFails(deleteDoc(settingRef(db, 'categories', { id: 'c1' })));
      await assertFails(deleteDoc(settingRef(db, 'paymentMethods', { id: 'p1' })));
      await assertFails(deleteDoc(settingRef(db, 'members', { id: 'partner' })));
    }
  });
});

describe('가계부 설정과 변경 기록', () => {
  function category(uid) {
    return {
      name: '소비',
      countsAsSaving: false,
      order: 0,
      createdBy: uid,
      updatedBy: uid,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    };
  }

  test('편집자와 관리자는 분류를 만들 수 있다', async () => {
    await assertSucceeds(
      setDoc(doc(firestoreAs(EDITOR), 'ledgers', LEDGER, 'categories', 'living'), category(EDITOR)),
    );
    await assertSucceeds(
      setDoc(doc(firestoreAs(OWNER), 'ledgers', VIEWER_LEDGER, 'categories', 'living'), category(OWNER)),
    );
  });

  test('보기 전용은 분류를 만들 수 없다', async () => {
    await assertFails(
      setDoc(doc(firestoreAs(VIEWER), 'ledgers', VIEWER_LEDGER, 'categories', 'saving'), category(VIEWER)),
    );
  });

  function setting(uid, fields = {}) {
    return {
      createdBy: uid,
      updatedBy: uid,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      ...fields,
    };
  }

  function settingRef(db, ledger, collectionName, id) {
    return doc(db, 'ledgers', ledger, collectionName, id);
  }

  test('가계부를 만들면서 이름표·분류·결제수단을 한 번의 일괄 쓰기로 넣을 수 있다', async () => {
    const db = firestoreAs(NEWCOMER);
    const batch = writeBatch(db);
    batch.set(ledgerRef(db, 'new-ledger'), newLedger(NEWCOMER));
    batch.set(settingRef(db, 'new-ledger', 'members', 'owner'), setting(NEWCOMER, { name: '하늘' }));
    batch.set(settingRef(db, 'new-ledger', 'members', 'partner'), setting(NEWCOMER, { name: '상대' }));
    batch.set(
      settingRef(db, 'new-ledger', 'categories', 'c1'),
      setting(NEWCOMER, { name: '소비', countsAsSaving: false, order: 0 }),
    );
    batch.set(
      settingRef(db, 'new-ledger', 'paymentMethods', 'p1'),
      setting(NEWCOMER, { name: '공동 통장', kind: 'account', order: 0 }),
    );
    await assertSucceeds(batch.commit());
  });

  test('가계부 문서 없이 설정만 일괄로 넣을 수는 없다', async () => {
    const db = firestoreAs(NEWCOMER);
    const batch = writeBatch(db);
    batch.set(settingRef(db, 'no-ledger', 'members', 'owner'), setting(NEWCOMER, { name: '하늘' }));
    await assertFails(batch.commit());
  });

  test('남의 가계부에는 일괄 쓰기로도 설정을 넣을 수 없다', async () => {
    const db = firestoreAs(OUTSIDER);
    const batch = writeBatch(db);
    batch.set(settingRef(db, LEDGER, 'categories', 'c1'), setting(OUTSIDER, { name: '소비', countsAsSaving: false, order: 0 }));
    await assertFails(batch.commit());
  });

  test('이름표 문서는 owner·partner 두 장만 만들 수 있다', async () => {
    const db = firestoreAs(OWNER);
    await assertSucceeds(setDoc(settingRef(db, SOLO_LEDGER, 'members', 'partner'), setting(OWNER, { name: '바다' })));
    await assertFails(setDoc(settingRef(db, SOLO_LEDGER, 'members', 'third'), setting(OWNER, { name: '바다' })));
  });

  // 길이 검사는 만들 때와 고칠 때 모두 한다. 막히는 경우는 통과하는 경우와 이름만 다르다.
  test('이름표 이름은 10자까지 만들 수 있다', async () => {
    const db = firestoreAs(OWNER);
    await assertSucceeds(setDoc(settingRef(db, SOLO_LEDGER, 'members', 'owner'), setting(OWNER, { name: '가'.repeat(10) })));
  });

  test('이름표 이름이 비었거나 11자면 만들 수 없다', async () => {
    const db = firestoreAs(OWNER);
    const ref = settingRef(db, SOLO_LEDGER, 'members', 'owner');
    await assertFails(setDoc(ref, setting(OWNER, { name: '' })));
    await assertFails(setDoc(ref, setting(OWNER, { name: '가'.repeat(11) })));
  });

  test('이름표 이름을 고칠 때도 1~10자다', async () => {
    await seed((db) =>
      setDoc(settingRef(db, SOLO_LEDGER, 'members', 'owner'), {
        name: '하늘',
        createdBy: OWNER,
        updatedBy: OWNER,
        createdAt: Timestamp.fromMillis(0),
        updatedAt: Timestamp.fromMillis(0),
      }),
    );
    const ref = settingRef(firestoreAs(OWNER), SOLO_LEDGER, 'members', 'owner');
    const rename = (name) => updateDoc(ref, { name, updatedBy: OWNER, updatedAt: serverTimestamp() });

    await assertSucceeds(rename('가'.repeat(10)));
    await assertFails(rename(''));
    await assertFails(rename('가'.repeat(11)));
  });

  // 앱의 memberRenameUpdate(lib/core/data/settings_repository.dart)와 같은 필드로 바꾼다.
  test('편집자는 두 이름표를 모두 고칠 수 있고, 보기 전용은 고칠 수 없다', async () => {
    await seed(async (db) => {
      for (const [ledger, slot] of [
        [LEDGER, 'owner'],
        [LEDGER, 'partner'],
        [VIEWER_LEDGER, 'partner'],
      ]) {
        await setDoc(settingRef(db, ledger, 'members', slot), {
          name: '하늘',
          createdBy: OWNER,
          updatedBy: OWNER,
          createdAt: Timestamp.fromMillis(0),
          updatedAt: Timestamp.fromMillis(0),
        });
      }
    });
    const rename = (uid, ledger, slot) =>
      updateDoc(settingRef(firestoreAs(uid), ledger, 'members', slot), {
        name: '바다',
        updatedBy: uid,
        updatedAt: serverTimestamp(),
      });

    await assertSucceeds(rename(EDITOR, LEDGER, 'owner'));
    await assertSucceeds(rename(EDITOR, LEDGER, 'partner'));
    await assertFails(rename(VIEWER, VIEWER_LEDGER, 'partner'));
    await assertSucceeds(rename(OWNER, VIEWER_LEDGER, 'partner'));
  });

  test('변경 기록은 자기 이름으로 추가만 할 수 있다', async () => {
    const db = firestoreAs(EDITOR);
    const ref = doc(db, 'ledgers', LEDGER, 'activity', 'log-1');
    const log = (actorUid) => ({
      actorUid,
      at: serverTimestamp(),
      action: 'entry.create',
      summary: '추가지출 장보기 10,000원',
    });
    await assertFails(setDoc(doc(db, 'ledgers', LEDGER, 'activity', 'log-0'), log(OWNER)));
    await assertSucceeds(setDoc(ref, log(EDITOR)));
    await assertFails(updateDoc(ref, { summary: '고친 기록' }));
    await assertFails(deleteDoc(ref));
  });
});
