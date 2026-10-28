import SwiftUI
import OmokCore

struct GameView: View {
    @State var model: GameViewModel

    @AppStorage("showDanger") private var showDanger = true
    @AppStorage("confirmPlacement") private var confirmPlacement = true

    var body: some View {
        VStack(spacing: 16) {
            PlayersHeader(model: model)

            BoardView(
                board: model.game.board,
                lastMove: model.game.lastMove?.position,
                pending: model.pending,
                pendingStone: model.game.currentPlayer,
                dangerous: showDanger && model.isHumanTurn ? model.game.dangerousPositionsForCurrentPlayer : [],
                losingLine: model.losingLine,
                onTap: { model.tap($0, confirm: confirmPlacement) }
            )
            .padding(.horizontal, 8)

            Text(model.statusText)
                .font(.headline)
                .foregroundStyle(model.game.isOver ? Color.accentColor : .primary)
                .animation(.default, value: model.statusText)

            controls
            Spacer(minLength: 0)
        }
        .padding(.vertical)
        .navigationTitle("리버스 오목")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { model.stop() }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                model.undo()
            } label: {
                Label("무르기", systemImage: "arrow.uturn.backward")
            }
            .disabled(!model.canUndo)

            if model.pending != nil {
                Button {
                    model.confirmPending()
                } label: {
                    Label("여기에 두기", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }

            Button {
                model = model.restart()
            } label: {
                Label("새 게임", systemImage: "arrow.clockwise")
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}

private struct PlayersHeader: View {
    let model: GameViewModel

    var body: some View {
        HStack(spacing: 12) {
            card(.black)
            card(.white)
        }
        .padding(.horizontal)
    }

    private func card(_ stone: Stone) -> some View {
        let active = !model.game.isOver && model.game.currentPlayer == stone
        return HStack(spacing: 10) {
            Circle()
                .fill(stone == .black ? Color.black : Color.white)
                .overlay(Circle().stroke(Color.gray, lineWidth: 1))
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.config.playerName(stone))
                    .font(.subheadline.bold())
                Text("둘 수 있는 칸 \(model.safeCount(for: stone))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
            if active && model.isThinking {
                ProgressView()
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(active ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(active ? Color.accentColor : .clear, lineWidth: 2)
        )
    }
}
