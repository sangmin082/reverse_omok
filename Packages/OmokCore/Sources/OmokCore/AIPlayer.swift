public enum AIDifficulty: String, Codable, CaseIterable, Sendable, Identifiable {
    case easy
    case normal
    case hard

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .easy: "쉬움"
        case .normal: "보통"
        case .hard: "어려움"
        }
    }

    struct Config {
        /// 반복 심화 최대 깊이.
        var maxDepth: Int
        /// 노드당 살펴볼 후보 수 (정렬 후 상위 N개).
        var beamWidth: Int
        /// 반복 심화 시간 제한.
        var timeLimit: Duration
        /// 루트 점수에 더하는 무작위 잡음의 크기.
        var noise: Int
    }

    var config: Config {
        switch self {
        case .easy: Config(maxDepth: 1, beamWidth: 999, timeLimit: .seconds(1), noise: 90)
        case .normal: Config(maxDepth: 2, beamWidth: 16, timeLimit: .seconds(1), noise: 8)
        case .hard: Config(maxDepth: 10, beamWidth: 10, timeLimit: .milliseconds(1200), noise: 0)
        }
    }
}

/// 컴퓨터 상대. 상태가 없어 어느 스레드에서 불러도 안전하다.
public struct AIPlayer: Sendable {
    public let difficulty: AIDifficulty

    public init(difficulty: AIDifficulty) {
        self.difficulty = difficulty
    }

    public func chooseMove(in game: Game) -> Position? {
        var rng = SystemRandomNumberGenerator()
        return chooseMove(in: game, using: &rng)
    }

    public func chooseMove<R: RandomNumberGenerator>(in game: Game, using rng: inout R) -> Position? {
        guard !game.isOver else { return nil }
        let board = game.board
        let color = game.currentPlayer.rawValue
        var search = Searcher(state: SearchState(board: board), config: difficulty.config)
        guard let idx = search.bestMove(for: color, using: &rng) else { return nil }
        return Position(row: idx / board.size, col: idx % board.size)
    }
}

private struct Searcher {
    static let win = 1_000_000

    var state: SearchState
    let config: AIDifficulty.Config
    private var deadline: ContinuousClock.Instant = .now
    private var timedOut = false
    private var nodes = 0

    init(state: SearchState, config: AIDifficulty.Config) {
        self.state = state
        self.config = config
    }

    mutating func bestMove<R: RandomNumberGenerator>(for color: UInt8, using rng: inout R) -> Int? {
        let safe = state.safeMoves(for: color)
        guard !safe.isEmpty else {
            // 어디에 둬도 진다. 아무 빈칸이나 둔다.
            return (0..<state.cells.count).first { state.isEmpty($0) }
        }
        if safe.count == 1 { return safe[0] }

        deadline = .now + config.timeLimit
        var ordered = orderedChildren(safe, color: color, ply: 0).map(\.move)
        var bestScores: [(move: Int, score: Int)] = ordered.map { ($0, 0) }

        for depth in 1...config.maxDepth {
            timedOut = false
            let candidates = depth == 1 ? ordered : Array(ordered.prefix(max(config.beamWidth * 2, 20)))
            var scored: [(move: Int, score: Int)] = []
            var alpha = -Self.win - 1
            for move in candidates {
                state.place(move, color: color)
                let score = -negamax(depth: depth - 1, alpha: -Self.win - 1, beta: -alpha, color: 3 - color, ply: 1)
                state.remove(move)
                if timedOut { break }
                scored.append((move, score))
                // 잡음이 있으면 모든 후보의 정확한 점수가 필요하므로 가지치기를 하지 않는다.
                if config.noise == 0 { alpha = max(alpha, score) }
            }
            if timedOut && depth > 1 { break }
            scored.sort { $0.score > $1.score }
            bestScores = scored
            ordered = scored.map(\.move) + ordered.filter { m in !scored.contains { $0.move == m } }
            // 이기거나 지는 수순을 찾았으면 더 볼 필요 없다.
            if let top = scored.first, abs(top.score) >= Self.win - 100 { break }
            if ContinuousClock.now >= deadline { break }
        }

        guard config.noise > 0 else { return bestScores.first?.move }
        let noisy = bestScores.map { ($0.move, $0.score + Int.random(in: 0...config.noise, using: &rng)) }
        return noisy.max { $0.1 < $1.1 }?.0
    }

    private mutating func negamax(depth: Int, alpha: Int, beta: Int, color: UInt8, ply: Int) -> Int {
        if let terminal = terminalScore(color: color, ply: ply) { return terminal }
        if depth == 0 { return state.evaluate(for: color) }

        nodes += 1
        if nodes & 1023 == 0, ContinuousClock.now >= deadline { timedOut = true }
        if timedOut { return 0 }

        let children = orderedChildren(state.safeMoves(for: color), color: color, ply: ply)
        if depth == 1 {
            // 자식 평가값은 정렬하면서 이미 계산했다.
            return children.first.map(\.score) ?? -Self.win + ply
        }

        var alpha = alpha
        var best = -Self.win - 1
        for child in children.prefix(config.beamWidth) {
            state.place(child.move, color: color)
            let score = -negamax(depth: depth - 1, alpha: -beta, beta: -alpha, color: 3 - color, ply: ply + 1)
            state.remove(child.move)
            if timedOut { return 0 }
            best = max(best, score)
            alpha = max(alpha, score)
            if alpha >= beta { break }
        }
        return best
    }

    /// 둘 차례인 color 기준 종국 점수. 진행 중이면 nil.
    private func terminalScore(color: UInt8, ply: Int) -> Int? {
        if state.emptyCount == 0 { return 0 }
        // 둘 곳이 모두 금수면 5목을 만들 수밖에 없다.
        if state.safeCount(for: color) == 0 { return -Self.win + ply }
        return nil
    }

    /// 각 수를 한 수 둬 본 뒤의 평가값(둔 쪽 기준)으로 내림차순 정렬한다. ply는 현재 노드의 깊이.
    private mutating func orderedChildren(_ moves: [Int], color: UInt8, ply: Int) -> [(move: Int, score: Int)] {
        var result: [(move: Int, score: Int)] = []
        result.reserveCapacity(moves.count)
        for move in moves {
            state.place(move, color: color)
            let opp = 3 - color
            let score: Int
            if state.emptyCount == 0 {
                score = 0
            } else if state.safeCount(for: opp) == 0 {
                score = Self.win - (ply + 1)
            } else {
                score = -state.evaluate(for: opp)
            }
            state.remove(move)
            result.append((move, score))
        }
        result.sort { $0.score > $1.score }
        return result
    }
}
