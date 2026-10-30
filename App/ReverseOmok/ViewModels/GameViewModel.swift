import Foundation
import Observation
import OmokCore

@MainActor
@Observable
final class GameViewModel {
    let config: MatchConfig
    private(set) var game: Game
    /// 착수 확인 모드에서 한 번 탭해 둔 자리.
    private(set) var pending: Position?
    private(set) var isThinking = false

    private var statsRecorded: Bool
    private var aiTask: Task<Void, Never>?

    init(config: MatchConfig) {
        self.config = config
        game = Game(size: config.boardSize)
        statsRecorded = false
        persist()
        scheduleAIIfNeeded()
    }

    init(saved: SavedMatch) {
        config = saved.config
        game = saved.game
        statsRecorded = saved.statsRecorded
        scheduleAIIfNeeded()
    }

    // MARK: - 상태

    var isHumanTurn: Bool { !game.isOver && config.isHuman(game.currentPlayer) }

    var canUndo: Bool {
        switch config.mode {
        case .twoPlayer: !game.moves.isEmpty
        case .vsAI: game.moves.contains { $0.stone == config.humanStone }
        }
    }

    var losingLine: [Position] {
        if case let .lost(_, line) = game.result { return line }
        return []
    }

    func safeCount(for stone: Stone) -> Int {
        game.board.safePositions(for: stone).count
    }

    var statusText: String {
        if let result = game.result { return resultText(result) }
        if isThinking { return "컴퓨터가 생각 중…" }
        let stone = game.currentPlayer
        switch config.mode {
        case .twoPlayer: return "\(stone.displayName) 차례"
        case .vsAI: return config.isHuman(stone) ? "내 차례 (\(stone.displayName))" : "컴퓨터 차례"
        }
    }

    private func resultText(_ result: GameResult) -> String {
        switch result {
        case .draw:
            return "판이 가득 찼습니다. 무승부!"
        case let .lost(loser, _):
            switch config.mode {
            case .twoPlayer:
                return "\(loser.displayName)이 5목을 만들었습니다. \(loser.opponent.displayName) 승리!"
            case .vsAI:
                return loser == config.humanStone
                    ? "5목을 만들어 버렸습니다. 패배…"
                    : "컴퓨터가 5목을 만들었습니다. 승리!"
            }
        }
    }

    // MARK: - 조작

    /// 칸을 탭했을 때. `confirm`이 켜져 있으면 같은 칸을 두 번 탭해야 둔다.
    func tap(_ p: Position, confirm: Bool) {
        guard isHumanTurn, !isThinking, game.board.isEmpty(p) else { return }
        if confirm && pending != p {
            pending = p
            Haptics.select()
            return
        }
        commit(p)
    }

    func confirmPending() {
        guard let p = pending else { return }
        commit(p)
    }

    func cancelPending() {
        pending = nil
    }

    func undo() {
        guard canUndo else { return }
        cancelAI()
        pending = nil
        switch config.mode {
        case .twoPlayer:
            game.undo()
        case .vsAI:
            // 내 수까지 되돌려서 다시 내 차례가 되게 한다.
            while let last = game.moves.last {
                game.undo()
                if last.stone == config.humanStone { break }
            }
        }
        persist()
        scheduleAIIfNeeded()
    }

    func restart() -> GameViewModel {
        cancelAI()
        return GameViewModel(config: config)
    }

    func stop() {
        cancelAI()
    }

    // MARK: - 내부

    private func commit(_ p: Position) {
        pending = nil
        do { try game.play(at: p) } catch { return }
        Haptics.place()
        afterMove()
    }

    private func afterMove() {
        if let result = game.result {
            if config.mode == .vsAI && !statsRecorded {
                Stats.record(result, humanStone: config.humanStone, difficulty: config.difficulty)
                statsRecorded = true
            }
            let won = config.mode == .twoPlayer || result.winner == config.humanStone
            Haptics.gameOver(won: won)
        }
        persist()
        scheduleAIIfNeeded()
    }

    private func scheduleAIIfNeeded() {
        guard config.mode == .vsAI, !game.isOver, !config.isHuman(game.currentPlayer) else { return }
        let snapshot = game
        let ai = AIPlayer(difficulty: config.difficulty)
        isThinking = true
        aiTask = Task { [weak self] in
            let start = ContinuousClock.now
            let move = await Task.detached(priority: .userInitiated) {
                ai.chooseMove(in: snapshot)
            }.value
            // 너무 빨리 두면 어색하니 최소한의 뜸을 들인다.
            let elapsed = ContinuousClock.now - start
            if elapsed < .milliseconds(450) {
                try? await Task.sleep(for: .milliseconds(450) - elapsed)
            }
            guard let self, !Task.isCancelled else { return }
            self.isThinking = false
            guard self.game == snapshot, let move else { return }
            try? self.game.play(at: move)
            Haptics.place()
            self.afterMove()
        }
    }

    private func cancelAI() {
        aiTask?.cancel()
        aiTask = nil
        isThinking = false
    }

    private func persist() {
        SavedMatch(config: config, game: game, statsRecorded: statsRecorded).save()
    }
}
