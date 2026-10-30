import SwiftUI
import OmokCore

/// 바둑판과 돌을 그리고 탭한 교차점을 알려 준다.
struct BoardView: View {
    let board: Board
    var lastMove: Position?
    var pending: Position?
    var pendingStone: Stone = .black
    var dangerous: Set<Position> = []
    var losingLine: [Position] = []
    var onTap: (Position) -> Void = { _ in }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = side / CGFloat(board.size)
            Canvas { ctx, _ in
                draw(in: &ctx, side: side, cell: cell)
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture().onEnded { value in
                    let p = Position(row: Int(value.location.y / cell), col: Int(value.location.x / cell))
                    if board.contains(p) { onTap(p) }
                }
            )
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("\(board.size)줄 바둑판, 돌 \(board.stoneCount)개")
    }

    private func center(_ p: Position, cell: CGFloat) -> CGPoint {
        CGPoint(x: (CGFloat(p.col) + 0.5) * cell, y: (CGFloat(p.row) + 0.5) * cell)
    }

    private func draw(in ctx: inout GraphicsContext, side: CGFloat, cell: CGFloat) {
        let n = board.size

        // 판
        let boardRect = CGRect(x: 0, y: 0, width: side, height: side)
        ctx.fill(Path(roundedRect: boardRect, cornerRadius: cell * 0.25), with: .color(Color("BoardWood")))

        // 줄
        var grid = Path()
        let start = cell / 2
        let end = side - cell / 2
        for i in 0..<n {
            let x = (CGFloat(i) + 0.5) * cell
            grid.move(to: CGPoint(x: x, y: start))
            grid.addLine(to: CGPoint(x: x, y: end))
            grid.move(to: CGPoint(x: start, y: x))
            grid.addLine(to: CGPoint(x: end, y: x))
        }
        ctx.stroke(grid, with: .color(.black.opacity(0.75)), lineWidth: max(0.5, cell * 0.03))

        // 화점
        let edge = n >= 13 ? 3 : 2
        for r in [edge, n / 2, n - 1 - edge] {
            for c in [edge, n / 2, n - 1 - edge] {
                let pt = center(Position(row: r, col: c), cell: cell)
                let rr = cell * 0.09
                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - rr, y: pt.y - rr, width: rr * 2, height: rr * 2)), with: .color(.black))
            }
        }

        // 금수 표시
        for p in dangerous {
            let pt = center(p, cell: cell)
            let d = cell * 0.18
            var x = Path()
            x.move(to: CGPoint(x: pt.x - d, y: pt.y - d))
            x.addLine(to: CGPoint(x: pt.x + d, y: pt.y + d))
            x.move(to: CGPoint(x: pt.x + d, y: pt.y - d))
            x.addLine(to: CGPoint(x: pt.x - d, y: pt.y + d))
            ctx.stroke(x, with: .color(.red.opacity(0.8)), style: StrokeStyle(lineWidth: max(1, cell * 0.07), lineCap: .round))
        }

        // 돌
        let radius = cell * 0.46
        for p in board.allPositions {
            guard let stone = board[p] else { continue }
            drawStone(stone, at: center(p, cell: cell), radius: radius, in: &ctx)
        }

        // 착수 대기
        if let pending {
            var preview = ctx
            preview.opacity = 0.5
            drawStone(pendingStone, at: center(pending, cell: cell), radius: radius, in: &preview)
        }

        // 마지막 수
        if let lastMove, losingLine.isEmpty {
            let pt = center(lastMove, cell: cell)
            let r = cell * 0.12
            ctx.fill(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)), with: .color(.red))
        }

        // 5목 줄
        if let first = losingLine.first, let last = losingLine.last {
            var line = Path()
            line.move(to: center(first, cell: cell))
            line.addLine(to: center(last, cell: cell))
            ctx.stroke(line, with: .color(.red), style: StrokeStyle(lineWidth: cell * 0.12, lineCap: .round))
        }
    }

    private func drawStone(_ stone: Stone, at pt: CGPoint, radius: CGFloat, in ctx: inout GraphicsContext) {
        let rect = CGRect(x: pt.x - radius, y: pt.y - radius, width: radius * 2, height: radius * 2)
        let circle = Path(ellipseIn: rect)
        let highlight = CGPoint(x: pt.x - radius * 0.35, y: pt.y - radius * 0.35)
        switch stone {
        case .black:
            ctx.fill(circle, with: .radialGradient(
                Gradient(colors: [Color(white: 0.45), Color(white: 0.05)]),
                center: highlight, startRadius: 0, endRadius: radius * 1.3))
        case .white:
            ctx.fill(circle, with: .radialGradient(
                Gradient(colors: [.white, Color(white: 0.82)]),
                center: highlight, startRadius: 0, endRadius: radius * 1.3))
            ctx.stroke(circle, with: .color(.black.opacity(0.35)), lineWidth: max(0.5, radius * 0.05))
        }
    }
}

#Preview {
    BoardView(board: Board(size: 15), pending: Position(row: 7, col: 7))
        .padding()
}
