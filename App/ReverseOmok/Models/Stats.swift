import Foundation
import OmokCore

/// 컴퓨터 대전 난이도별 전적.
struct Stats: Codable, Equatable {
    struct Record: Codable, Equatable {
        var wins = 0
        var losses = 0
        var draws = 0

        var total: Int { wins + losses + draws }
    }

    var records: [AIDifficulty: Record] = [:]

    subscript(_ difficulty: AIDifficulty) -> Record {
        get { records[difficulty] ?? Record() }
        set { records[difficulty] = newValue }
    }

    private static let key = "stats"

    static func load() -> Stats {
        guard let data = UserDefaults.standard.data(forKey: key),
              let stats = try? JSONDecoder().decode(Stats.self, from: data) else { return Stats() }
        return stats
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }

    static func record(_ result: GameResult, humanStone: Stone, difficulty: AIDifficulty) {
        var stats = load()
        if let winner = result.winner {
            if winner == humanStone { stats[difficulty].wins += 1 } else { stats[difficulty].losses += 1 }
        } else {
            stats[difficulty].draws += 1
        }
        stats.save()
    }
}
