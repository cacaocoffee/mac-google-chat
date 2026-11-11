// Google Chat이 Dock 배지를 달 때 부르는 navigator.setAppBadge를 감싸 그 값을 확장에 알린다.
// 페이지와 같은 실행 환경(MAIN world)에서 페이지 스크립트보다 먼저 돌아야 감쌀 수 있다.
// 원래 함수는 그대로 불러 Dock 배지는 전과 똑같이 달린다.
(() => {
  const proto = globalThis.Navigator && Navigator.prototype;
  if (!proto || typeof proto.setAppBadge !== 'function' || proto.setAppBadge.__chatlamp) return;

  const report = (value) => {
    try {
      window.top.postMessage({ chatlamp: 'badge', value }, 'https://chat.google.com');
    } catch (_) {
      // 맨 위 창이 다른 사이트면 보내지 않는다.
    }
  };

  const originalSet = proto.setAppBadge;
  const setAppBadge = function (contents) {
    report(contents === undefined ? 'flag' : Number(contents));
    return originalSet.apply(this, arguments);
  };
  setAppBadge.__chatlamp = true;
  proto.setAppBadge = setAppBadge;

  const originalClear = proto.clearAppBadge;
  if (typeof originalClear === 'function') {
    proto.clearAppBadge = function () {
      report(0);
      return originalClear.apply(this, arguments);
    };
  }
})();
