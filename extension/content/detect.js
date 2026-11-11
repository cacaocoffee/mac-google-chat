// Google Chat 화면에서 안 읽은 메시지를 알아내는 규칙.
// 화면을 바꾸지 않는 함수만 둔다. node 테스트(test/detect.test.js)에서도 불러 쓴다.
//
// 근거: ankurk91/google-chat-tauri가 2026-09-24에 로그인된 화면에서 확인한 구조.
(function (root) {
  'use strict';

  /**
   * 파비콘 주소로 안 읽은 메시지가 있는지 판단한다.
   * Google Chat은 안 읽은 메시지가 생기면 파비콘을 다른 파일로 바꾼다.
   *   지금 화면:  ..._dot_64px.png (있음) / ..._no_dot_64px.png (없음)
   *   이전 화면:  favicon_chat_new_notif_r2 (있음) / favicon_chat_r2 · favicon_chat_new_non_notif_r2 (없음)
   * 알 수 없는 주소면 null.
   */
  function unreadFromFavicon(href) {
    if (!href) return null;
    if (/no_dot/.test(href)) return false;
    if (/_dot[_.]/.test(href)) return true;
    if (/favicon_chat_new_notif/.test(href)) return true;
    if (/favicon_chat_new_non_notif|favicon_chat_r\d/.test(href)) return false;
    return null;
  }

  /**
   * 탭 제목에서 안 읽은 수를 읽는다. "Chat (3)" 같은 형식일 때만.
   * 숫자가 없으면 0이 아니라 null이다. 숫자가 없다고 다 읽었다는 뜻은 아니기 때문이다.
   */
  function countFromTitle(title) {
    if (!title || !/chat|채팅/i.test(title)) return null;
    const match = title.match(/\((\d{1,4})\+?\)/);
    return match ? Number(match[1]) : null;
  }

  /**
   * 왼쪽 목록의 「채팅」「스페이스」 묶음 머리에 적힌 숫자를 더한다.
   * 묶음마다 data-section-type이 붙어 있고(1 채팅, 2 스페이스, 10 바로가기),
   * 머리 버튼의 aria-labelledby에 적힌 ID 가운데 마지막이 숫자가 적힌 요소다.
   * 바로가기는 앞의 둘을 되풀이하므로 뺀다.
   * 목록이 화면에 없으면(창이 가려지면 Google Chat이 목록을 지운다) null.
   */
  function readSidebarCount(doc) {
    const sections = doc.querySelectorAll('[data-section-type="1"],[data-section-type="2"]');
    if (sections.length === 0) return null;
    let total = 0;
    for (const section of sections) {
      const toggle = section.querySelector('[role="button"][aria-labelledby][aria-controls]');
      const ids = toggle ? toggle.getAttribute('aria-labelledby').trim().split(/\s+/) : [];
      if (ids.length < 2) continue;
      const badge = doc.getElementById(ids[ids.length - 1]);
      const count = parseInt(badge ? badge.textContent : '', 10);
      if (!Number.isNaN(count)) total += count;
    }
    return total;
  }

  /**
   * 신호를 합쳐 탭 하나의 상태를 정한다.
   *
   * 불을 켤지는 파비콘 → Dock 배지 → 왼쪽 목록 → 탭 제목 순으로, 먼저 답을 주는 것을 따른다.
   * 파비콘을 맨 앞에 두는 이유: 창이 가려져도 바뀌고, Google이 「알릴 만한 것이 있다」고 정한 결과라서다.
   * 개수는 불이 켜졌을 때만, 숫자를 주는 신호 가운데 처음 나오는 양수를 쓴다.
   *
   * @param {{faviconHref: ?string, badge: (number|'flag'|undefined), sidebarCount: ?number, title: ?string}} input
   *   badge는 페이지가 navigator.setAppBadge로 단 값. 'flag'는 숫자 없이 점만 단 경우, undefined는 아직 호출이 없는 경우.
   */
  function judge({ faviconHref, badge, sidebarCount, title }) {
    const favicon = unreadFromFavicon(faviconHref);
    const badgeCount = typeof badge === 'number' && Number.isFinite(badge) ? badge : null;
    const sidebar = typeof sidebarCount === 'number' ? sidebarCount : null;
    const titleCount = countFromTitle(title);

    let unread = null;
    let via = null;
    if (favicon !== null) {
      unread = favicon;
      via = 'favicon';
    } else if (badge === 'flag' || badgeCount !== null) {
      unread = badge === 'flag' || badgeCount > 0;
      via = 'badge';
    } else if (sidebar !== null) {
      unread = sidebar > 0;
      via = 'sidebar';
    } else if (titleCount !== null) {
      unread = titleCount > 0;
      via = 'title';
    }

    const count = [badgeCount, sidebar, titleCount].find((n) => n !== null && n > 0);
    return {
      level: unread === null ? 'unknown' : unread ? 'alert' : 'none',
      count: unread && count !== undefined ? count : null,
      via,
      signals: { favicon, badge: badge === undefined ? null : badge, sidebar, title: titleCount },
    };
  }

  const api = { unreadFromFavicon, countFromTitle, readSidebarCount, judge };
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.ChatLampDetect = api;
})(globalThis);
