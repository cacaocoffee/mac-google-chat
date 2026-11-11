// Google Chat 탭 하나를 지켜보다가 상태가 바뀌면 background.js에 알린다.
(() => {
  'use strict';

  const { judge, readSidebarCount } = globalThis.ChatLampDetect;
  const POLL_MS = 5000; // 왼쪽 목록 숫자는 이 간격으로 다시 읽는다
  const RESEND_MS = 20000; // 바뀐 것이 없어도 이 간격으로 다시 알린다. background.js는 60초 동안 소식이 없는 탭을 지운다

  let badge; // 페이지가 navigator.setAppBadge로 단 값. 아직 호출이 없으면 undefined
  let lastSent = '';
  let pending = null;
  const timers = [];
  const observer = new MutationObserver(schedule);

  function faviconHref() {
    const icons = document.querySelectorAll('link[rel~="icon" i]');
    return icons.length ? icons[icons.length - 1].href : null;
  }

  function send(force) {
    const state = judge({
      faviconHref: faviconHref(),
      badge,
      sidebarCount: readSidebarCount(document),
      title: document.title,
    });
    const key = JSON.stringify(state);
    if (!force && key === lastSent) return;
    lastSent = key;
    post({ type: 'tab-state', state });
  }

  function post(message) {
    try {
      chrome.runtime.sendMessage(message).catch(() => {});
    } catch (_) {
      // 확장을 다시 로드하면 이전 스크립트는 더 보낼 곳이 없다. 새로 들어온 스크립트에 맡기고 멈춘다.
      stop();
    }
  }

  // 변경이 몰려 와도 한 번만 읽는다.
  function schedule() {
    if (pending !== null) return;
    pending = setTimeout(() => {
      pending = null;
      send(false);
    }, 300);
  }

  function start() {
    // 파비콘과 제목은 <head>에 있다.
    if (document.head) {
      observer.observe(document.head, {
        childList: true,
        subtree: true,
        characterData: true,
        attributes: true,
        attributeFilter: ['href', 'rel'],
      });
    }
    timers.push(setInterval(() => send(false), POLL_MS));
    timers.push(setInterval(() => send(true), RESEND_MS));
    document.addEventListener('visibilitychange', schedule);
    window.addEventListener('focus', schedule);
    window.addEventListener('pagehide', () => post({ type: 'tab-gone' }));
    send(true);
  }

  function stop() {
    observer.disconnect();
    timers.forEach(clearInterval);
  }

  window.addEventListener('message', (event) => {
    if (event.origin !== location.origin) return;
    if (!event.data || event.data.chatlamp !== 'badge') return;
    badge = event.data.value;
    schedule();
  });

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
  else start();
})();
