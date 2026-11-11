import Foundation

/// 크롬 확장 · 네이티브 호스트 · 메뉴 막대 앱이 함께 쓰는 이름.
///
/// 흐름: 확장 → (크롬 네이티브 메시징) → chatlamp-host → (분산 알림) → ChatLamp 앱
enum Bridge {
    static let appBundleID = "io.github.cacaocoffee.chatlamp"

    /// 크롬 네이티브 메시징 호스트 이름. 확장의 background.js에 같은 값이 있다.
    static let hostName = "io.github.cacaocoffee.chatlamp"

    /// manifest.json의 `key`로 고정한 확장 ID. 이 ID의 확장만 호스트를 실행할 수 있다.
    static let extensionIDs = ["hieanablcjkmeeohhplglfaegdagigmk"]

    /// 호스트가 확장에서 받은 상태를 앱에 넘길 때.
    static let stateNotification = Notification.Name("io.github.cacaocoffee.chatlamp.state")
    /// 호스트가 끝날 때(크롬이 꺼지거나 확장이 연결을 끊을 때).
    static let byeNotification = Notification.Name("io.github.cacaocoffee.chatlamp.bye")
    /// 앱이 막 켜졌을 때 실행 중인 호스트들에게 마지막 상태를 다시 보내 달라고 할 때.
    static let requestNotification = Notification.Name("io.github.cacaocoffee.chatlamp.request")

    /// userInfo 키: 호스트 하나를 가리키는 ID. 크롬 프로필마다 호스트가 따로 실행된다.
    static let hostKey = "host"
    /// userInfo 키: 확장이 보낸 JSON 문자열 그대로.
    static let payloadKey = "payload"
}
