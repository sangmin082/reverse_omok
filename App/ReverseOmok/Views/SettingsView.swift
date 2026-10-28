import SwiftUI
import OmokCore

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("showDanger") private var showDanger = true
    @AppStorage("confirmPlacement") private var confirmPlacement = true
    @AppStorage(Haptics.settingKey) private var hapticsEnabled = true
    @State private var stats = Stats.load()
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section("게임") {
                    Toggle("두면 지는 칸 표시", isOn: $showDanger)
                    Toggle("착수 확인 (두 번 탭)", isOn: $confirmPlacement)
                    Toggle("진동", isOn: $hapticsEnabled)
                }

                Section("컴퓨터 대전 전적") {
                    ForEach(AIDifficulty.allCases) { difficulty in
                        let record = stats[difficulty]
                        HStack {
                            Text(difficulty.displayName)
                            Spacer()
                            Text("\(record.wins)승 \(record.losses)패 \(record.draws)무")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button("전적 초기화", role: .destructive) { confirmReset = true }
                        .disabled(stats == Stats())
                }

                Section {
                    LabeledContent("버전", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-")
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .confirmationDialog("전적을 모두 지울까요?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("초기화", role: .destructive) {
                    stats = Stats()
                    stats.save()
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
