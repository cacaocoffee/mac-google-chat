// Google Chat 탭들이 보낸 상태를 하나로 합쳐 메뉴 막대 앱에 보낸다.
// 앱과는 크롬 네이티브 메시징으로 연결한다. 크롬이 앱 안의 chatlamp-host를 실행해 준다.

const HOST = 'io.github.cacaocoffee.chatlamp';
// 이 시간 동안 소식이 없는 탭은 닫힌 것으로 본다. 크롬은 5분 넘게 가려진 탭의 반복 타이머를
// 1분에 한 번으로 늦추므로, 뒤에 깔린 탭이 지워지지 않도록 그보다 넉넉하게 둔다.
// 탭을 닫거나 다른 주소로 옮기는 경우는 tabs.onRemoved와 pagehide로 바로 지운다.
const TAB_STALE_MS = 180_000;
const RESEND_MS = 25_000; // 바뀐 것이 없어도 앱에 다시 보낸다. 앱은 90초 동안 소식이 없으면 끊긴 것으로 본다
const LEVELS = ['closed', 'unknown', 'none', 'alert']; // 뒤로 갈수록 우선한다

let port = null;
let native = { connected: false, appRunning: null, error: null };
let tabs = {}; // 탭 ID → { state, at }

// 크롬은 서비스 워커를 언제든 종료했다가 다시 시작할 수 있어서 탭 상태를 세션 저장소에 저장한다.
const ready = chrome.storage.session.get('tabs').then((saved) => {
  tabs = saved.tabs ?? {};
});

function save() {
  chrome.storage.session.set({ tabs }).catch(() => {});
}

function summarize() {
  const now = Date.now();
  for (const [id, tab] of Object.entries(tabs)) {
    if (now - tab.at > TAB_STALE_MS) delete tabs[id];
  }
  const states = Object.values(tabs).map((tab) => tab.state);
  if (states.length === 0) return { type: 'state', level: 'closed', count: null, tabs: 0 };

  const level = states
    .map((state) => state.level)
    .reduce((a, b) => (LEVELS.indexOf(b) > LEVELS.indexOf(a) ? b : a));
  // 같은 계정을 탭과 앱 창에 같이 열어 둘 수 있으니 더하지 않고 큰 값을 쓴다.
  const counts = states.filter((s) => s.level === 'alert' && s.count > 0).map((s) => s.count);
  return { type: 'state', level, count: counts.length ? Math.max(...counts) : null, tabs: states.length };
}

function connect() {
  if (port) return port;
  try {
    port = chrome.runtime.connectNative(HOST);
  } catch (error) {
    native = { connected: false, appRunning: null, error: String(error?.message ?? error) };
    return null;
  }
  native = { connected: true, appRunning: native.appRunning, error: null };
  port.onMessage.addListener((message) => {
    if (message?.type === 'ack') native.appRunning = Boolean(message.appRunning);
  });
  port.onDisconnect.addListener(() => {
    // 호스트가 등록돼 있지 않으면 여기로 바로 온다. 다음 publish()에서 다시 연결한다.
    native = { connected: false, appRunning: null, error: chrome.runtime.lastError?.message ?? null };
    port = null;
  });
  return port;
}

function publish() {
  const summary = summarize();
  showBadge(summary);
  const current = connect();
  if (!current) return;
  try {
    current.postMessage(summary);
  } catch (_) {
    port = null;
  }
}

// 크롬 툴바의 확장 아이콘에도 같은 상태를 표시한다.
function showBadge({ level, count }) {
  const text = level !== 'alert' ? '' : count ? (count > 99 ? '99+' : String(count)) : '•';
  chrome.action.setBadgeText({ text });
  chrome.action.setBadgeBackgroundColor({ color: '#1e8e3e' });
  chrome.action.setBadgeTextColor({ color: '#ffffff' });
}

// 설치하거나 다시 로드하기 전에 열려 있던 Google Chat 탭에도 스크립트를 넣는다.
// manifest의 content_scripts는 새로 여는 페이지에만 들어가기 때문이다.
async function injectIntoOpenTabs() {
  const open = await chrome.tabs.query({ url: 'https://chat.google.com/*' });
  for (const tab of open) {
    chrome.scripting
      .executeScript({ target: { tabId: tab.id, allFrames: true }, world: 'MAIN', files: ['content/badge-hook.js'] })
      .catch(() => {});
    chrome.scripting
      .executeScript({ target: { tabId: tab.id }, files: ['content/detect.js', 'content/watch.js'] })
      .catch(() => {});
  }
}

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  const tabId = sender.tab?.id;
  if (message?.type === 'tab-state' && tabId != null) {
    ready.then(() => {
      tabs[tabId] = { state: message.state, at: Date.now() };
      save();
      publish();
    });
  } else if (message?.type === 'tab-gone' && tabId != null) {
    ready.then(() => {
      delete tabs[tabId];
      save();
      publish();
    });
  } else if (message?.type === 'popup') {
    ready.then(() => sendResponse({ summary: summarize(), tabs, native }));
    return true;
  }
});

chrome.tabs.onRemoved.addListener((tabId) => {
  ready.then(() => {
    if (!tabs[tabId]) return;
    delete tabs[tabId];
    save();
    publish();
  });
});

chrome.runtime.onInstalled.addListener(() => {
  injectIntoOpenTabs();
});

// 서비스 워커가 시작될 때마다(크롬 시작, 탭 메시지 등) 앱과 연결한다.
// 네이티브 메시징 연결이 유지되는 동안 크롬은 서비스 워커를 종료하지 않는다.
ready.then(publish);
setInterval(() => ready.then(publish), RESEND_MS);
