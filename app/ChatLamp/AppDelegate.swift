import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let bundleID = "io.github.cacaocoffee.chatlamp"

    private static let didSetUpLoginItemKey = "didSetUpLoginItem"
    private static let didAskAccessibilityKey = "didAskAccessibility"

    private let model = LampModel()
    private var statusController: StatusController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 이미 실행 중이면 아이콘이 두 개가 되므로 나중에 실행한 쪽을 종료한다.
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID)
            .filter { $0 != .current }
        if !others.isEmpty {
            NSApp.terminate(nil)
            return
        }

        UserDefaults.standard.register(defaults: [StatusController.showCountKey: true])
        setUpLoginItemOnce()
        askAccessibilityOnce()

        let controller = StatusController()
        statusController = controller
        model.onChange = { controller.render($0) }
        model.start()
    }

    /// 처음 실행할 때 한 번만 손쉬운 사용 권한을 묻는다. Dock 배지를 읽는 데 필요하다.
    /// 거절했으면 다시 묻지 않고, 메뉴의 「손쉬운 사용 권한 허용…」으로 허용할 수 있다.
    private func askAccessibilityOnce() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.didAskAccessibilityKey), !DockBadgeReader.isTrusted else { return }
        defaults.set(true, forKey: Self.didAskAccessibilityKey)
        DockBadgeReader.requestPermission()
    }

    /// 처음 실행할 때 한 번만 로그인 항목에 넣는다. 카카오톡처럼 켜 두는 앱이라서다.
    /// 빌드 폴더에서 바로 실행한 개발용 앱은 넣지 않는다.
    private func setUpLoginItemOnce() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.didSetUpLoginItemKey) else { return }
        let path = Bundle.main.bundlePath
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard path.hasPrefix("/Applications/") || path.hasPrefix(home + "/Applications/") else { return }
        defaults.set(true, forKey: Self.didSetUpLoginItemKey)
        if !LoginItem.isEnabled { LoginItem.setEnabled(true) }
    }
}
