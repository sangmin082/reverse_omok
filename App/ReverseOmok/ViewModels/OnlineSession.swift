import Foundation
import GameKit
import Observation
import OmokCore

/// 두 기기가 주고받는 메시지.
enum OnlineMessage: Codable {
    /// 연결 직후 서로 보내는 난수. 큰 쪽이 흑(선)을 잡는다.
    case hello(nonce: UInt64)
    /// number는 이 수가 몇 번째 수인지(1부터).
    case move(number: Int, row: Int, col: Int)
    case resign
    case rematch
}

/// Game Center 실시간 매치로 하는 온라인 대국 한 세션.
///
/// 방 코드는 서버 없이 `GKMatchRequest.playerGroup`으로 구현한다.
/// 같은 그룹 번호로 찾는 두 사람만 서로 매칭되므로, 코드가 곧 방이다.
@MainActor
@Observable
final class OnlineSession: NSObject, GKMatchDelegate {
    enum Phase: Equatable {
        case idle
        /// code가 nil이면 빠른 대국(아무나).
        case searching(code: String?)
        /// 상대를 찾았고 선후를 정하는 중.
        case connecting
        case playing
    }

    enum Outcome: Equatable {
        case win(String)
        case lose(String)
        case draw
    }

    static let turnSeconds = 30
    /// 상대 시계가 0이 된 뒤 이만큼 더 응답이 없으면 나간 것으로 본다.
    private static let graceSeconds = 10
    /// 규칙이 다른 앱 버전끼리 매칭되지 않도록 그룹 번호에 섞는다.
    private static let rulesVersion = 1
    private static let quickGroup = 9_000_000 + rulesVersion
    private static func roomGroup(_ code: String) -> Int? {
        guard code.count == 4, let number = Int(code) else { return nil }
        return 1_000_000 * rulesVersion + number
    }

    private(set) var phase = Phase.idle
    private(set) var game = Game(size: MatchConfig.boardSize, runLength: MatchConfig.runLength)
    private(set) var myStone = Stone.black
    private(set) var opponentName = "상대"
    private(set) var pending: Position?
    private(set) var outcome: Outcome?
    private(set) var secondsLeft = OnlineSession.turnSeconds
    private(set) var iWantRematch = false
    private(set) var opponentWantsRematch = false
    private(set) var opponentLeft = false
    var errorText: String?

    private var activeMatch: GKMatch?
    private var myNonce: UInt64 = 0
    private var theirNonce: UInt64?
    private var turnDeadline = Date()
    private var clockTask: Task<Void, Never>?
    private var searchID = 0

    // MARK: - 상태

    var isMyTurn: Bool { phase == .playing && outcome == nil && game.currentPlayer == myStone }

    var losingLine: [Position] {
        if case let .lost(_, line) = game.result { return line }
        return []
    }

    var statusText: String {
        switch outcome {
        case let .win(reason): return "\(reason) 승리!"
        case let .lose(reason): return "\(reason) 패배…"
        case .draw: return "판이 가득 찼습니다. 무승부!"
        case nil: return isMyTurn ? "내 차례" : "상대 차례"
        }
    }

    func safeCount(for stone: Stone) -> Int {
        game.board.safePositions(for: stone).count
    }

    static func randomCode() -> String {
        String(format: "%04d", Int.random(in: 0...9999))
    }

    // MARK: - 매칭

    /// code가 nil이면 빠른 대국, 아니면 같은 4자리 코드를 넣은 사람과만 만난다.
    func search(code: String?) {
        guard phase == .idle else { return }
        let group: Int
        if let code {
            guard let roomGroup = Self.roomGroup(code) else {
                errorText = "방 코드는 숫자 4자리입니다."
                return
            }
            group = roomGroup
        } else {
            group = Self.quickGroup
        }

        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        request.playerGroup = group

        errorText = nil
        phase = .searching(code: code)
        searchID += 1
        let id = searchID
        Task {
            do {
                let found = try await GKMatchmaker.shared().findMatch(for: request)
                guard id == searchID, case .searching = phase else {
                    found.disconnect()
                    return
                }
                begin(found)
            } catch {
                guard id == searchID, case .searching = phase else { return }
                phase = .idle
                if (error as? GKError)?.code != .cancelled {
                    errorText = "상대를 찾지 못했습니다. \(error.localizedDescription)"
                }
            }
        }
    }

    func cancelSearch() {
        guard case .searching = phase else { return }
        searchID += 1
        GKMatchmaker.shared().cancel()
        phase = .idle
    }

    /// 대국을 끝내고 연결을 끊는다.
    func leave() {
        searchID += 1
        if case .searching = phase { GKMatchmaker.shared().cancel() }
        clockTask?.cancel()
        clockTask = nil
        activeMatch?.delegate = nil
        activeMatch?.disconnect()
        activeMatch = nil
        phase = .idle
        outcome = nil
        pending = nil
        opponentLeft = false
    }

    private func begin(_ found: GKMatch) {
        activeMatch = found
        found.delegate = self
        phase = .connecting
        theirNonce = nil
        myNonce = UInt64.random(in: 1...UInt64.max)
        opponentLeft = false
        sendHelloIfConnected()
    }

    private func sendHelloIfConnected() {
        guard let match = activeMatch, phase == .connecting, match.expectedPlayerCount == 0,
              let opponent = match.players.first else { return }
        GKMatchmaker.shared().finishMatchmaking(for: match)
        opponentName = opponent.displayName
        send(.hello(nonce: myNonce))
        startGameIfReady()
    }

    private func startGameIfReady() {
        guard phase == .connecting, let theirNonce, theirNonce != myNonce else { return }
        startGame(as: myNonce > theirNonce ? .black : .white)
    }

    private func startGame(as stone: Stone) {
        myStone = stone
        game = Game(size: MatchConfig.boardSize, runLength: MatchConfig.runLength)
        pending = nil
        outcome = nil
        iWantRematch = false
        opponentWantsRematch = false
        phase = .playing
        startClock()
        Haptics.place()
    }

    // MARK: - 대국

    func tap(_ p: Position, confirm: Bool) {
        guard isMyTurn, game.board.isEmpty(p) else { return }
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

    func resign() {
        guard phase == .playing, outcome == nil else { return }
        send(.resign)
        finish(.lose("기권했습니다."))
    }

    func requestRematch() {
        guard phase == .playing, outcome != nil, !opponentLeft, !iWantRematch else { return }
        iWantRematch = true
        send(.rematch)
        rematchIfAgreed()
    }

    private func commit(_ p: Position) {
        pending = nil
        guard isMyTurn else { return }
        do { try game.play(at: p) } catch { return }
        send(.move(number: game.moves.count, row: p.row, col: p.col))
        Haptics.place()
        afterMove()
    }

    private func afterMove() {
        if let result = game.result {
            switch result {
            case .draw:
                finish(.draw)
            case let .lost(loser, _):
                finish(loser == myStone ? .lose("3개를 이어 버렸습니다.") : .win("상대가 3개를 이었습니다."))
            }
        } else {
            resetDeadline()
        }
    }

    private func finish(_ result: Outcome) {
        guard outcome == nil else { return }
        outcome = result
        pending = nil
        clockTask?.cancel()
        clockTask = nil
        if case .win = result { Haptics.gameOver(won: true) } else { Haptics.gameOver(won: false) }
    }

    private func rematchIfAgreed() {
        guard iWantRematch, opponentWantsRematch else { return }
        // 다시 둘 때는 흑백을 바꾼다.
        startGame(as: myStone.opponent)
    }

    // MARK: - 시계

    private func resetDeadline() {
        turnDeadline = Date().addingTimeInterval(TimeInterval(Self.turnSeconds))
        secondsLeft = Self.turnSeconds
    }

    private func startClock() {
        clockTask?.cancel()
        resetDeadline()
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self, !Task.isCancelled else { return }
                self.tick()
            }
        }
    }

    private func tick() {
        guard phase == .playing, outcome == nil else { return }
        let remaining = turnDeadline.timeIntervalSinceNow
        secondsLeft = max(0, Int(remaining.rounded(.up)))
        if isMyTurn {
            if remaining <= 0 {
                send(.resign)
                finish(.lose("시간이 다 됐습니다."))
            }
        } else if remaining <= -TimeInterval(Self.graceSeconds) {
            opponentLeft = true
            finish(.win("상대가 응답하지 않습니다."))
        }
    }

    // MARK: - 통신

    private func send(_ message: OnlineMessage) {
        guard let match = activeMatch, let data = try? JSONEncoder().encode(message) else { return }
        do {
            try match.sendData(toAllPlayers: data, with: .reliable)
        } catch {
            errorText = "전송에 실패했습니다. \(error.localizedDescription)"
        }
    }

    private func receive(_ data: Data) {
        guard let message = try? JSONDecoder().decode(OnlineMessage.self, from: data) else { return }
        switch message {
        case let .hello(nonce):
            // 상대가 준비되기 전에 보낸 내 인사는 사라질 수 있으니, 처음 받은 인사에는 한 번 답한다.
            let isNew = theirNonce != nonce
            theirNonce = nonce
            if isNew { send(.hello(nonce: myNonce)) }
            startGameIfReady()

        case let .move(number, row, col):
            // 상대 차례의 바로 다음 수만 받는다.
            guard phase == .playing, outcome == nil, !isMyTurn, number == game.moves.count + 1 else { return }
            do { try game.play(at: Position(row: row, col: col)) } catch { return }
            Haptics.place()
            afterMove()

        case .resign:
            guard phase == .playing else { return }
            finish(.win("상대가 기권했습니다."))

        case .rematch:
            guard phase == .playing, outcome != nil else { return }
            opponentWantsRematch = true
            rematchIfAgreed()
        }
    }

    private func opponentDisconnected() {
        opponentLeft = true
        switch phase {
        case .playing:
            finish(.win("상대가 나갔습니다."))
        case .connecting:
            leave()
            errorText = "상대와 연결이 끊겼습니다."
        case .idle, .searching:
            break
        }
    }

    // MARK: - GKMatchDelegate

    nonisolated func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        Task { @MainActor in
            guard match === self.activeMatch else { return }
            self.receive(data)
        }
    }

    nonisolated func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        Task { @MainActor in
            guard match === self.activeMatch else { return }
            switch state {
            case .connected: self.sendHelloIfConnected()
            case .disconnected: self.opponentDisconnected()
            default: break
            }
        }
    }

    nonisolated func match(_ match: GKMatch, didFailWithError error: Error?) {
        Task { @MainActor in
            guard match === self.activeMatch else { return }
            self.opponentDisconnected()
        }
    }
}
