import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  HolidayApiError,
  apiErrorMessage,
  holidaysFromResponse,
  normalizeServiceKey,
  restDayUrl,
  sameDays,
  yearInKorea,
} from './holidays.js';

// 특일 API JSON 응답 모양(항목은 [items]).
function response(items: unknown, resultCode = '00'): string {
  return JSON.stringify({
    response: {
      header: { resultCode, resultMsg: 'NORMAL SERVICE.' },
      body: { items, numOfRows: 50, pageNo: 1, totalCount: 0 },
    },
  });
}

describe('holidaysFromResponse', () => {
  test('공휴일만 날짜별 이름으로 뽑는다', () => {
    const days = holidaysFromResponse(
      response({
        item: [
          { dateKind: '01', dateName: '개천절', isHoliday: 'Y', locdate: 20261003, seq: 1 },
          { dateKind: '01', dateName: '대체공휴일', isHoliday: 'Y', locdate: 20261005, seq: 1 },
          { dateKind: '01', dateName: '한글날', isHoliday: 'Y', locdate: 20261009, seq: 1 },
          { dateKind: '01', dateName: '국군의 날', isHoliday: 'N', locdate: 20261001, seq: 1 },
        ],
      }),
    );

    assert.deepEqual(days, {
      '2026-10-03': '개천절',
      '2026-10-05': '대체공휴일',
      '2026-10-09': '한글날',
    });
  });

  test('항목이 하나면 객체로, 없으면 빈 문자열로 와도 읽는다', () => {
    assert.deepEqual(
      holidaysFromResponse(
        response({ item: { dateName: '성탄절', isHoliday: 'Y', locdate: '20261225' } }),
      ),
      { '2026-12-25': '성탄절' },
    );
    assert.deepEqual(holidaysFromResponse(response('')), {});
  });

  test('같은 날 공휴일이 둘이면 이름을 잇고, 같은 이름은 한 번만 쓴다', () => {
    const days = holidaysFromResponse(
      response({
        item: [
          { dateName: '어린이날', isHoliday: 'Y', locdate: 20250505 },
          { dateName: '부처님오신날', isHoliday: 'Y', locdate: 20250505 },
          { dateName: '부처님오신날', isHoliday: 'Y', locdate: 20250505 },
        ],
      }),
    );

    assert.deepEqual(days, { '2025-05-05': '어린이날·부처님오신날' });
  });

  test('날짜나 이름이 이상한 항목은 건너뛴다', () => {
    const days = holidaysFromResponse(
      response({
        item: [
          { dateName: '설날', isHoliday: 'Y', locdate: 2026021 },
          { dateName: ' ', isHoliday: 'Y', locdate: 20260217 },
          { isHoliday: 'Y', locdate: 20260218 },
          { dateName: '설날', isHoliday: 'Y', locdate: 20260216 },
        ],
      }),
    );

    assert.deepEqual(days, { '2026-02-16': '설날' });
  });

  test('결과 코드가 정상이 아니면 결과 메시지를 오류에 담는다', () => {
    assert.throws(
      () => holidaysFromResponse(response('', '22')),
      /결과 코드 22 NORMAL SERVICE\./,
    );
  });

  test('결과 코드가 정상이 아니거나 JSON이 아니면 오류다', () => {
    assert.throws(() => holidaysFromResponse(response('', '30')), HolidayApiError);
    assert.throws(
      () =>
        holidaysFromResponse(
          '<OpenAPI_ServiceResponse><cmmMsgHeader><returnAuthMsg>SERVICE_KEY_IS_NOT_REGISTERED_ERROR</returnAuthMsg></cmmMsgHeader></OpenAPI_ServiceResponse>',
        ),
      HolidayApiError,
    );
    assert.throws(() => holidaysFromResponse('{}'), HolidayApiError);
  });
});

test('조회 주소는 인증키를 인코딩하고 달을 두 자리로 쓴다', () => {
  const url = new URL(restDayUrl('a+b/c==', 2026, 3));

  assert.equal(url.pathname, '/B090041/openapi/service/SpcdeInfoService/getRestDeInfo');
  assert.equal(url.searchParams.get('ServiceKey'), 'a+b/c==');
  assert.equal(url.searchParams.get('solYear'), '2026');
  assert.equal(url.searchParams.get('solMonth'), '03');
  assert.equal(url.searchParams.get('_type'), 'json');
});

describe('normalizeServiceKey', () => {
  test('포털의 Encoding 키는 풀고, Decoding 키는 그대로 둔다', () => {
    assert.equal(normalizeServiceKey('a%2Bb%2Fc%3D%3D'), 'a+b/c==');
    assert.equal(normalizeServiceKey('a+b/c=='), 'a+b/c==');
  });

  test('앞뒤 공백·줄바꿈은 자르고, 풀 수 없는 %는 그대로 둔다', () => {
    assert.equal(normalizeServiceKey('  a+b/c==\n'), 'a+b/c==');
    assert.equal(normalizeServiceKey('abc%zz'), 'abc%zz');
  });

  test('Encoding 키로 만든 주소도 원래 키 한 번만 인코딩된다', () => {
    const url = new URL(restDayUrl('a%2Bb%2Fc%3D%3D', 2026, 10));

    assert.equal(url.searchParams.get('ServiceKey'), 'a+b/c==');
    assert.match(url.search, /ServiceKey=a%2Bb%2Fc%3D%3D&/);
  });
});

describe('apiErrorMessage', () => {
  test('거부 응답(JSON)에서 오류 코드와 사유를 뽑는다', () => {
    // 등록되지 않은 키로 부르면 HTTP 403과 함께 오는 본문.
    const body = JSON.stringify({
      OpenAPI_ServiceResponse: {
        cmmMsgHeader: {
          errMsg: 'SERVICE_KEY_IS_NOT_REGISTERED_ERROR',
          returnAuthMsg: '등록되지 않은 서비스키',
          returnReasonCode: '30',
        },
      },
    });

    assert.equal(
      apiErrorMessage(body),
      'SERVICE_KEY_IS_NOT_REGISTERED_ERROR(등록되지 않은 서비스키)',
    );
  });

  test('XML 거부 응답에서도 뽑고, 모르는 모양이면 본문 앞부분을 돌려준다', () => {
    assert.equal(
      apiErrorMessage(
        '<OpenAPI_ServiceResponse><cmmMsgHeader><errMsg>SERVICE ERROR</errMsg><returnAuthMsg>LIMITED_NUMBER_OF_SERVICE_REQUESTS_EXCEEDS_ERROR</returnAuthMsg></cmmMsgHeader></OpenAPI_ServiceResponse>',
      ),
      'SERVICE ERROR(LIMITED_NUMBER_OF_SERVICE_REQUESTS_EXCEEDS_ERROR)',
    );
    assert.equal(apiErrorMessage('Forbidden\n  please retry'), 'Forbidden please retry');
  });
});

test('sameDays는 날짜와 이름이 모두 같을 때만 같다', () => {
  const days = { '2026-10-03': '개천절' };

  assert.equal(sameDays({ '2026-10-03': '개천절' }, days), true);
  assert.equal(sameDays(undefined, days), false);
  assert.equal(sameDays({ '2026-10-03': '개천절', '2026-10-09': '한글날' }, days), false);
  assert.equal(sameDays({ '2026-10-03': '대체공휴일' }, days), false);
});

test('올해는 한국 시간으로 센다', () => {
  // 한국 시간 2027-01-01 03:00은 UTC로 2026-12-31 18:00이다.
  assert.equal(yearInKorea(new Date('2026-12-31T18:00:00Z')), 2027);
  assert.equal(yearInKorea(new Date('2026-12-31T14:00:00Z')), 2026);
});
