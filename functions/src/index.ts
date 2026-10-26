import { initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { setGlobalOptions } from 'firebase-functions';
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

// Firestore와 같은 서울 지역에서 돌린다. 하루 한 번 도는 함수라 인스턴스는 하나면 된다.
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
