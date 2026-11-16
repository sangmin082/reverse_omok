import SwiftUI
import OmokCore

@main
struct ReverseOmokApp: App {
    init() {
        Theme.registerFonts()
    }

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
            NavigationStack { GameView(model: GameViewModel(saved: Self.sample(.four, Self.fourMoves))) }
        case "game5":
            NavigationStack { GameView(model: GameViewModel(saved: Self.sample(.five, Self.fiveMoves))) }
        case "result":
            NavigationStack { GameView(model: GameViewModel(saved: Self.sample(.four, Self.wonMoves))) }
        case "tutorial":
            TutorialView {}
        case "tutorial2":
            TutorialView(initialStep: .avoid) {}
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
    /// 흑(나)이 둘 차례이고 금지 칸이 보이는 4목 중반.
    private static let fourMoves = [(3, 3), (1, 1), (3, 4), (6, 5), (3, 2), (1, 5), (5, 6), (5, 2), (6, 1), (2, 6)]
    /// 흑(나)이 둘 차례이고 금지 칸이 보이는 5목 중반.
    private static let fiveMoves = [
        (5, 5), (2, 2), (5, 6), (8, 8), (5, 7), (2, 8), (5, 8), (8, 2),
        (3, 5), (7, 5), (9, 4), (4, 3), (1, 6), (6, 9), (8, 6), (3, 9),
    ]
    /// 백(컴퓨터)이 4개를 이어 내가 이긴 판.
    private static let wonMoves = [
        (0, 0), (4, 2), (0, 2), (4, 3), (2, 7), (4, 4), (7, 7), (1, 5), (6, 1), (6, 6), (2, 3), (4, 5),
    ]

    private static func sample(_ rule: GameRule, _ moves: [(Int, Int)]) -> SavedMatch {
        var config = MatchConfig()
        config.rule = rule
        var game = rule.newGame()
        for (r, c) in moves {
            try? game.play(at: Position(row: r, col: c))
        }
        return SavedMatch(config: config, game: game, statsRecorded: true)
    }
    #endif
}
