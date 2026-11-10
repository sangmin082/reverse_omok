import Foundation
import XCTest
@testable import OmokCore

/// 규칙별 평균 수순 길이를 출력한다. OMOK_BENCH=1일 때만 돈다.
final class LengthProbe: XCTestCase {
    func testGameLengths() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["OMOK_BENCH"] == "1")
        var rng = SplitMix64(seed: 99)
        let rules = [(9, 5), (5, 3), (6, 3), (7, 3), (8, 3), (6, 4), (7, 4), (8, 4), (9, 4)]
        for (size, runLength) in rules {
            var total = 0, draws = 0, blackWins = 0
            let n = 10
            for _ in 0..<n {
                var game = Game(size: size, runLength: runLength)
                while !game.isOver {
                    try game.play(at: XCTUnwrap(AIPlayer(difficulty: .normal).chooseMove(in: game, using: &rng)))
                }
                total += game.moves.count
                if game.result == .draw { draws += 1 }
                if game.result?.winner == .black { blackWins += 1 }
            }
            print("[probe] \(runLength)목 \(size)줄: 평균 \(total / n)수 / \(size * size)칸, 무승부 \(draws)/\(n), 흑승 \(blackWins)/\(n)")
        }
    }
}
