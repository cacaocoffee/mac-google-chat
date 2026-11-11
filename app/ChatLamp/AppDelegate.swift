import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let didSetUpLoginItemKey = "didSetUpLoginItem"

    private let model = LampModel()
    private var statusController: StatusController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 이미 실행 중이면 아이콘이 두 개가 되므로 나중에 실행한 쪽을 종료한다.
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bridge.appBundleID)
            .filter { $0 != .current }
        if !others.isEmpty {
            NSApp.terminate(nil)
            return
        }

        UserDefaults.standard.register(defaults: [StatusController.showCountKey: true])
        NativeHostInstaller.install()
        setUpLoginItemOnce()

        let controller = StatusController()
        statusController = controller
        model.onChange = { controller.render($0) }
        model.start()
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
