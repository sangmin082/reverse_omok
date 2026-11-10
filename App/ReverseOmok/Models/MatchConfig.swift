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
    /// 이만큼 이으면 진다. 3목 7줄이 한 판이 짧고(약 40수) 무승부가 거의 없다.
    var runLength: Int = 3
    var boardSize: Int = 7

    /// 규칙별로 고를 수 있는 판 크기. 판이 클수록 한 판이 길어진다.
    static func boardSizes(for runLength: Int) -> [Int] {
        switch runLength {
        case 3: [5, 7, 9]
        case 4: [7, 9, 11]
        default: [9, 11, 13, 15]
        }
    }

    static func defaultBoardSize(for runLength: Int) -> Int {
        switch runLength {
        case 3: 7
        case 4: 9
        default: 15
        }
    }

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
