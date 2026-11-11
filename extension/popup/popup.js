// 확장 아이콘을 누르면 지금 상태와 메뉴 막대 앱 연결 여부를 보여 준다.

const LEVEL_TEXT = {
  closed: 'Google Chat이 열려 있지 않음',
  unknown: '새 메시지가 있는지 알 수 없음',
  none: '새 메시지 없음',
  alert: '새 메시지 있음',
};

const SIGNAL_NAMES = [
  ['favicon', '파비콘'],
  ['badge', 'Dock 배지'],
  ['sidebar', '왼쪽 목록 숫자'],
  ['title', '탭 제목'],
];

function signalText(key, value) {
  if (value === null || value === undefined) return '알 수 없음';
  if (key === 'favicon') return value ? '안 읽은 표시 있음' : '안 읽은 표시 없음';
  if (value === 'flag') return '점만 있음';
  return String(value);
}

// 크롬이 돌려주는 연결 오류를 사람이 할 일로 바꾼다.
function nativeHint(native) {
  const error = native.error ?? '';
  if (/not found/i.test(error)) {
    return 'ChatLamp 앱을 한 번 실행해 주세요. 앱이 처음 실행될 때 크롬에 자기를 등록합니다.';
  }
  if (/forbidden/i.test(error)) {
    return '이 확장의 ID가 앱에 등록된 ID와 다릅니다. 저장소의 extension 폴더를 그대로 불러왔는지 확인해 주세요.';
  }
  if (error) return `연결 오류: ${error}`;
  if (native.appRunning === false) return 'ChatLamp 앱이 꺼져 있습니다. 응용 프로그램 폴더에서 ChatLamp를 실행해 주세요.';
  return null;
}

function el(tag, text, className) {
  const node = document.createElement(tag);
  if (text !== undefined) node.textContent = text;
  if (className) node.className = className;
  return node;
}

function render({ summary, tabs, native }) {
  const level = document.getElementById('level');
  level.textContent =
    summary.level === 'alert' && summary.count ? `${LEVEL_TEXT.alert} (${summary.count})` : LEVEL_TEXT[summary.level];
  level.className = summary.level === 'alert' ? 'lit' : '';

  const app = document.getElementById('app');
  const ok = native.connected && native.appRunning !== false;
  app.textContent = ok ? '연결됨' : '연결 안 됨';
  app.className = ok ? '' : 'warn';

  const hint = document.getElementById('hint');
  const message = nativeHint(native);
  hint.hidden = !message;
  hint.textContent = message ?? '';

  const list = document.getElementById('tabs');
  list.replaceChildren();
  const entries = Object.values(tabs);
  if (entries.length === 0) {
    list.append(el('p', '지켜보는 Google Chat 탭이 없습니다.'));
    return;
  }
  entries.forEach(({ state }, index) => {
    const box = el('div', undefined, 'tab');
    box.append(el('strong', `탭 ${index + 1}: ${LEVEL_TEXT[state.level]}`));
    const table = el('table');
    for (const [key, name] of SIGNAL_NAMES) {
      const row = el('tr', undefined, state.via === key ? 'used' : '');
      row.append(el('th', name), el('td', signalText(key, state.signals[key])));
      table.append(row);
    }
    box.append(table);
    list.append(box);
  });
}

chrome.runtime.sendMessage({ type: 'popup' }).then(render);
