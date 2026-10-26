// 공공데이터포털 '한국천문연구원_특일 정보'의 공휴일 조회(getRestDeInfo) 응답을 앱이 읽는 모양으로 바꾼다.
// 네트워크·Firestore 없이 테스트하려고 순수 함수만 둔다.

/** 특일 정보 서비스 주소. 공휴일 조회는 이 뒤에 `/getRestDeInfo`를 붙인다. */
export const specialDayServiceUrl =
  'https://apis.data.go.kr/B090041/openapi/service/SpcdeInfoService';

/** 한 해의 공휴일. 키는 `2026-10-03` 같은 날짜, 값은 이름이다. 앱의 `holidays/{연도}` 문서 `days` 필드와 같다. */
export type HolidayDays = Record<string, string>;

/** 특일 API가 정상이 아닌 답을 줬다(인증키 오류, 호출 한도 초과 등). */
export class HolidayApiError extends Error {}

/** [year]년 [month]월 공휴일 조회 주소. [serviceKey]는 포털의 일반 인증키(Decoding)다. */
export function restDayUrl(
  serviceKey: string,
  year: number,
  month: number,
): string {
  const params = new URLSearchParams({
    ServiceKey: serviceKey,
    solYear: String(year),
    solMonth: String(month).padStart(2, '0'),
    numOfRows: '50',
    pageNo: '1',
    _type: 'json',
  });
  return `${specialDayServiceUrl}/getRestDeInfo?${params}`;
}

/**
 * getRestDeInfo의 JSON 응답에서 공휴일(`isHoliday`가 `Y`)만 뽑는다.
 *
 * - 항목이 하나면 `item`이 배열이 아니라 객체로, 없으면 `items`가 빈 문자열로 온다.
 * - 같은 날 공휴일이 둘이면(2025-05-05 어린이날·부처님오신날) 이름을 '·'로 잇는다.
 * - 날짜나 이름이 이상한 항목은 건너뛴다.
 * - 결과 코드가 정상(`00`)이 아니거나 모양이 다르면 [HolidayApiError]를 던진다. 인증키 오류는 JSON이 아닌 XML로 오기도 해서
 *   본문을 문자열로 받아 여기서 해석한다.
 */
export function holidaysFromResponse(text: string): HolidayDays {
  let body: unknown;
  try {
    body = JSON.parse(text);
  } catch {
    throw new HolidayApiError(`JSON이 아닌 응답: ${text.slice(0, 200)}`);
  }
  const response = field(body, 'response');
  const code = field(field(response, 'header'), 'resultCode');
  if (code !== '00') {
    throw new HolidayApiError(`결과 코드 ${String(code)}`);
  }
  const items = field(field(response, 'body'), 'items');
  const item = field(items, 'item');
  const list = Array.isArray(item) ? item : item === undefined ? [] : [item];
  const days: HolidayDays = {};
  for (const entry of list) {
    if (field(entry, 'isHoliday') !== 'Y') continue;
    const date = dateOf(field(entry, 'locdate'));
    const name = field(entry, 'dateName');
    if (date === null || typeof name !== 'string' || name.trim() === '') {
      continue;
    }
    const names = days[date]?.split('·') ?? [];
    if (!names.includes(name.trim())) names.push(name.trim());
    days[date] = names.join('·');
  }
  return days;
}

/** 두 해 공휴일이 같은지. 바뀌지 않았으면 문서를 다시 쓰지 않는다(앱의 읽기가 늘지 않게). */
export function sameDays(a: HolidayDays | undefined, b: HolidayDays): boolean {
  if (a === undefined) return false;
  const keys = Object.keys(b);
  return (
    Object.keys(a).length === keys.length && keys.every((key) => a[key] === b[key])
  );
}

/** 한국 시간으로 올해. 함수는 UTC로 돌아서 1월 1일 0~9시에 지난해로 보지 않게 한다. */
export function yearInKorea(now: Date): number {
  return new Date(now.getTime() + 9 * 60 * 60 * 1000).getUTCFullYear();
}

function field(value: unknown, key: string): unknown {
  return typeof value === 'object' && value !== null
    ? (value as Record<string, unknown>)[key]
    : undefined;
}

// 20261003(숫자나 문자열) → '2026-10-03'. 모양이 다르면 null.
function dateOf(locdate: unknown): string | null {
  const text = String(locdate ?? '');
  const match = /^(\d{4})(\d{2})(\d{2})$/.exec(text);
  return match === null ? null : `${match[1]}-${match[2]}-${match[3]}`;
}
