import SwiftUI
import OmokCore

@main
struct ReverseOmokApp: App {
    var body: some Scene {
        WindowGroup {
            root
                .tint(Theme.seal)
        }
    }

    @ViewBuilder
    private var root: some View {
        #if DEBUG
        // 스크린샷용: 실행 인자 `-screen game`처럼 넘기면 그 화면으로 바로 연다.
        switch UserDefaults.standard.string(forKey: "screen") {
        case "game":
            NavigationStack { GameView(model: GameViewModel(saved: Self.sampleMatch)) }
        case "tutorial":
            TutorialView {}
        case "online":
            NavigationStack { OnlineLobbyView() }
        default:
            MenuView()
        }
        #else
        MenuView()
        #endif
    }

    #if DEBUG
    private static var sampleMatch: SavedMatch {
        var game = Game(size: MatchConfig.boardSize, runLength: MatchConfig.runLength)
        for (r, c) in [(3, 3), (2, 2), (3, 4), (5, 1), (1, 5), (4, 4), (5, 5), (0, 3), (6, 2), (2, 5)] {
            try? game.play(at: Position(row: r, col: c))
        }
        return SavedMatch(config: MatchConfig(), game: game, statsRecorded: true)
    }
    #endif
}
