import AppKit
import ServiceManagement

/// 메뉴 막대 아이콘과 그 메뉴.
///
/// 안 읽은 메시지가 있으면 말풍선을 초록색으로 채우고 옆에 개수를 적는다.
/// 없으면 메뉴 막대 색을 따르는 빈 말풍선, Google Chat 앱이 꺼져 있거나 권한이 없으면 흐린 말풍선.
final class StatusController: NSObject, NSMenuDelegate {
    static let readmeURL = URL(string: "https://github.com/cacaocoffee/mac-google-chat#readme")!
    static let showCountKey = "showCount"

    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var state = LampState(level: .noPermission, count: nil)

    private var showCount: Bool {
        get { UserDefaults.standard.bool(forKey: Self.showCountKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.showCountKey) }
    }

    override init() {
        super.init()
        menu.delegate = self
        item.menu = menu
        render(state)
    }

    func render(_ state: LampState) {
        self.state = state
        guard let button = item.button else { return }

        let lit = state.level == .alert
        button.image = Self.icon(lit: lit)
        button.appearsDisabled = state.level == .noPermission || state.level == .closed

        if lit, showCount, let count = state.count, count > 0 {
            button.title = count > 99 ? "99+" : String(count)
            button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
            button.imagePosition = .imageLeading
        } else {
            button.title = ""
            button.imagePosition = .imageOnly
        }
        button.toolTip = "ChatLamp: \(Self.describe(state))"
        button.setAccessibilityLabel("Google Chat, \(Self.describe(state))")
    }

    private static func icon(lit: Bool) -> NSImage? {
        let size = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        if lit {
            let config = size.applying(.init(paletteColors: [.systemGreen]))
            let image = NSImage(systemSymbolName: "message.fill", accessibilityDescription: "새 메시지 있음")?
                .withSymbolConfiguration(config)
            image?.isTemplate = false
            return image
        }
        let image = NSImage(systemSymbolName: "message", accessibilityDescription: "Google Chat")?
            .withSymbolConfiguration(size)
        image?.isTemplate = true
        return image
    }

    static func describe(_ state: LampState) -> String {
        switch state.level {
        case .noPermission: return "손쉬운 사용 권한이 필요함"
        case .closed: return "Google Chat이 열려 있지 않음"
        case .unknown: return "새 메시지가 있는지 알 수 없음"
        case .none: return "새 메시지 없음"
        case .alert:
            if let count = state.count, count > 0 { return "새 메시지 있음 (\(count))" }
            return "새 메시지 있음"
        }
    }

    private static func hint(_ level: LampLevel) -> String? {
        switch level {
        case .noPermission: return "Dock의 Google Chat 배지를 읽으려면 권한을 허용하세요"
        case .closed: return "Google Chat 크롬 앱을 열어 두면 확인합니다"
        default: return nil
        }
    }

    // MARK: - 메뉴

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(withTitle: Self.describe(state), action: nil, keyEquivalent: "").isEnabled = false
        if let hint = Self.hint(state.level) {
            let hintItem = menu.addItem(withTitle: hint, action: nil, keyEquivalent: "")
            hintItem.isEnabled = false
            hintItem.indentationLevel = 1
        }
        if !DockBadgeReader.isTrusted {
            add("손쉬운 사용 권한 허용…", #selector(requestAccessibility))
        }
        menu.addItem(.separator())

        add("Google Chat 열기", #selector(openGoogleChat), key: "o")
        menu.addItem(.separator())

        add("아이콘 옆에 개수 표시", #selector(toggleShowCount)).state = showCount ? .on : .off
        add("로그인 시 열기", #selector(toggleLoginItem)).state = LoginItem.isEnabled ? .on : .off
        menu.addItem(.separator())

        add("설치 방법 보기…", #selector(openReadme))
        add("ChatLamp 종료", #selector(quit), key: "q")
    }

    @discardableResult
    private func add(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let menuItem = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
        menuItem.target = self
        return menuItem
    }

    @objc private func requestAccessibility() {
        DockBadgeReader.requestPermission()
        DockBadgeReader.openPermissionSettings()
    }

    @objc private func openGoogleChat() {
        GoogleChatLauncher.open()
    }

    @objc private func toggleShowCount() {
        showCount.toggle()
        render(state)
    }

    @objc private func toggleLoginItem() {
        LoginItem.setEnabled(!LoginItem.isEnabled)
    }

    @objc private func openReadme() {
        NSWorkspace.shared.open(Self.readmeURL)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

/// Google Chat을 연다. 크롬 앱으로 설치돼 있으면 그 앱을, 없으면 기본 브라우저로 연다.
enum GoogleChatLauncher {
    static let chatURL = URL(string: "https://chat.google.com/")!

    static func open() {
        if let app = installedWebApp() {
            NSWorkspace.shared.openApplication(at: app, configuration: .init())
        } else {
            NSWorkspace.shared.open(chatURL)
        }
    }

    /// `~/Applications/Chrome Apps.localized` 같은 폴더에서 chat.google.com을 여는 웹 앱을 찾는다.
    private static func installedWebApp() -> URL? {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        let folders = ((try? fm.contentsOfDirectory(at: home, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.lastPathComponent.hasSuffix("Apps.localized") }
        for folder in folders {
            for app in (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            where app.pathExtension == "app" {
                let plist = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist"))
                if let url = plist?["CrAppModeShortcutURL"] as? String, url.hasPrefix("https://chat.google.com") {
                    return app
                }
            }
        }
        return nil
    }
}

/// 로그인 시 열기. macOS 13부터 쓰는 SMAppService로 등록한다.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "로그인 시 열기를 바꾸지 못했습니다"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}
