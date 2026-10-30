public struct Move: Codable, Hashable, Sendable {
    public let position: Position
    public let stone: Stone
}

public enum GameResult: Codable, Hashable, Sendable {
    /// `loser`가 5목 이상을 만들어 졌다. `line`은 문제의 줄.
    case lost(loser: Stone, line: [Position])
    /// 판이 가득 찼다.
    case draw

    public var winner: Stone? {
        if case let .lost(loser, _) = self { return loser.opponent }
        return nil
    }
}

public enum MoveError: Error, Equatable {
    case gameOver
    case outOfBounds
    case occupied
}

/// 리버스 오목 한 판의 상태. 흑 선공, 5목 이상을 만들면 패배, 판이 차면 무승부.
public struct Game: Codable, Hashable, Sendable {
    public private(set) var board: Board
    public private(set) var moves: [Move] = []
    public private(set) var result: GameResult?

    public init(size: Int = 15) {
        board = Board(size: size)
    }

    public var currentPlayer: Stone { moves.count.isMultiple(of: 2) ? .black : .white }
    public var isOver: Bool { result != nil }
    public var lastMove: Move? { moves.last }

    @discardableResult
    public mutating func play(at p: Position) throws -> GameResult? {
        guard result == nil else { throw MoveError.gameOver }
        guard board.contains(p) else { throw MoveError.outOfBounds }
        guard board.isEmpty(p) else { throw MoveError.occupied }

        let stone = currentPlayer
        board.place(stone, at: p)
        moves.append(Move(position: p, stone: stone))

        if let line = board.losingLine(ifPlacing: stone, at: p) {
            result = .lost(loser: stone, line: line)
        } else if board.isFull {
            result = .draw
        }
        return result
    }

    /// 마지막 수를 무른다. 무를 수가 없으면 false.
    @discardableResult
    public mutating func undo() -> Bool {
        guard let last = moves.popLast() else { return false }
        board.remove(at: last.position)
        result = nil
        return true
    }

    /// 지금 둘 차례인 쪽이 두면 지는 칸들.
    public var dangerousPositionsForCurrentPlayer: Set<Position> {
        guard !isOver else { return [] }
        let stone = currentPlayer
        return Set(board.emptyPositions.filter { !board.isSafe($0, for: stone) })
    }
}
