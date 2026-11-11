import Foundation
import os

/// 메뉴 막대 아이콘이 보여 줄 상태. 아래로 갈수록 우선한다.
enum LampLevel: Int, Comparable {
    /// 연결된 확장이 하나도 없다. 크롬이 꺼져 있거나 확장을 설치하지 않았다.
    case disconnected
    /// 확장은 연결됐지만 열린 Google Chat 탭(또는 앱 창)이 없다.
    case closed
    /// Google Chat은 열려 있지만 안 읽은 메시지가 있는지 알아내지 못했다.
    case unknown
    /// 안 읽은 메시지 없음.
    case none
    /// 안 읽은 메시지 있음. 아이콘이 초록색으로 바뀐다.
    case alert

    init?(payload value: String) {
        switch value {
        case "closed": self = .closed
        case "unknown": self = .unknown
        case "none": self = .none
        case "alert": self = .alert
        default: return nil
        }
    }

    static func < (lhs: LampLevel, rhs: LampLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct LampState: Equatable {
    var level: LampLevel
    /// Google Chat이 보여 주는 안 읽은 수. 알아내지 못했으면 nil.
    var count: Int?
}

/// 네이티브 호스트들이 보내는 상태를 받아 하나로 합친다.
///
/// 크롬 프로필마다 확장과 호스트가 따로 실행되므로 호스트가 여러 개일 수 있다.
/// 가장 높은 상태를 따르고, 개수는 그중 가장 큰 값을 쓴다.
final class LampModel: NSObject {
    /// 이 시간 동안 소식이 없는 호스트는 끊긴 것으로 본다. 확장은 25초마다 상태를 다시 보낸다.
    static let staleAfter: TimeInterval = 90

    private struct Report {
        var level: LampLevel
        var count: Int?
        var seen: Date
    }

    private let log = Logger(subsystem: Bridge.appBundleID, category: "lamp")
    private var reports: [String: Report] = [:]
    private var sweepTimer: Timer?

    private(set) var state = LampState(level: .disconnected, count: nil)
    var onChange: ((LampState) -> Void)?

    func start() {
        let center = DistributedNotificationCenter.default()
        // 메뉴 막대 앱은 활성 상태가 되는 일이 드물다. 기본값(.coalesce)이면 앱이
        // 활성화될 때까지 알림이 쌓이기만 하므로 바로 받도록 한다.
        center.addObserver(self, selector: #selector(stateReceived(_:)),
                           name: Bridge.stateNotification, object: nil,
                           suspensionBehavior: .deliverImmediately)
        center.addObserver(self, selector: #selector(byeReceived(_:)),
                           name: Bridge.byeNotification, object: nil,
                           suspensionBehavior: .deliverImmediately)
        sweepTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.dropStaleReports()
        }
        // 앱보다 먼저 실행 중이던 호스트가 있으면 마지막 상태를 다시 받는다.
        center.postNotificationName(Bridge.requestNotification, object: nil, userInfo: nil,
                                    deliverImmediately: true)
    }

    @objc private func stateReceived(_ note: Notification) {
        guard let host = note.userInfo?[Bridge.hostKey] as? String,
              let payload = note.userInfo?[Bridge.payloadKey] as? String,
              let object = try? JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any],
              object["type"] as? String == "state",
              let levelName = object["level"] as? String,
              let level = LampLevel(payload: levelName)
        else { return }

        let count = (object["count"] as? NSNumber)?.intValue
        reports[host] = Report(level: level, count: count, seen: Date())
        recompute()
    }

    @objc private func byeReceived(_ note: Notification) {
        guard let host = note.userInfo?[Bridge.hostKey] as? String else { return }
        reports[host] = nil
        recompute()
    }

    private func dropStaleReports() {
        let cutoff = Date().addingTimeInterval(-Self.staleAfter)
        let before = reports.count
        reports = reports.filter { $0.value.seen >= cutoff }
        if reports.count != before { recompute() }
    }

    private func recompute() {
        let level = reports.values.map(\.level).max() ?? .disconnected
        let count = level == .alert
            ? reports.values.filter { $0.level == .alert }.compactMap(\.count).max()
            : nil
        let next = LampState(level: level, count: count)
        guard next != state else { return }
        state = next
        log.info("level=\(String(describing: level), privacy: .public) count=\(count ?? -1) hosts=\(self.reports.count)")
        onChange?(next)
    }
}
