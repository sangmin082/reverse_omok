import SwiftUI
import OmokCore

/// 온라인 대국: 방 만들기, 코드로 들어가기, 빠른 대국. 상대를 만나면 같은 화면에서 대국으로 넘어간다.
struct OnlineLobbyView: View {
    @State private var session = OnlineSession()
    @State private var auth = GameCenterAuth.shared
    @State private var codeInput = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var codeFocused: Bool

    var body: some View {
        Group {
            switch session.phase {
            case .idle:
                lobby
            case let .searching(code):
                waiting(code: code)
            case .connecting:
                connecting
            case .playing:
                OnlineGameView(session: session)
            }
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if session.phase != .playing {
                    Button("나가기") {
                        session.leave()
                        dismiss()
                    }
                    .foregroundStyle(Theme.ink)
                }
            }
        }
        .toolbarBackground(Theme.paper, for: .navigationBar)
        .onAppear { auth.start() }
        .onDisappear { session.leave() }
    }

    private var lobby: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    Text("온라인 대국")
                        .font(Theme.title(32))
                        .foregroundStyle(Theme.ink)
                    Text("한 수에 \(OnlineSession.turnSeconds)초 · 흑백은 무작위")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.subInk)
                }

                if auth.isAuthenticated {
                    rooms
                } else {
                    signInNotice
                }

                if let error = session.errorText {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.seal)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
        }
    }

    private var rooms: some View {
        VStack(spacing: 28) {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("친구와")
                Button("방 만들기") {
                    session.search(code: OnlineSession.randomCode())
                }
                .buttonStyle(InkButtonStyle())

                HStack(spacing: 10) {
                    TextField("방 코드 4자리", text: $codeInput)
                        .keyboardType(.numberPad)
                        .focused($codeFocused)
                        .font(.system(size: 20, weight: .medium).monospacedDigit())
                        .multilineTextAlignment(.center)
                        .frame(minHeight: 48)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.ink.opacity(0.8), lineWidth: 1))
                        .onChange(of: codeInput) { _, newValue in
                            let digits = String(newValue.filter(\.isNumber).prefix(4))
                            if digits != newValue { codeInput = digits }
                        }
                    Button("들어가기") {
                        codeFocused = false
                        session.search(code: codeInput)
                    }
                    .buttonStyle(OutlineButtonStyle())
                    .frame(width: 120)
                    .disabled(codeInput.count != 4)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("아무나와")
                Button("빠른 대국") {
                    session.search(code: nil)
                }
                .buttonStyle(OutlineButtonStyle())
            }
        }
    }

    private var signInNotice: some View {
        VStack(spacing: 12) {
            if auth.isWorking {
                ProgressView()
                Text("Game Center에 연결하는 중…")
                    .foregroundStyle(Theme.subInk)
            } else {
                Text("온라인 대국은 Game Center 로그인이 필요합니다.")
                    .foregroundStyle(Theme.ink)
                Text("설정 앱 → Game Center에서 로그인한 뒤 다시 들어와 주세요.")
                    .foregroundStyle(Theme.subInk)
                if let error = auth.errorText {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.subInk)
                }
            }
        }
        .font(.system(size: 15))
        .multilineTextAlignment(.center)
        .padding(.vertical, 24)
    }

    private func waiting(code: String?) -> some View {
        VStack(spacing: 24) {
            Spacer()
            if let code {
                Text("방 코드")
                    .font(Theme.label)
                    .foregroundStyle(Theme.subInk)
                Text(code)
                    .font(.system(size: 64, weight: .semibold).monospacedDigit())
                    .tracking(10)
                    .foregroundStyle(Theme.ink)
                Text("상대가 이 코드로 들어오면 바로 시작합니다.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.subInk)
                ShareLink(item: "리버스 오목 한 판 하자! 방 코드 \(code)") {
                    Text("코드 보내기")
                        .underline()
                        .foregroundStyle(Theme.ink)
                }
            } else {
                Text("상대를 찾는 중")
                    .font(Theme.title(26))
                    .foregroundStyle(Theme.ink)
                Text("지금 접속한 사람이 없으면 오래 걸릴 수 있습니다.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.subInk)
            }
            ProgressView()
            Spacer()
            Button("취소") { session.cancelSearch() }
                .buttonStyle(OutlineButtonStyle())
        }
        .multilineTextAlignment(.center)
        .padding(24)
    }

    private var connecting: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("상대를 찾았습니다. 연결하는 중…")
                .font(.system(size: 15))
                .foregroundStyle(Theme.subInk)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.label)
            .foregroundStyle(Theme.subInk)
    }
}

/// 온라인 대국 화면.
struct OnlineGameView: View {
    let session: OnlineSession

    @AppStorage("showDanger") private var showDanger = true
    @AppStorage("confirmPlacement") private var confirmPlacement = true
    @State private var confirmResign = false

    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top, spacing: 20) {
                playerBar(.black)
                playerBar(.white)
            }
            .padding(.horizontal, 20)

            BoardView(
                board: session.game.board,
                lastMove: session.game.lastMove?.position,
                pending: session.pending,
                pendingStone: session.myStone,
                dangerous: showDanger && session.isMyTurn ? session.game.dangerousPositionsForCurrentPlayer : [],
                losingLine: session.losingLine,
                onTap: { session.tap($0, confirm: confirmPlacement) }
            )
            .padding(.horizontal, 12)

            Text(session.statusText)
                .font(Theme.title(20))
                .foregroundStyle(session.outcome == nil ? Theme.ink : Theme.seal)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            controls
                .padding(.horizontal, 20)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 16)
        .confirmationDialog("기권할까요?", isPresented: $confirmResign, titleVisibility: .visible) {
            Button("기권", role: .destructive) { session.resign() }
        }
    }

    private func playerBar(_ stone: Stone) -> some View {
        let mine = stone == session.myStone
        let active = session.outcome == nil && session.game.currentPlayer == stone
        return PlayerBar(
            stone: stone,
            name: mine ? "나" : session.opponentName,
            detail: "둘 수 있는 칸 \(session.safeCount(for: stone))",
            active: active
        ) {
            if active {
                Text("\(session.secondsLeft)")
                    .font(.system(size: 16, weight: .semibold).monospacedDigit())
                    .foregroundStyle(session.secondsLeft <= 10 ? Theme.seal : Theme.ink)
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        if session.outcome != nil {
            VStack(spacing: 10) {
                if session.opponentLeft {
                    Text("상대가 방을 나갔습니다.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.subInk)
                } else {
                    Button(session.iWantRematch ? "상대의 수락을 기다리는 중…" : (session.opponentWantsRematch ? "한 판 더 (상대가 원해요)" : "한 판 더")) {
                        session.requestRematch()
                    }
                    .buttonStyle(InkButtonStyle())
                    .disabled(session.iWantRematch)
                }
                Button("방 나가기") { session.leave() }
                    .buttonStyle(OutlineButtonStyle())
            }
        } else if session.pending != nil {
            Button("여기에 두기") { session.confirmPending() }
                .buttonStyle(InkButtonStyle())
        } else {
            Button("기권") { confirmResign = true }
                .buttonStyle(OutlineButtonStyle())
        }
    }
}
