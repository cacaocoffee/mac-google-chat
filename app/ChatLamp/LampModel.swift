import Foundation
import os

/// 메뉴 막대 아이콘이 보여 줄 상태.
enum LampLevel {
    /// 손쉬운 사용 권한이 없어 Dock 배지를 읽을 수 없다.
    case noPermission
    /// Google Chat 크롬 앱이 실행 중이 아니다.
    case closed
    /// Google Chat 앱은 실행 중인데 Dock에서 그 아이콘을 찾지 못했다.
    case unknown
    /// 안 읽은 메시지 없음.
    case none
    /// 안 읽은 메시지 있음. 아이콘이 초록색으로 바뀐다.
    case alert
}

struct LampState: Equatable {
    var level: LampLevel
    /// Dock 배지에 적힌 안 읽은 수. 숫자 없이 점만 달렸으면 nil.
    var count: Int?
}

/// Dock에 있는 Google Chat 앱 아이콘의 배지를 2초마다 읽어 메뉴 막대 상태로 바꾼다.
final class LampModel {
    static let pollInterval: TimeInterval = 2

    private let log = Logger(subsystem: AppDelegate.bundleID, category: "lamp")
    private let reader = DockBadgeReader()
    private var timer: Timer?

    private(set) var state = LampState(level: .noPermission, count: nil)
    var onChange: ((LampState) -> Void)?

    func start() {
        update()
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            self?.update()
        }
    }

    private func update() {
        let next = Self.state(for: reader.read())
        guard next != state else { return }
        state = next
        log.info("level=\(String(describing: next.level), privacy: .public) count=\(next.count ?? -1)")
        onChange?(next)
    }

    static func state(for reading: DockBadgeReader.Reading) -> LampState {
        switch reading {
        case .noPermission:
            return LampState(level: .noPermission, count: nil)
        case .notRunning:
            return LampState(level: .closed, count: nil)
        case .notInDock:
            return LampState(level: .unknown, count: nil)
        case .badge(nil):
            return LampState(level: .none, count: nil)
        case .badge(let label?):
            // 숫자 대신 점(•)만 달리는 경우도 있다. 그때는 개수 없이 초록색으로만 바꾼다.
            return LampState(level: .alert, count: Int(label.filter(\.isNumber)))
        }
    }
}
