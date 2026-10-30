import SwiftUI

struct RulesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("규칙") {
                    rule("1", "흑이 먼저 두고, 번갈아 한 수씩 둡니다.")
                    rule("2", "가로·세로·대각선으로 자기 돌을 5개 이상 연속으로 놓으면 집니다. 6목 이상도 패배입니다.")
                    rule("3", "판이 가득 찰 때까지 아무도 5목을 만들지 않으면 무승부입니다.")
                    rule("4", "둘 수 있는 칸이 모두 5목 자리뿐이라면 어쩔 수 없이 두어야 하고, 그대로 집니다.")
                }

                Section("화면 보는 법") {
                    Label("빨간 ×는 지금 두면 지는 칸입니다. 설정에서 끌 수 있어요.", systemImage: "xmark")
                    Label("'둘 수 있는 칸'은 각자 5목을 만들지 않고 둘 수 있는 빈칸 수입니다.", systemImage: "number")
                    Label("착수 확인을 켜면 한 번 탭해 미리 보고, 한 번 더 탭하면 둡니다.", systemImage: "hand.tap")
                }

                Section("요령") {
                    Text("자기 돌끼리 한 줄로 모이지 않게 흩어 두세요. 4개가 이어지면 그 옆 칸은 나에게만 금지된 칸이 됩니다.")
                    Text("반대로 상대의 줄은 막지 말고 내버려 두세요. 상대에게 금지된 칸은 나만 쓸 수 있는 칸이 됩니다.")
                    Text("후반에는 '둘 수 있는 칸' 숫자가 승부를 가릅니다. 상대보다 내 칸이 많도록 관리하세요.")
                }
            }
            .navigationTitle("리버스 오목 규칙")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    private func rule(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.headline)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.accentColor.opacity(0.2)))
            Text(text)
        }
    }
}

#Preview {
    RulesView()
}
