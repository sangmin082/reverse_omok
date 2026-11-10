import SwiftUI
import OmokCore

struct GameView: View {
    @State var model: GameViewModel

    @Environment(\.dismiss) private var dismiss
    @AppStorage("showDanger") private var showDanger = true
    @AppStorage("confirmPlacement") private var confirmPlacement = true

    var body: some View {
        VStack(spacing: 20) {
            TopBar(title: "‹ 나가기") { dismiss() }
                .padding(.bottom, -8)

            HStack(alignment: .top, spacing: 20) {
                playerBar(.black)
                playerBar(.white)
            }
            .padding(.horizontal, 20)

            BoardView(
                board: model.game.board,
                lastMove: model.game.lastMove?.position,
                pending: model.pending,
                pendingStone: model.game.currentPlayer,
                dangerous: showDanger && model.isHumanTurn ? model.game.dangerousPositionsForCurrentPlayer : [],
                losingLine: model.losingLine,
                onTap: { model.tap($0, confirm: confirmPlacement) }
            )
            .padding(.horizontal, 12)

            Text(model.statusText)
                .font(Theme.title(20))
                .foregroundStyle(model.game.isOver ? Theme.seal : Theme.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .animation(.default, value: model.statusText)

            controls
                .padding(.horizontal, 20)
            Spacer(minLength: 0)
        }
        .padding(.bottom, 16)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background(Theme.paper.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear { model.stop() }
    }

    private func playerBar(_ stone: Stone) -> some View {
        let active = !model.game.isOver && model.game.currentPlayer == stone
        return PlayerBar(
            stone: stone,
            name: model.config.playerName(stone),
            detail: "둘 수 있는 칸 \(model.safeCount(for: stone))",
            active: active
        ) {
            if active && model.isThinking {
                ProgressView().controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        if model.pending != nil {
            Button("여기에 두기") { model.confirmPending() }
                .buttonStyle(InkButtonStyle())
        } else {
            HStack(spacing: 10) {
                Button("무르기") { model.undo() }
                    .disabled(!model.canUndo)
                Button("새 대국") { model = model.restart() }
            }
            .buttonStyle(OutlineButtonStyle())
        }
    }
}
