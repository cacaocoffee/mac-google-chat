// 확장 아이콘(PNG)과 앱 아이콘(icns)을 그린다. 결과물은 저장소에 함께 올린다.
//
//   swift scripts/make-icons.swift
//
// 초록 둥근 사각형 위에 흰 말풍선, 말풍선 오른쪽 위에 노란 불빛 점.
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[0])
    .deletingLastPathComponent().deletingLastPathComponent()

func png(size: Int, inset: CGFloat) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let s = CGFloat(size)
    let tile = NSRect(x: 0, y: 0, width: s, height: s).insetBy(dx: s * inset, dy: s * inset)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: tile.width * 0.23, yRadius: tile.width * 0.23)
    NSGradient(starting: NSColor(srgbRed: 0.20, green: 0.74, blue: 0.40, alpha: 1),
               ending: NSColor(srgbRed: 0.05, green: 0.50, blue: 0.27, alpha: 1))!
        .draw(in: tilePath, angle: -90)

    // 말풍선: 둥근 사각형 + 왼쪽 아래 꼬리
    let w = tile.width
    let bubble = NSRect(x: tile.minX + w * 0.18, y: tile.minY + w * 0.30, width: w * 0.64, height: w * 0.46)
    let path = NSBezierPath(roundedRect: bubble, xRadius: bubble.height * 0.42, yRadius: bubble.height * 0.42)
    let tail = NSBezierPath()
    tail.move(to: NSPoint(x: bubble.minX + w * 0.12, y: bubble.minY + w * 0.04))
    tail.line(to: NSPoint(x: bubble.minX + w * 0.06, y: bubble.minY - w * 0.12))
    tail.line(to: NSPoint(x: bubble.minX + w * 0.28, y: bubble.minY + w * 0.02))
    tail.close()
    path.append(tail)
    NSColor.white.setFill()
    path.fill()

    // 불빛 점
    let r = w * 0.13
    let dot = NSRect(x: bubble.maxX - r * 1.1, y: bubble.maxY - r * 0.9, width: r * 2, height: r * 2)
    NSColor(srgbRed: 1.0, green: 0.80, blue: 0.10, alpha: 1).setFill()
    NSBezierPath(ovalIn: dot).fill()
    NSColor(srgbRed: 0.05, green: 0.50, blue: 0.27, alpha: 1).setStroke()
    let ring = NSBezierPath(ovalIn: dot)
    ring.lineWidth = max(1, w * 0.025)
    ring.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default

// 확장: 툴바용은 여백 없이 꽉 채운다.
let extIcons = root.appendingPathComponent("extension/icons")
try fm.createDirectory(at: extIcons, withIntermediateDirectories: true)
for size in [16, 32, 48, 128] {
    try png(size: size, inset: 0.02).write(to: extIcons.appendingPathComponent("icon\(size).png"))
}

// 앱: macOS 아이콘 격자에 맞춰 둘레에 여백을 둔다.
let iconset = fm.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try png(size: base, inset: 0.1).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try png(size: base * 2, inset: 0.1).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("app/AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
print("확장 아이콘: \(extIcons.path)\n앱 아이콘: app/AppIcon.icns")
