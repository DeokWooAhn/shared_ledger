/**
 * 가계부 문서(`ledgers/{ledgerId}`)를 보고 판단하는 규칙. Firebase 없이 테스트한다(ledgers.test.ts).
 */

/** 가계부 문서의 구성원 uid 목록. 목록이 아니면 null. */
function memberUidsOf(data: Record<string, unknown> | undefined): unknown[] | null {
  const memberUids = data?.['memberUids'];
  return Array.isArray(memberUids) ? memberUids : null;
}

/**
 * 이번 고치기로 구성원이 비었는지. 혼자 쓰던 관리자가 나가면(규칙의 ownerClosesAlone, 탈퇴 포함) 구성원 목록을 비운다.
 *
 * 앞에도 비어 있었으면(이미 지우는 중인 가계부를 다시 고친 경우) 다시 지우지 않는다. 목록이 없는 문서는 건드리지 않는다.
 */
export function becameEmpty(
  before: Record<string, unknown> | undefined,
  after: Record<string, unknown> | undefined,
): boolean {
  const beforeUids = memberUidsOf(before);
  const afterUids = memberUidsOf(after);
  return beforeUids !== null && beforeUids.length > 0 && afterUids !== null && afterUids.length === 0;
}

/** 지금 문서의 구성원이 비어 있는지. 지우기 바로 전에 다시 확인한다. */
export function hasNoMembers(data: Record<string, unknown> | undefined): boolean {
  const memberUids = memberUidsOf(data);
  return memberUids !== null && memberUids.length === 0;
}
