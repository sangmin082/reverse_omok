import GameKit
import Observation
import UIKit

/// Game Center 로그인 상태. 온라인 대국에만 쓴다.
@MainActor
@Observable
final class GameCenterAuth {
    static let shared = GameCenterAuth()

    private(set) var isAuthenticated = false
    private(set) var isWorking = false
    private(set) var errorText: String?
    private var started = false

    private init() {}

    /// 로그인 절차를 시작한다. 여러 번 불러도 한 번만 등록된다.
    func start() {
        guard !started else {
            isAuthenticated = GKLocalPlayer.local.isAuthenticated
            return
        }
        started = true
        isWorking = true
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                guard let self else { return }
                if let viewController {
                    // 로그인 화면을 띄워야 한다.
                    Self.topViewController()?.present(viewController, animated: true)
                    return
                }
                self.isWorking = false
                self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                self.errorText = self.isAuthenticated ? nil : (error?.localizedDescription ?? "Game Center에 로그인되어 있지 않습니다.")
            }
        }
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
