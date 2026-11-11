import AppKit

// 크롬 네이티브 메시징 호스트.
//
// 확장이 chrome.runtime.connectNative()를 부르면 크롬이 이 프로그램을 실행하고,
// 표준 입력으로 [길이 4바이트(리틀 엔디언)][JSON] 묶음을 계속 보낸다.
// 받은 JSON은 분산 알림으로 메뉴 막대 앱에 그대로 넘긴다. 표준 입력이 닫히면
// (크롬 종료, 확장 다시 로드) 앱에 끝났다고 알리고 종료한다.

let hostID = UUID().uuidString
let center = DistributedNotificationCenter.default()
var lastPayload: String?

func post(_ name: Notification.Name, payload: String? = nil) {
    var info = [Bridge.hostKey: hostID]
    if let payload { info[Bridge.payloadKey] = payload }
    center.postNotificationName(name, object: nil, userInfo: info, deliverImmediately: true)
}

/// 확장에 답을 보낸다. 형식은 받을 때와 같다.
func reply(_ object: [String: Any]) {
    guard let body = try? JSONSerialization.data(withJSONObject: object) else { return }
    var length = UInt32(body.count).littleEndian
    var frame = Data(bytes: &length, count: 4)
    frame.append(body)
    FileHandle.standardOutput.write(frame)
}

/// 정확히 count바이트를 읽는다. 중간에 입력이 끝나면 nil.
func readExactly(_ count: Int) -> Data? {
    var data = Data()
    while data.count < count {
        guard let chunk = try? FileHandle.standardInput.read(upToCount: count - data.count),
              !chunk.isEmpty else { return nil }
        data.append(chunk)
    }
    return data
}

func appIsRunning() -> Bool {
    !NSRunningApplication.runningApplications(withBundleIdentifier: Bridge.appBundleID).isEmpty
}

center.addObserver(forName: Bridge.requestNotification, object: nil, queue: .main) { _ in
    if let lastPayload { post(Bridge.stateNotification, payload: lastPayload) }
}

Thread.detachNewThread {
    while let header = readExactly(4) {
        let length = header.withUnsafeBytes { Int(UInt32(littleEndian: $0.loadUnaligned(as: UInt32.self))) }
        guard let body = readExactly(length), let payload = String(data: body, encoding: .utf8) else { break }
        DispatchQueue.main.async {
            lastPayload = payload
            post(Bridge.stateNotification, payload: payload)
            reply(["type": "ack", "appRunning": appIsRunning()])
        }
    }
    DispatchQueue.main.async {
        post(Bridge.byeNotification)
        exit(0)
    }
}

RunLoop.main.run()
