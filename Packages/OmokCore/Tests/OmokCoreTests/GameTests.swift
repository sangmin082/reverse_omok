import XCTest
@testable import OmokCore

final class GameTests: XCTestCase {
    private func p(_ r: Int, _ c: Int) -> Position { Position(row: r, col: c) }

    /// 흑은 `black`에, 백은 `white`에 번갈아 둔다.
    private func play(_ game: inout Game, black: [Position], white: [Position]) throws {
        for i in 0..<max(black.count, white.count) {
            if i < black.count { try game.play(at: black[i]) }
            if i < white.count { try game.play(at: white[i]) }
        }
    }

    func testFiveInARowLoses() throws {
        var game = Game(size: 15)
        try play(&game,
                 black: [p(7, 3), p(7, 4), p(7, 5), p(7, 6)],
                 white: [p(0, 0), p(0, 2), p(0, 4), p(0, 6)])
        XCTAssertNil(game.result)
        try game.play(at: p(7, 7))
        XCTAssertEqual(game.result, .lost(loser: .black, line: [p(7, 3), p(7, 4), p(7, 5), p(7, 6), p(7, 7)]))
        XCTAssertEqual(game.result?.winner, .white)
        XCTAssertThrowsError(try game.play(at: p(10, 10))) { XCTAssertEqual($0 as? MoveError, .gameOver) }
    }

    func testDiagonalAndOverlineLose() throws {
        var game = Game(size: 9)
        // 백이 대각선으로 X X X _ X X 를 만들고 가운데를 채우면 6목.
        try play(&game,
                 black: [p(0, 8), p(2, 8), p(4, 8), p(6, 8), p(8, 8), p(0, 6)],
                 white: [p(0, 0), p(1, 1), p(2, 2), p(4, 4), p(5, 5)])
        try game.play(at: p(3, 3))
        XCTAssertEqual(game.result?.winner, .black)
        if case let .lost(loser, line) = game.result {
            XCTAssertEqual(loser, .white)
            XCTAssertEqual(line.count, 6)
        } else {
            XCTFail("expected a loss")
        }
    }

    func testFourIsFine() throws {
        var game = Game(size: 9)
        try play(&game, black: [p(4, 0), p(4, 1), p(4, 2), p(4, 3)], white: [p(0, 0), p(0, 2), p(0, 4), p(0, 6)])
        XCTAssertNil(game.result)
        XCTAssertEqual(game.currentPlayer, .black)
        XCTAssertEqual(game.dangerousPositionsForCurrentPlayer, [p(4, 4)])
    }

    func testRejectsInvalidMoves() throws {
        var game = Game(size: 9)
        try game.play(at: p(4, 4))
        XCTAssertThrowsError(try game.play(at: p(4, 4))) { XCTAssertEqual($0 as? MoveError, .occupied) }
        XCTAssertThrowsError(try game.play(at: p(9, 0))) { XCTAssertEqual($0 as? MoveError, .outOfBounds) }
    }

    func testUndoRestoresState() throws {
        var game = Game(size: 9)
        try play(&game, black: [p(4, 0), p(4, 1), p(4, 2), p(4, 3)], white: [p(0, 0), p(0, 2), p(0, 4), p(0, 6)])
        try game.play(at: p(4, 4))
        XCTAssertNotNil(game.result)
        XCTAssertTrue(game.undo())
        XCTAssertNil(game.result)
        XCTAssertEqual(game.currentPlayer, .black)
        XCTAssertTrue(game.board.isEmpty(p(4, 4)))
        while game.undo() {}
        XCTAssertEqual(game.board, Board(size: 9))
        XCTAssertFalse(game.undo())
    }

    func testFullBoardIsDraw() throws {
        // 5×5 판을 두 칸씩 엇갈려 채우면 어느 줄에도 5목이 생기지 않는다.
        var board = Board(size: 5)
        var black: [Position] = []
        var white: [Position] = []
        for r in 0..<5 {
            for c in 0..<5 {
                let isBlack = ((c + 2 * r) / 2) % 2 == 0
                if isBlack { black.append(p(r, c)) } else { white.append(p(r, c)) }
            }
        }
        for q in black { board.place(.black, at: q) }
        for q in white { board.place(.white, at: q) }
        for q in board.allPositions {
            for d in lineDirections {
                XCTAssertLessThan(board.run(through: q, direction: d, as: board[q]!).count, 5, "\(q)")
            }
        }
        XCTAssertEqual(black.count, 13)
        XCTAssertEqual(white.count, 12)

        var game = Game(size: 5)
        try play(&game, black: black, white: white)
        XCTAssertEqual(game.result, .draw)
    }

    func testCodableRoundTrip() throws {
        var game = Game(size: 11)
        try play(&game, black: [p(5, 5), p(2, 3)], white: [p(1, 1)])
        let data = try JSONEncoder().encode(game)
        XCTAssertEqual(try JSONDecoder().decode(Game.self, from: data), game)
    }
}
