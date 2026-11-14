import SwiftUI
import OmokCore

struct MenuView: View {
    @AppStorage("lastConfig") private var configData = Data()
    @AppStorage("tutorialSeen") private var tutorialSeen = false
    @State private var config = MatchConfig()
    @State private var session: GameViewModel?
    @State private var saved: SavedMatch?
    @State private var showOnline = false
    @State private var showRules = false
    @State private var showSettings = false
    @State private var showTutorial = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    masthead
                    options
                    actions
                    footer
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: Binding(
                get: { session != nil },
                set: { if !$0 { session = nil } }
            )) {
                if let session {
                    GameView(model: session)
                }
            }
            .navigationDestination(isPresented: $showOnline) {
                OnlineLobbyView()
            }
            .sheet(isPresented: $showRules) { RulesView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .fullScreenCover(isPresented: $showTutorial) {
                TutorialView {
                    tutorialSeen = true
                    showTutorial = false
                }
            }
            .onAppear {
                if let decoded = try? JSONDecoder().decode(MatchConfig.self, from: configData) {
                    config = decoded
                }
                saved = SavedMatch.load()
                // 처음 켜면 튜토리얼부터 보여 준다.
                if !tutorialSeen { showTutorial = true }
            }
            .onChange(of: session == nil) { _, isClosed in
                if isClosed { saved = SavedMatch.load() }
            }
            .onChange(of: config) { _, newValue in
                configData = (try? JSONEncoder().encode(newValue)) ?? Data()
            }
        }
    }

    private var masthead: some View {
        VStack(spacing: 14) {
            Emblem()
                .frame(width: 110, height: 110)
            Text("리버스 오목")
                .font(Theme.title(40))
                .foregroundStyle(Theme.ink)
            Text("다섯을 이으면 진다")
                .font(.system(size: 15))
                .tracking(4)
                .foregroundStyle(Theme.subInk)
        }
        .padding(.top, 12)
    }

    private var options: some View {
        VStack(spacing: 12) {
            ChoiceRow(
                label: "상대",
                options: GameMode.allCases.map { Choice($0, $0.displayName) },
                selection: $config.mode
            )
            if config.mode == .vsAI {
                ChoiceRow(
                    label: "난이도",
                    options: AIDifficulty.allCases.map { Choice($0, $0.displayName) },
                    selection: $config.difficulty
                )
                ChoiceRow(
                    label: "내 돌",
                    options: [Choice(Stone.black, "흑 · 먼저"), Choice(Stone.white, "백 · 나중")],
                    selection: $config.humanStone
                )
            }
        }
        .animation(.easeOut(duration: 0.15), value: config.mode)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button("대국 시작") {
                session = GameViewModel(config: config)
            }
            .buttonStyle(InkButtonStyle())

            if let saved, !saved.game.isOver, !saved.game.moves.isEmpty {
                Button("이어 두기 · \(saved.game.moves.count)수째") {
                    session = GameViewModel(saved: saved)
                }
                .buttonStyle(OutlineButtonStyle())
            }

            Button("온라인 대국") {
                showOnline = true
            }
            .buttonStyle(OutlineButtonStyle())
        }
    }

    private var footer: some View {
        VStack(spacing: 16) {
            Hairline()
            HStack(spacing: 0) {
                footerLink("튜토리얼") { showTutorial = true }
                footerLink("규칙") { showRules = true }
                footerLink("설정") { showSettings = true }
            }
        }
    }

    private func footerLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
    }
}

/// 흑돌 넷과 금지 칸 하나. 이 게임의 규칙을 그대로 그린 표지.
private struct Emblem: View {
    var body: some View {
        Canvas { ctx, size in
            let cell = size.width / 5
            var grid = Path()
            for i in 0..<5 {
                let x = (CGFloat(i) + 0.5) * cell
                grid.move(to: CGPoint(x: x, y: 0))
                grid.addLine(to: CGPoint(x: x, y: size.height))
                grid.move(to: CGPoint(x: 0, y: x))
                grid.addLine(to: CGPoint(x: size.width, y: x))
            }
            ctx.stroke(grid, with: .color(Theme.ink.opacity(0.35)), lineWidth: 1)

            let radius = cell * 0.38
            for i in 0..<4 {
                let c = (CGFloat(i) + 0.5) * cell
                let rect = CGRect(x: c - radius, y: c - radius, width: radius * 2, height: radius * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(Theme.ink))
            }

            let c = 4.5 * cell
            let d = cell * 0.26
            var cross = Path()
            cross.move(to: CGPoint(x: c - d, y: c - d))
            cross.addLine(to: CGPoint(x: c + d, y: c + d))
            cross.move(to: CGPoint(x: c + d, y: c - d))
            cross.addLine(to: CGPoint(x: c - d, y: c + d))
            ctx.stroke(cross, with: .color(Theme.seal), style: StrokeStyle(lineWidth: 3, lineCap: .square))
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    MenuView()
}
