// 감지 규칙 테스트. 실행: node --test test/detect.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const { unreadFromFavicon, countFromTitle, judge } = require('../extension/content/detect.js');

test('파비콘: 지금 화면의 점 있음/없음', () => {
  assert.equal(unreadFromFavicon('https://www.gstatic.com/x/logo_favicon_dot_64px.png'), true);
  assert.equal(unreadFromFavicon('https://www.gstatic.com/x/logo_favicon_no_dot_64px.png'), false);
});

test('파비콘: 이전 화면 이름', () => {
  assert.equal(unreadFromFavicon('https://ssl.gstatic.com/ui/v1/icons/mail/images/favicon_chat_new_notif_r2.ico'), true);
  assert.equal(unreadFromFavicon('https://ssl.gstatic.com/ui/v1/icons/mail/images/favicon_chat_new_non_notif_r2.ico'), false);
  assert.equal(unreadFromFavicon('https://ssl.gstatic.com/ui/v1/icons/mail/images/favicon_chat_r2.ico'), false);
});

test('파비콘: 모르는 주소나 없음은 null', () => {
  assert.equal(unreadFromFavicon('https://chat.google.com/favicon.ico'), null);
  assert.equal(unreadFromFavicon(null), null);
});

test('제목: Chat이 들어간 제목의 괄호 숫자만 읽는다', () => {
  assert.equal(countFromTitle('Chat (3)'), 3);
  assert.equal(countFromTitle('(12+) Google Chat'), 12);
  assert.equal(countFromTitle('Google Chat'), null);
  assert.equal(countFromTitle('회의 (2)'), null);
});

test('판단: 파비콘이 답을 주면 그것을 따르고 개수는 배지에서 가져온다', () => {
  const s = judge({ faviconHref: 'a/logo_favicon_dot_64px.png', badge: 4, sidebarCount: null, title: 'Google Chat' });
  assert.deepEqual([s.level, s.count, s.via], ['alert', 4, 'favicon']);
});

test('판단: 파비콘이 다 읽음이면 배지 숫자가 있어도 새 메시지 없음', () => {
  const s = judge({ faviconHref: 'a/logo_favicon_no_dot_64px.png', badge: 2, sidebarCount: 2, title: '' });
  assert.deepEqual([s.level, s.count], ['none', null]);
});

test('판단: 파비콘을 모르면 Dock 배지, 그다음 왼쪽 목록', () => {
  assert.equal(judge({ faviconHref: null, badge: 'flag', sidebarCount: null, title: '' }).level, 'alert');
  assert.equal(judge({ faviconHref: null, badge: 0, sidebarCount: 5, title: '' }).level, 'none');
  const bySidebar = judge({ faviconHref: null, badge: undefined, sidebarCount: 5, title: '' });
  assert.deepEqual([bySidebar.level, bySidebar.count, bySidebar.via], ['alert', 5, 'sidebar']);
});

test('판단: 아무 신호도 없으면 unknown', () => {
  const s = judge({ faviconHref: null, badge: undefined, sidebarCount: null, title: 'Google Chat' });
  assert.deepEqual([s.level, s.count, s.via], ['unknown', null, null]);
});
