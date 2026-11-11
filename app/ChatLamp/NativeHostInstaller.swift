import Foundation
import os

/// 크롬이 chatlamp-host를 찾을 수 있도록 네이티브 메시징 호스트 매니페스트를 쓴다.
///
/// 크롬은 `~/Library/Application Support/<브라우저>/NativeMessagingHosts/<호스트 이름>.json`에서
/// 실행 파일 경로를 읽는다. 경로가 앱 위치에 따라 달라지므로 앱이 켜질 때마다 다시 쓴다.
enum NativeHostInstaller {
    /// 크롬 계열 브라우저의 Application Support 아래 폴더. 깔려 있는 것에만 쓴다.
    static let browserFolders = [
        "Google/Chrome",
        "Google/Chrome Beta",
        "Google/Chrome Dev",
        "Google/Chrome Canary",
        "Chromium",
        "Microsoft Edge",
        "BraveSoftware/Brave-Browser",
    ]

    private static let log = Logger(subsystem: Bridge.appBundleID, category: "install")

    /// 매니페스트를 쓴 브라우저 폴더 목록을 돌려준다.
    @discardableResult
    static func install() -> [String] {
        guard let hostPath = Bundle.main.url(forAuxiliaryExecutable: "chatlamp-host")?.path else {
            log.error("chatlamp-host not found in bundle")
            return []
        }
        let manifest: [String: Any] = [
            "name": Bridge.hostName,
            "description": "ChatLamp: Google Chat 안 읽은 메시지를 메뉴 막대에 표시",
            "path": hostPath,
            "type": "stdio",
            "allowed_origins": Bridge.extensionIDs.map { "chrome-extension://\($0)/" },
        ]
        guard let data = try? JSONSerialization.data(
            withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        else { return [] }

        let fm = FileManager.default
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        var written: [String] = []
        for folder in browserFolders {
            let browserDir = support.appendingPathComponent(folder)
            guard fm.fileExists(atPath: browserDir.path) else { continue }
            let hostsDir = browserDir.appendingPathComponent("NativeMessagingHosts")
            let file = hostsDir.appendingPathComponent("\(Bridge.hostName).json")
            do {
                try fm.createDirectory(at: hostsDir, withIntermediateDirectories: true)
                if (try? Data(contentsOf: file)) != data {
                    try data.write(to: file, options: .atomic)
                }
                written.append(folder)
            } catch {
                log.error("manifest write failed for \(folder, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        log.info("native host manifest in: \(written.joined(separator: ", "), privacy: .public)")
        return written
    }
}
