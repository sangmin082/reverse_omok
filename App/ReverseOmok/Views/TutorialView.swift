import SwiftUI
import OmokCore

/// 직접 돌을 놓아 보며 규칙을 배우는 튜토리얼.
struct TutorialView: View {
    var onFinish: () -> Void

    @State private var step = Step.place
    @State private var board = Board(size: MatchConfig.boardSize, runLength: MatchConfig.runLength)
    @State private var lastMove: Position?
    @State private var losingLine: [Position] = []
    @State private var feedback: String?
    @State private var cleared = false

    enum Step: Int, CaseIterable {
        case place, avoid, opponent, finish, done

        var title: String {
            switch self {
            case .place: "돌 놓기"
            case .avoid: "5개를 이으면 진다"
            case .opponent: "상대의 금지 칸"
            case .finish: "상대를 몰아넣기"
            case .done: "준비 끝!"
            }
        }

        var instruction: String {
            switch self {
            case .place:
                "흑과 백이 번갈아 한 수씩 둡니다. 나는 흑이에요. 아무 칸이나 탭해 돌을 놓아 보세요."
            case .avoid:
                "내 돌 5개가 가로·세로·대각선으로 이어지면 집니다. 빨간 ×는 지금 두면 지는 칸이에요. ×가 없는 칸에 두세요."
            case .opponent:
                "이번 ×는 백이 두면 지는 칸입니다. 백이 못 두니 나만 쓸 수 있는 내 전용 칸이에요. 상대의 줄은 막지 말고 그대로 두는 게 좋습니다."
            case .finish:
                "판이 거의 찼습니다. ×는 백이 못 두는 칸이고, 백에게 남은 안전한 칸은 하나뿐이에요. 그 칸을 내가 먼저 차지하세요."
            case .done:
                ""
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: step == .done ? " " : "건너뛰기") {
                if step != .done { onFinish() }
            }
            VStack(spacing: 16) {
                if step == .done {
                    summary
                } else {
                    lesson
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background(Theme.paper.ignoresSafeArea())
        .onAppear { load(.place) }
    }

    private var lesson: some View {
        VStack(spacing: 16) {
            Text("\(step.rawValue + 1) / \(Step.allCases.count - 1)")
                .font(Theme.label)
                .foregroundStyle(Theme.seal)
            Text(step.title)
                .font(Theme.title(26))
                .foregroundStyle(Theme.ink)
            Text(step.instruction)
                .font(.system(size: 15))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            BoardView(
                board: board,
                lastMove: lastMove,
                dangerous: markedCells,
                losingLine: losingLine,
                onTap: tap
            )

            Text(feedback ?? " ")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(cleared ? Theme.seal : Theme.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button("다음") {
                load(Step(rawValue: step.rawValue + 1) ?? .done)
            }
            .buttonStyle(InkButtonStyle())
            .disabled(!cleared)

            Spacer(minLength: 0)
        }
    }

    private var summary: some View {
        VStack(spacing: 20) {
            Spacer()
            Text(Step.done.title)
                .font(Theme.title(34))
                .foregroundStyle(Theme.ink)
            VStack(alignment: .leading, spacing: 0) {
                point("하나", "내 돌 5개를 이으면 집니다.")
                point("둘", "내 돌은 흩어 두고, 상대의 줄은 막지 마세요.")
                point("셋", "상대가 둘 곳이 금지 칸뿐이면 내가 이깁니다.")
            }
            Spacer()
            Button("시작하기") { onFinish() }
                .buttonStyle(InkButtonStyle())
        }
    }

    private func point(_ number: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(number)
                    .font(Theme.title(17))
                    .foregroundStyle(Theme.seal)
                    .frame(width: 36, alignment: .leading)
                Text(text)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 14)
            Hairline()
        }
    }

    /// 단계마다 ×로 표시할 칸. 앞 단계는 내(흑) 금지 칸, 뒤 단계는 상대(백) 금지 칸.
    private var markedCells: Set<Position> {
        guard losingLine.isEmpty else { return [] }
        let stone: Stone
        switch step {
        case .place, .done: return []
        case .avoid: stone = .black
        case .opponent, .finish: stone = .white
        }
        return Set(board.emptyPositions.filter { !board.isSafe($0, for: stone) })
    }

    private func load(_ newStep: Step) {
        step = newStep
        lastMove = nil
        losingLine = []
        feedback = nil
        cleared = false
        switch newStep {
        case .place, .done:
            board = Self.makeBoard([])
        case .avoid:
            board = Self.makeBoard([
                "...........",
                ".W.....W...",
                "...........",
                "...........",
                "...........",
                "...BBBB....",
                ".........W.",
                "...........",
                ".BB.BB.....",
                "...........",
                ".....W.....",
            ])
        case .opponent:
            board = Self.makeBoard([
                "B.........B",
                "...........",
                "...........",
                "..WWWW.....",
                "...........",
                "...........",
                ".....W.....",
                "......W....",
                ".B.....W...",
                "........W..",
                "B..........",
            ])
            cleared = true
        case .finish:
            board = Self.makeBoard([
                "BWWWBWBBWWW",
                "BBWWBBWBWWB",
                "WWBBWBWBBWW",
                "BBWBWWBWBWB",
                "WWBWW.BWB.B",
                "WW.BBWWWWBB",
                "BWWWBW.WBWW",
                "WBWWBWBBWBW",
                "BBBB.BWBBBW",
                "BBWBBBWWBWW",
                "BWBWWBBWBBB",
            ])
        }
    }

    private func tap(_ p: Position) {
        guard !cleared, board.isEmpty(p) else { return }
        switch step {
        case .place:
            place(.black, at: p)
            feedback = "좋아요! 이렇게 번갈아 둡니다."
            cleared = true

        case .avoid:
            guard board.isSafe(p, for: .black) else {
                feedback = "거기 두면 5개가 이어져 집니다. 다른 칸을 골라 보세요."
                Haptics.select()
                return
            }
            place(.black, at: p)
            feedback = "잘했어요! 내 돌은 흩어 두는 게 안전합니다."
            cleared = true

        case .finish:
            guard board.isSafe(p, for: .black) else {
                feedback = "거기 두면 내가 5개를 잇게 됩니다."
                Haptics.select()
                return
            }
            guard board.isSafe(p, for: .white) else {
                feedback = "그 칸은 백이 어차피 못 두는 칸이에요. ×가 없는 칸을 차지하세요."
                Haptics.select()
                return
            }
            place(.black, at: p)
            // 백은 둘 곳이 금지 칸뿐이라 어쩔 수 없이 5목을 만든다.
            if let forced = board.emptyPositions.first,
               let line = board.losingLine(ifPlacing: .white, at: forced) {
                board.place(.white, at: forced)
                lastMove = forced
                losingLine = line
            }
            feedback = "백은 둘 곳이 금지 칸뿐이라 5개를 잇고 졌습니다. 승리!"
            cleared = true
            Haptics.gameOver(won: true)

        case .opponent, .done:
            break
        }
    }

    private func place(_ stone: Stone, at p: Position) {
        board.place(stone, at: p)
        lastMove = p
        Haptics.place()
    }

    /// "B", "W", "."으로 그린 판을 만든다. 빈 배열이면 빈 판.
    private static func makeBoard(_ rows: [String]) -> Board {
        var board = Board(size: MatchConfig.boardSize, runLength: MatchConfig.runLength)
        for (r, row) in rows.enumerated() {
            for (c, ch) in row.enumerated() {
                let p = Position(row: r, col: c)
                if ch == "B" { board.place(.black, at: p) }
                if ch == "W" { board.place(.white, at: p) }
            }
        }
        return board
    }
}

#Preview {
    TutorialView {}
}
