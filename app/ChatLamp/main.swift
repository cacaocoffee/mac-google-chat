import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Dock 아이콘 없이 메뉴 막대에만 아이콘을 표시한다. Info.plist의 LSUIElement와 같은 뜻.
app.setActivationPolicy(.accessory)
app.run()
