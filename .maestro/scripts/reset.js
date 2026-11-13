// 호스트의 전용 포트와 demo 프로젝트만 사용한다. 운영 프로젝트 주소는 받지 않는다.
var project = 'demo-shared-ledger';
var authBase = 'http://127.0.0.1:19099';
var storeBase = 'http://127.0.0.1:18080';
var database = '/v1/projects/' + project + '/databases/(default)/documents';

function checked(response) {
  if (response.status < 200 || response.status >= 300) {
    throw new Error('테스트 데이터 준비 실패: HTTP ' + response.status + ' ' + response.body);
  }
  return response.body ? json(response.body) : {};
}

function clearFirestore() {
  // 이전 앱의 listen 연결이 닫힐 때 clearData가 일시적으로 HTTP 500을 돌려줄 수 있다.
  // 초기화 DELETE만 재시도한다. 앱의 쓰기나 검증 실패는 다시 실행하지 않는다.
  for (var attempt = 0; attempt < 3; attempt++) {
    var response = http.delete(storeBase + '/emulator/v1/projects/' + project + '/databases/(default)/documents');
    if (response.status !== 500 || attempt === 2) return checked(response);
  }
}

clearFirestore();
checked(http.delete(authBase + '/emulator/v1/projects/' + project + '/accounts'));
var user = checked(http.post(authBase + '/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key', {
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ email: 'maestro@example.test', password: 'maestro-test-password', returnSecureToken: true })
}));
output.ledgerId = user.localId + '_MaestroLedger0000001';

function value(data) {
  if (typeof data === 'string') return { stringValue: data };
  if (typeof data === 'number') return { integerValue: String(data) };
  if (typeof data === 'boolean') return { booleanValue: data };
  if (Array.isArray(data)) return { arrayValue: { values: data.map(value) } };
  return { mapValue: { fields: fields(data) } };
}
function fields(data) {
  var result = {};
  Object.keys(data).forEach(function (key) { result[key] = value(data[key]); });
  return result;
}
function put(path, data) {
  var documentFields = fields(data);
  // 가계부 루트는 시각만, 설정·항목 문서는 작성자도 갖는다(실제 저장소와 같은 필드).
  if (path !== 'ledgers/' + output.ledgerId) {
    documentFields.createdBy = value(user.localId);
    documentFields.updatedBy = value(user.localId);
  }
  documentFields.createdAt = { timestampValue: '2026-10-15T00:00:00Z' };
  documentFields.updatedAt = { timestampValue: '2026-10-15T00:00:00Z' };
  // 초기 픽스처만 관리자 권한으로 넣는다. 앱의 추가·수정·휴지통·복원에는 실제 보안 규칙이 적용된다.
  checked(http.request(storeBase + database + '/' + path, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json', Authorization: 'Bearer owner' },
    body: JSON.stringify({ fields: documentFields })
  }));
}
var ledger = 'ledgers/' + output.ledgerId;
put(ledger, { name: '자동화 테스트 가계부', ownerUid: user.localId, roles: {}, memberUids: [user.localId], months: ['2026-10'] });
put(ledger + '/members/owner', { name: '테스트 하나' });
put(ledger + '/members/partner', { name: '테스트 둘' });
put(ledger + '/paymentMethods/smoke-account', { name: '테스트 통장', kind: 'account', order: 0, hidden: false });
put(ledger + '/categories/smoke-spending', { name: '테스트 소비', countsAsSaving: false, order: 0, hidden: false });
put(ledger + '/months/2026-10/incomes/smoke-income', { memberId: 'owner', title: '테스트 수입', amount: 1000000, receivedOn: '2026-10-15' });
put(ledger + '/months/2026-10/extras/smoke-expense', { memberId: 'owner', title: '테스트 지출', amount: 23000, paymentMethodId: 'smoke-account', spentOn: '2026-10-15' });
