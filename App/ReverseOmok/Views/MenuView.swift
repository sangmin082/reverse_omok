import SwiftUI
import OmokCore

struct MenuView: View {
    @AppStorage("lastConfig") private var configData = Data()
    @State private var config = MatchConfig()
    @State private var session: GameViewModel?
    @State private var saved: SavedMatch?
    @State private var showRules = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 6) {
                        Text("리버스 오목")
                            .font(.largeTitle.bold())
                        Text("다섯 개를 이으면 집니다")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section("대전 방식") {
                    Picker("상대", selection: $config.mode) {
                        ForEach(GameMode.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if config.mode == .vsAI {
                        Picker("난이도", selection: $config.difficulty) {
                            ForEach(AIDifficulty.allCases) { Text($0.displayName).tag($0) }
                        }
                        Picker("내 돌", selection: $config.humanStone) {
                            Text("흑 (먼저)").tag(Stone.black)
                            Text("백 (나중)").tag(Stone.white)
                        }
                    }

                    Picker("판 크기", selection: $config.boardSize) {
                        ForEach(Board.supportedSizes, id: \.self) { Text("\($0)줄").tag($0) }
                    }
                }

                Section {
                    Button {
                        start(GameViewModel(config: config))
                    } label: {
                        Label("새 게임 시작", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .listRowBackground(Color.clear)

                    if let saved, !saved.game.isOver, !saved.game.moves.isEmpty {
                        Button {
                            start(GameViewModel(saved: saved))
                        } label: {
                            Label("이어하기 · \(saved.config.boardSize)줄 \(saved.game.moves.count)수째", systemImage: "arrow.forward.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showRules = true } label: { Label("규칙", systemImage: "questionmark.circle") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Label("설정", systemImage: "gearshape") }
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { session != nil },
                set: { if !$0 { session = nil } }
            )) {
                if let session {
                    GameView(model: session)
                }
            }
            .sheet(isPresented: $showRules) { RulesView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .onAppear {
                if let decoded = try? JSONDecoder().decode(MatchConfig.self, from: configData) {
                    config = decoded
                }
                saved = SavedMatch.load()
            }
            .onChange(of: session == nil) { _, isClosed in
                if isClosed { saved = SavedMatch.load() }
            }
            .onChange(of: config) { _, newValue in
                configData = (try? JSONEncoder().encode(newValue)) ?? Data()
            }
        }
    }

    private func start(_ model: GameViewModel) {
        session = model
    }
}

#Preview {
    MenuView()
}
