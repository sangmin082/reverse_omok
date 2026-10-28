/// AI 탐색용 보드. 착수/무르기마다 평가값을 증분 갱신한다.
///
/// 핵심 관찰: 빈 칸 c에 X를 두면 5목 이상이 되는 것은, c를 포함하는 길이 5의 창(window) 중
/// "X 4개 + 빈칸 c"인 창이 있을 때와 정확히 같다. 그래서 창별로 흑/백 돌 수를 세어 두면
/// 각 칸이 누구에게 금수(두면 지는 칸)인지 O(1)로 알 수 있다.
///
/// - 흑만 못 두는 칸 = 백 전용 칸(백의 비축 수)
/// - 백만 못 두는 칸 = 흑 전용 칸
/// - 둘 다 둘 수 있는 칸 = 공용 칸
/// 공용 칸이 떨어지면 전용 칸이 많은 쪽이 이긴다.
struct SearchState {
    static let empty: UInt8 = 0

    let size: Int
    private(set) var cells: [UInt8]
    private(set) var emptyCount: Int

    /// 창 w의 칸 인덱스는 windowCells[w*5 ..< w*5+5].
    private let windowCells: [Int]
    /// 칸별로 그 칸을 포함하는 창 목록.
    private let cellWindows: [[Int]]
    /// 창별 돌 수. [1]=흑, [2]=백 (index 0 미사용).
    private var windowCount: [[UInt8]]
    /// 칸별로 "그 칸이 유일한 빈칸이고 나머지 4칸이 해당 색"인 창의 수.
    private var killCount: [[UInt8]]

    /// 빈 칸 분류 집계. reserve[1] = 흑만 둘 수 있는 칸 수, reserve[2] = 백만 둘 수 있는 칸 수.
    private(set) var reserve: [Int] = [0, 0, 0]
    private(set) var shared: Int = 0
    private(set) var dead: Int = 0
    /// 색별 모양 점수(같은 색만 있는 창에 돌이 2~3개면 장차 금수가 생길 위험). 높을수록 그 색에 불리.
    private(set) var shapeRisk: [Int] = [0, 0, 0]

    static let riskWeight: [Int] = [0, 0, 1, 6, 0, 0]

    init(board: Board) {
        let n = board.size
        size = n
        cells = Array(repeating: Self.empty, count: n * n)
        emptyCount = n * n

        var wc: [Int] = []
        var cw: [[Int]] = Array(repeating: [], count: n * n)
        for r in 0..<n {
            for c in 0..<n {
                for d in lineDirections {
                    let er = r + d.dr * (losingRunLength - 1)
                    let ec = c + d.dc * (losingRunLength - 1)
                    guard er >= 0, er < n, ec >= 0, ec < n else { continue }
                    let w = wc.count / losingRunLength
                    for k in 0..<losingRunLength {
                        let idx = (r + d.dr * k) * n + (c + d.dc * k)
                        wc.append(idx)
                        cw[idx].append(w)
                    }
                }
            }
        }
        windowCells = wc
        cellWindows = cw
        let windowTotal = wc.count / losingRunLength
        windowCount = Array(repeating: Array(repeating: 0, count: windowTotal), count: 3)
        killCount = Array(repeating: Array(repeating: 0, count: n * n), count: 3)
        shared = n * n

        for p in board.allPositions {
            if let s = board[p] { place(p.row * n + p.col, color: s.rawValue) }
        }
    }

    // MARK: - 조회

    @inline(__always) func isEmpty(_ idx: Int) -> Bool { cells[idx] == Self.empty }

    /// 빈 칸 idx에 color를 두면 지는가.
    @inline(__always) func isForbidden(_ idx: Int, for color: UInt8) -> Bool {
        killCount[Int(color)][idx] > 0
    }

    /// color가 둘 수 있는(지지 않는) 칸의 수.
    func safeCount(for color: UInt8) -> Int { shared + reserve[Int(color)] }

    func safeMoves(for color: UInt8) -> [Int] {
        var result: [Int] = []
        result.reserveCapacity(emptyCount)
        for idx in 0..<cells.count where cells[idx] == Self.empty && killCount[Int(color)][idx] == 0 {
            result.append(idx)
        }
        return result
    }

    /// color 입장의 정적 평가값(둘 차례인 쪽 기준).
    func evaluate(for color: UInt8) -> Int {
        let me = Int(color)
        let opp = 3 - me
        var score = 60 * (reserve[me] - reserve[opp])
        score += shapeRisk[opp] - shapeRisk[me]
        // 공용 칸을 다 쓰고 나면 차례가 누구에게 돌아오는지가 승패를 가른다.
        if shared <= 24 {
            score += shared % 2 == 1 ? 30 : -30
        }
        return score
    }

    // MARK: - 착수/무르기

    mutating func place(_ idx: Int, color: UInt8) {
        precondition(cells[idx] == Self.empty)
        untally(idx)
        cells[idx] = color
        emptyCount -= 1
        let me = Int(color)
        let opp = 3 - me

        for w in cellWindows[idx] {
            let oldMine = Int(windowCount[me][w])
            let oldOpp = Int(windowCount[opp][w])
            // 이 칸이 유일한 빈칸이던 4목 창은 사라진다.
            if oldMine == 4 && oldOpp == 0 { killCount[me][idx] -= 1 }
            if oldOpp == 4 && oldMine == 0 { killCount[opp][idx] -= 1 }

            removeShape(mine: oldMine, opp: oldOpp, me: me)
            windowCount[me][w] += 1
            addShape(mine: oldMine + 1, opp: oldOpp, me: me)

            if oldMine + 1 == 4 && oldOpp == 0 {
                let e = emptyCell(in: w)
                untally(e)
                killCount[me][e] += 1
                tally(e)
            }
        }
    }

    mutating func remove(_ idx: Int) {
        let color = cells[idx]
        precondition(color != Self.empty)
        let me = Int(color)
        let opp = 3 - me

        for w in cellWindows[idx] {
            let oldMine = Int(windowCount[me][w])
            let oldOpp = Int(windowCount[opp][w])
            if oldMine == 4 && oldOpp == 0 {
                // 4목 창이 3목으로 줄면 그 창의 빈칸은 더 이상 금수가 아니다.
                let e = emptyCell(in: w)
                untally(e)
                killCount[me][e] -= 1
                tally(e)
            }
            removeShape(mine: oldMine, opp: oldOpp, me: me)
            windowCount[me][w] -= 1
            addShape(mine: oldMine - 1, opp: oldOpp, me: me)

            // 돌을 빼고 나서 4목 창이 되면 idx가 그 창의 유일한 빈칸이다.
            if oldMine - 1 == 4 && oldOpp == 0 { killCount[me][idx] += 1 }
            if oldOpp == 4 && oldMine - 1 == 0 { killCount[opp][idx] += 1 }
        }
        cells[idx] = Self.empty
        emptyCount += 1
        tally(idx)
    }

    // MARK: - 내부

    private func emptyCell(in w: Int) -> Int {
        let base = w * losingRunLength
        for k in 0..<losingRunLength where cells[windowCells[base + k]] == Self.empty {
            return windowCells[base + k]
        }
        preconditionFailure("window \(w) has no empty cell")
    }

    @inline(__always) private mutating func removeShape(mine: Int, opp: Int, me: Int) {
        if opp == 0 { shapeRisk[me] -= Self.riskWeight[mine] }
        if mine == 0 { shapeRisk[3 - me] -= Self.riskWeight[opp] }
    }

    @inline(__always) private mutating func addShape(mine: Int, opp: Int, me: Int) {
        if opp == 0 { shapeRisk[me] += Self.riskWeight[mine] }
        if mine == 0 { shapeRisk[3 - me] += Self.riskWeight[opp] }
    }

    private mutating func tally(_ idx: Int) { adjustTally(idx, by: 1) }
    private mutating func untally(_ idx: Int) { adjustTally(idx, by: -1) }

    private mutating func adjustTally(_ idx: Int, by delta: Int) {
        guard cells[idx] == Self.empty else { return }
        let blackBanned = killCount[1][idx] > 0
        let whiteBanned = killCount[2][idx] > 0
        switch (blackBanned, whiteBanned) {
        case (false, false): shared += delta
        case (true, true): dead += delta
        case (true, false): reserve[2] += delta
        case (false, true): reserve[1] += delta
        }
    }
}
