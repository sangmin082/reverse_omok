import Foundation
import XCTest
@testable import OmokCore

/// 난이도 간 대국 결과를 출력한다. 오래 걸리므로 OMOK_BENCH=1일 때만 돈다.
final class StrengthBenchmark: XCTestCase {
    func testDifficultyLadder() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["OMOK_BENCH"] == "1")
        let size = Int(ProcessInfo.processInfo.environment["OMOK_SIZE"] ?? "") ?? 9
        let games = Int(ProcessInfo.processInfo.environment["OMOK_GAMES"] ?? "") ?? 4
        let pairs: [(AIDifficulty, AIDifficulty)] = [(.normal, .easy), (.hard, .easy), (.hard, .normal)]
        var rng = SplitMix64(seed: 2026)
        for (strong, weak) in pairs {
            var wins = 0, losses = 0, draws = 0
            for g in 0..<games {
                let strongIsBlack = g.isMultiple(of: 2)
                var game = Game(size: size)
                while !game.isOver {
                    let isStrong = (game.currentPlayer == .black) == strongIsBlack
                    let ai = AIPlayer(difficulty: isStrong ? strong : weak)
                    try game.play(at: XCTUnwrap(ai.chooseMove(in: game, using: &rng)))
                }
                switch game.result?.winner {
                case nil: draws += 1
                case .black?: if strongIsBlack { wins += 1 } else { losses += 1 }
                case .white?: if strongIsBlack { losses += 1 } else { wins += 1 }
                }
                print("[bench] \(strong) vs \(weak) game \(g): \(String(describing: game.result.map { $0.winner.map { "\($0)" } ?? "draw" })) in \(game.moves.count) moves")
            }
            print("[bench] \(size)x\(size) \(strong) vs \(weak): W\(wins) L\(losses) D\(draws)")
        }
    }
}
