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

/// 고를 수 있는 규칙. 줄 길이마다 무승부가 적고 너무 길지 않은 판 크기를 짝지어 둔다.
enum GameRule: String, Codable, CaseIterable, Identifiable {
    /// 4개를 이으면 진다. 한 판이 짧다.
    case four
    /// 5개를 이으면 진다. 9줄 이하는 무승부가 대부분이라 11줄을 쓴다.
    case five

    var id: String { rawValue }

    var runLength: Int {
        switch self {
        case .four: 4
        case .five: 5
        }
    }

    var boardSize: Int {
        switch self {
        case .four: 8
        case .five: 11
        }
    }

    var displayName: String {
        switch self {
        case .four: "4목 · 짧게"
        case .five: "5목 · 길게"
        }
    }

    var shortName: String { "\(runLength)목 \(boardSize)줄" }

    func newGame() -> Game {
        Game(size: boardSize, runLength: runLength)
    }

    func matches(_ board: Board) -> Bool {
        board.size == boardSize && board.runLength == runLength
    }
}

/// 한 판을 시작할 때 고르는 설정.
struct MatchConfig: Codable, Equatable {
    var mode: GameMode = .vsAI
    var difficulty: AIDifficulty = .normal
    /// 컴퓨터 대전에서 사람이 잡는 돌.
    var humanStone: Stone = .black
    var rule: GameRule = .four

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
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode(SavedMatch.self, from: data) else { return nil }
        // 지금은 없는 규칙(예: 3목 7줄)으로 저장된 판은 이어 할 수 없다.
        guard saved.config.rule.matches(saved.game.board) else { return nil }
        return saved
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
