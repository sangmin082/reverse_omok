import XCTest
@testable import OmokCore

/// 테스트를 재현 가능하게 하는 시드 고정 난수 생성기.
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

final class AITests: XCTestCase {
    private func p(_ r: Int, _ c: Int) -> Position { Position(row: r, col: c) }

    /// 증분 갱신한 금수 판정이 Board의 직접 계산과 항상 같은지 무작위 대국으로 확인한다.
    func testSearchStateMatchesBruteForce() {
        var rng = SplitMix64(seed: 42)
        for size in [5, 7, 9] {
            for _ in 0..<20 {
                var board = Board(size: size)
                var state = SearchState(board: board)
                var history: [Int] = []
                var color = Stone.black
                while !board.isFull {
                    // 금수도 가끔 둬서 5목 이상 창까지 검증한다.
                    let empties = board.emptyPositions
                    let q = empties.randomElement(using: &rng)!
                    board.place(color, at: q)
                    state.place(q.row * size + q.col, color: color.rawValue)
                    history.append(q.row * size + q.col)
                    assertConsistent(board, state)
                    color = color.opponent
                    // 가끔 무르기도 섞는다.
                    if Int.random(in: 0..<5, using: &rng) == 0, let last = history.popLast() {
                        board.remove(at: Position(row: last / size, col: last % size))
                        state.remove(last)
                        color = color.opponent
                        assertConsistent(board, state)
                    }
                }
            }
        }
    }

    private func assertConsistent(_ board: Board, _ state: SearchState, file: StaticString = #filePath, line: UInt = #line) {
        var shared = 0, dead = 0, resB = 0, resW = 0
        for q in board.emptyPositions {
            let idx = q.row * board.size + q.col
            let blackSafe = board.isSafe(q, for: .black)
            let whiteSafe = board.isSafe(q, for: .white)
            XCTAssertEqual(state.isForbidden(idx, for: 1), !blackSafe, "black at \(q)", file: file, line: line)
            XCTAssertEqual(state.isForbidden(idx, for: 2), !whiteSafe, "white at \(q)", file: file, line: line)
            switch (blackSafe, whiteSafe) {
            case (true, true): shared += 1
            case (false, false): dead += 1
            case (true, false): resB += 1
            case (false, true): resW += 1
            }
        }
        XCTAssertEqual(state.shared, shared, file: file, line: line)
        XCTAssertEqual(state.dead, dead, file: file, line: line)
        XCTAssertEqual(state.reserve[1], resB, file: file, line: line)
        XCTAssertEqual(state.reserve[2], resW, file: file, line: line)
        XCTAssertEqual(state.emptyCount, board.emptyPositions.count, file: file, line: line)
    }

    func testAIAvoidsLosingMove() throws {
        var game = Game(size: 9)
        // 흑 차례, (4,4)만 빼면 다 안전하다.
        for (b, w) in [(p(4, 0), p(0, 0)), (p(4, 1), p(0, 2)), (p(4, 2), p(0, 4)), (p(4, 3), p(0, 6))] {
            try game.play(at: b)
            try game.play(at: w)
        }
        for difficulty in AIDifficulty.allCases {
            var rng = SplitMix64(seed: 7)
            for _ in 0..<10 {
                let move = try XCTUnwrap(AIPlayer(difficulty: difficulty).chooseMove(in: game, using: &rng))
                XCTAssertNotEqual(move, p(4, 4), "\(difficulty)")
                XCTAssertTrue(game.board.isEmpty(move))
            }
        }
    }

    /// 두면 상대에게 안전한 칸이 하나도 남지 않는 수(즉시 이기는 수)가 있으면 반드시 그 수를 둔다.
    func testAIFindsImmediateWin() throws {
        var rng = SplitMix64(seed: 11)
        var found = 0
        while found < 15 {
            // 무작위로 진행하다 보면 그런 국면이 나온다.
            var game = Game(size: 7)
            while !game.isOver {
                let me = game.currentPlayer
                let safe = game.board.safePositions(for: me)
                guard !safe.isEmpty else { break }
                let winning = safe.filter { q in
                    var b = game.board
                    b.place(me, at: q)
                    return !b.isFull && b.safePositions(for: me.opponent).isEmpty
                }
                if !winning.isEmpty && winning.count < safe.count {
                    found += 1
                    for difficulty in [AIDifficulty.normal, .hard] {
                        let move = try XCTUnwrap(AIPlayer(difficulty: difficulty).chooseMove(in: game, using: &rng))
                        XCTAssertTrue(winning.contains(move), "\(difficulty) chose \(move), winning: \(winning)")
                    }
                    break
                }
                try game.play(at: safe.randomElement(using: &rng)!)
            }
        }
    }

    func testHardIsFastEnoughOnEmptyAndMidgameBoards() throws {
        var rng = SplitMix64(seed: 3)
        var game = Game(size: 15)
        let ai = AIPlayer(difficulty: .hard)
        for _ in 0..<10 {
            let start = ContinuousClock.now
            let move = try XCTUnwrap(ai.chooseMove(in: game, using: &rng))
            XCTAssertLessThan(ContinuousClock.now - start, .seconds(3))
            try game.play(at: move)
            if game.isOver { break }
        }
    }
}
