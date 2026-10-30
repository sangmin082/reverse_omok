/// 돌 색. 흑이 먼저 둔다.
public enum Stone: UInt8, Codable, Sendable, CaseIterable {
    case black = 1
    case white = 2

    public var opponent: Stone { self == .black ? .white : .black }
}

public struct Position: Hashable, Codable, Sendable {
    public let row: Int
    public let col: Int

    public init(row: Int, col: Int) {
        self.row = row
        self.col = col
    }
}

/// 가로, 세로, 두 대각선.
public let lineDirections: [(dr: Int, dc: Int)] = [(0, 1), (1, 0), (1, 1), (1, -1)]

/// 연속으로 놓으면 지는 돌 개수.
public let losingRunLength = 5

/// 정사각형 바둑판. 값 타입이라 복사해서 시뮬레이션에 써도 안전하다.
public struct Board: Codable, Hashable, Sendable {
    public let size: Int
    public private(set) var cells: [Stone?]
    public private(set) var stoneCount: Int = 0

    public static let supportedSizes = [9, 11, 13, 15]

    public init(size: Int = 15) {
        precondition(size >= losingRunLength, "board must fit a run of \(losingRunLength)")
        self.size = size
        self.cells = Array(repeating: nil, count: size * size)
    }

    public var isFull: Bool { stoneCount == cells.count }

    public func contains(_ p: Position) -> Bool {
        p.row >= 0 && p.row < size && p.col >= 0 && p.col < size
    }

    public subscript(_ p: Position) -> Stone? {
        cells[p.row * size + p.col]
    }

    public func isEmpty(_ p: Position) -> Bool { self[p] == nil }

    public var allPositions: [Position] {
        (0..<size).flatMap { r in (0..<size).map { c in Position(row: r, col: c) } }
    }

    public var emptyPositions: [Position] {
        allPositions.filter { isEmpty($0) }
    }

    public mutating func place(_ stone: Stone, at p: Position) {
        precondition(isEmpty(p), "cell \(p) is occupied")
        cells[p.row * size + p.col] = stone
        stoneCount += 1
    }

    public mutating func remove(at p: Position) {
        precondition(!isEmpty(p), "cell \(p) is empty")
        cells[p.row * size + p.col] = nil
        stoneCount -= 1
    }

    /// `p`를 지나는 `stone`의 연속된 줄을 방향별로 구한다. `p`에 해당 돌이 놓여 있다고 가정한다.
    public func run(through p: Position, direction d: (dr: Int, dc: Int), as stone: Stone) -> [Position] {
        var line = [p]
        for sign in [-1, 1] {
            var q = Position(row: p.row + sign * d.dr, col: p.col + sign * d.dc)
            while contains(q), self[q] == stone {
                if sign < 0 { line.insert(q, at: 0) } else { line.append(q) }
                q = Position(row: q.row + sign * d.dr, col: q.col + sign * d.dc)
            }
        }
        return line
    }

    /// `stone`을 `p`에 놓으면 5목 이상이 되는 줄. 없으면 nil.
    public func losingLine(ifPlacing stone: Stone, at p: Position) -> [Position]? {
        for d in lineDirections {
            let line = run(through: p, direction: d, as: stone)
            if line.count >= losingRunLength { return line }
        }
        return nil
    }

    /// 놓아도 지지 않는 빈 칸인가.
    public func isSafe(_ p: Position, for stone: Stone) -> Bool {
        isEmpty(p) && losingLine(ifPlacing: stone, at: p) == nil
    }

    public func safePositions(for stone: Stone) -> [Position] {
        emptyPositions.filter { losingLine(ifPlacing: stone, at: $0) == nil }
    }
}
