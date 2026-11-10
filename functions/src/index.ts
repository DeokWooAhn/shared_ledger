import { initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { setGlobalOptions } from 'firebase-functions';
import { onDocumentUpdated } from 'firebase-functions/firestore';
import * as logger from 'firebase-functions/logger';
import { defineSecret } from 'firebase-functions/params';
import { onSchedule } from 'firebase-functions/scheduler';

import {
  type HolidayDays,
  HolidayApiError,
  apiErrorMessage,
  holidaysFromResponse,
  restDayUrl,
  sameDays,
  yearInKorea,
} from './holidays.js';
import { becameEmpty, hasNoMembers } from './ledgers.js';

// Firestore와 같은 서울 지역에서 돌린다. 하루 한 번 도는 함수와 드물게 일하는 트리거뿐이라 인스턴스는 하나면 된다.
setGlobalOptions({ region: 'asia-northeast3', maxInstances: 1 });
initializeApp();

/**
 * 공공데이터포털 일반 인증키(Encoding·Decoding 둘 다 된다). `firebase functions:secrets:set HOLIDAY_API_KEY`로 넣고,
 * 넣은 뒤에는 함수를 다시 배포해야 새 버전을 쓴다. 저장소와 로그에 두지 않는다.
 */
const holidayApiKey = defineSecret('HOLIDAY_API_KEY');

/**
 * 매일 새벽 4시(한국 시간)에 올해와 내년 공휴일을 특일 API에서 받아 `holidays/{연도}`에 쓴다.
 *
 * - 임시공휴일·선거일처럼 해 중간에 생기는 공휴일도 다음 날 새벽이면 앱에 들어간다.
 * - 아직 발표 전이라 비어 있는 해(보통 내년 상반기)는 쓰지 않는다. 받은 값이 지금 문서와 같으면 다시 쓰지 않는다.
 * - 한 해라도 받지 못하면 그해는 건드리지 않고(지난번 값을 그대로 둔다) 오류로 남긴다. 다음 날 다시 받는다.
 */
export const syncHolidays = onSchedule(
  {
    schedule: 'every day 04:00',
    timeZone: 'Asia/Seoul',
    secrets: [holidayApiKey],
    timeoutSeconds: 120,
  },
  async () => {
    const thisYear = yearInKorea(new Date());
    const failed: number[] = [];
    for (const year of [thisYear, thisYear + 1]) {
      try {
        await syncYear(year, holidayApiKey.value());
      } catch (error) {
        failed.push(year);
        logger.error('공휴일을 받지 못함', { year, error: String(error) });
      }
    }
    if (failed.length > 0) {
      throw new Error(`공휴일 동기화 실패: ${failed.join(', ')}`);
    }
  },
);

async function syncYear(year: number, serviceKey: string): Promise<void> {
  const days: HolidayDays = {};
  for (let month = 1; month <= 12; month++) {
    const response = await fetch(restDayUrl(serviceKey, year, month), {
      signal: AbortSignal.timeout(10_000),
    });
    if (!response.ok) {
      throw new HolidayApiError(
        `HTTP ${response.status} ${apiErrorMessage(await response.text())}`,
      );
    }
    Object.assign(days, holidaysFromResponse(await response.text()));
  }
  if (Object.keys(days).length === 0) {
    logger.info('아직 발표 전이라 건너뜀', { year });
    return;
  }
  const doc = getFirestore().doc(`holidays/${year}`);
  const current = (await doc.get()).get('days') as HolidayDays | undefined;
  if (sameDays(current, days)) return;
  await doc.set({ days, updatedAt: FieldValue.serverTimestamp() });
  logger.info('공휴일을 고침', { year, count: Object.keys(days).length });
}

/**
 * 혼자 쓰던 관리자가 나가 구성원이 빈 가계부를 하위 문서(설정·항목·변경 기록)까지 지운다(2026-11-10).
 *
 * - 앱은 가계부 문서를 지울 수 없다(규칙의 `allow delete: if false`). 문서만 지우면 하위 컬렉션이 남기 때문이다.
 *   대신 구성원 목록을 비우면(규칙의 `ownerClosesAlone`, 탈퇴할 때도 같다) 이 함수가 관리자 권한으로 통째로 지운다.
 * - 구성원이 빈 가계부는 규칙이 읽기·쓰기·참여를 모두 막아서, 지워지기 전에도 아무도 볼 수 없다.
 * - 그 가계부의 초대 코드도 지운다. 남은 코드로는 어차피 들어올 수 없지만(규칙), 쓸모없는 문서를 남기지 않는다.
 * - 가계부 문서는 고칠 때마다(달 더하기, 이름 바꾸기, 참여) 이 함수를 깨우지만, 구성원이 비지 않았으면 바로 끝난다.
 * - 실패하면 다시 시도한다(`retry`). 이미 지웠으면 지울 것이 없어 끝난다.
 * - 가계부 id는 만든 사람의 uid로 시작해서 로그에 남기지 않는다.
 */
export const deleteClosedLedger = onDocumentUpdated(
  { document: 'ledgers/{ledgerId}', retry: true, timeoutSeconds: 540 },
  async (event) => {
    if (!becameEmpty(event.data?.before.data(), event.data?.after.data())) return;
    const db = getFirestore();
    const ledger = db.doc(`ledgers/${event.params.ledgerId}`);
    // 다시 시도하는 사이에 이미 지웠으면 지울 것이 없다.
    if (!hasNoMembers((await ledger.get()).data())) return;
    const invites = await db.collection('invites').where('ledgerId', '==', ledger.id).get();
    await Promise.all(invites.docs.map((invite) => invite.ref.delete()));
    await db.recursiveDelete(ledger);
    logger.info('구성원이 빈 가계부를 지움', { invites: invites.size });
  },
);
