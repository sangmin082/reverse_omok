import Foundation
import OmokCore

enum GameMode: String, Codable, CaseIterable, Identifiable {
    case vsAI
    case twoPlayer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vsAI: "컴퓨터와"
        case .twoPlayer: "둘이서"
        }
    }
}

/// 한 판을 시작할 때 고르는 설정.
struct MatchConfig: Codable, Equatable {
    var mode: GameMode = .vsAI
    var difficulty: AIDifficulty = .normal
    /// 컴퓨터 대전에서 사람이 잡는 돌.
    var humanStone: Stone = .black
    var boardSize: Int = 15

    func isHuman(_ stone: Stone) -> Bool {
        mode == .twoPlayer || stone == humanStone
    }

    func playerName(_ stone: Stone) -> String {
        switch mode {
        case .twoPlayer: stone.displayName
        case .vsAI: stone == humanStone ? "나" : "컴퓨터"
        }
    }
}

extension Stone {
    var displayName: String { self == .black ? "흑" : "백" }
}

/// 이어하기용으로 진행 중인 판을 저장한다.
struct SavedMatch: Codable {
    var config: MatchConfig
    var game: Game
    var statsRecorded: Bool

    private static let key = "savedMatch"

    static func load() -> SavedMatch? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SavedMatch.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
