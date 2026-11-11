import AppKit
import ApplicationServices

/// Dock에 있는 Google Chat 앱 아이콘의 배지(빨간 숫자)를 읽는다.
///
/// Google Chat을 크롬 앱으로 설치해 쓰면 Google Chat이 안 읽은 수를 그 앱의 Dock 아이콘에 단다.
/// 다른 앱의 Dock 배지를 읽는 공개 API가 없어서, 손쉬운 사용 API로 Dock 항목의
/// AXStatusLabel 값을 읽는다. 그래서 ChatLamp에 손쉬운 사용 권한이 있어야 한다.
final class DockBadgeReader {
    enum Reading: Equatable {
        /// 손쉬운 사용 권한이 없다.
        case noPermission
        /// Google Chat 앱이 실행 중이 아니다.
        case notRunning
        /// 실행 중인데 Dock에서 그 항목을 찾지 못했다.
        case notInDock
        /// Dock 항목을 읽었다. 배지가 없으면 nil.
        case badge(String?)
    }

    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// macOS의 권한 요청 창을 띄운다. 이미 허용돼 있으면 아무 일도 하지 않는다.
    static func requestPermission() {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)
    }

    static func openPermissionSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// 번들 ID → Google Chat 크롬 앱인지. Info.plist를 매번 읽지 않으려고 기억해 둔다.
    private var isChatApp: [String: Bool] = [:]

    func read() -> Reading {
        guard Self.isTrusted else { return .noPermission }
        guard let chat = runningChatApp(), let chatPath = chat.bundleURL?.standardizedFileURL.path else {
            return .notRunning
        }
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            return .notInDock
        }
        let dockElement = AXUIElementCreateApplication(dock.processIdentifier)
        for list in children(of: dockElement) {
            for item in children(of: list) {
                guard let url = urlValue(item, "AXURL"), url.standardizedFileURL.path == chatPath else { continue }
                return .badge(stringValue(item, "AXStatusLabel"))
            }
        }
        return .notInDock
    }

    /// 크롬 계열 브라우저가 만든 웹 앱 가운데 chat.google.com을 여는 것.
    /// 크롬 앱의 번들 ID는 `com.google.Chrome.app.<ID>` 꼴이고 Info.plist에 여는 주소가 적혀 있다.
    private func runningChatApp() -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { app in
            guard let id = app.bundleIdentifier, id.contains(".app.") else { return false }
            if let known = isChatApp[id] { return known }
            let url = app.bundleURL.flatMap { Bundle(url: $0)?.object(forInfoDictionaryKey: "CrAppModeShortcutURL") as? String }
            let result = url?.hasPrefix("https://chat.google.com") ?? false
            isChatApp[id] = result
            return result
        }
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success else {
            return []
        }
        return value as? [AXUIElement] ?? []
    }

    private func stringValue(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        let text = value as? String
        return text?.isEmpty == true ? nil : text
    }

    private func urlValue(_ element: AXUIElement, _ attribute: String) -> URL? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? URL
    }
}
