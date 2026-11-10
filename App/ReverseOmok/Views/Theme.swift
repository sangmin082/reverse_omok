import SwiftUI
import UIKit
import OmokCore

/// 한지 바탕에 먹색 글씨, 인주 빨강 하나만 포인트로 쓰는 바둑판 분위기.
enum Theme {
    static let paper = Color(light: 0xF3EDE2, dark: 0x171512)
    static let ink = Color(light: 0x1D1B18, dark: 0xEDE6DA)
    static let subInk = Color(light: 0x6B655C, dark: 0x9C9488)
    static let rule = Color(light: 0xD6CCBB, dark: 0x38332C)
    /// 인주(도장) 빨강. 금지 칸, 차례 표시, 강조에만 쓴다.
    static let seal = Color(light: 0xC23B2A, dark: 0xE2553F)
    static let wood = Color(light: 0xE2BA78, dark: 0xC49C5E)
    static let woodLine = Color(light: 0x3A2C17, dark: 0x2A1F10)

    /// 제목용 명조. 기기에 없으면 시스템 글꼴로 대체된다.
    static func title(_ size: CGFloat) -> Font {
        .custom("AppleMyungjo", size: size)
    }

    static let label = Font.system(size: 13, weight: .medium)
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

/// 먹으로 채운 주 버튼.
struct InkButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Theme.paper)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Theme.ink.opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.3))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

/// 테두리만 있는 보조 버튼.
struct OutlineButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(Theme.ink.opacity(isEnabled ? 1 : 0.35))
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(configuration.isPressed ? Theme.rule.opacity(0.5) : .clear)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.ink.opacity(isEnabled ? 0.8 : 0.25), lineWidth: 1))
    }
}

struct Choice<Value: Hashable> {
    let value: Value
    let title: String

    init(_ value: Value, _ title: String) {
        self.value = value
        self.title = title
    }
}

/// "라벨 ─ 선택지들" 한 줄. 고른 항목은 먹으로 채운다.
struct ChoiceRow<Value: Hashable>: View {
    let label: String
    let options: [Choice<Value>]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(Theme.label)
                .foregroundStyle(Theme.subInk)
                .frame(width: 64, alignment: .leading)
            HStack(spacing: 0) {
                ForEach(options.indices, id: \.self) { index in
                    let option = options[index]
                    let selected = option.value == selection
                    Button {
                        selection = option.value
                    } label: {
                        Text(option.title)
                            .font(.system(size: 15, weight: selected ? .semibold : .regular))
                            .foregroundStyle(selected ? Theme.paper : Theme.ink)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(selected ? Theme.ink : .clear)
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay(Rectangle().stroke(Theme.ink.opacity(0.8), lineWidth: 1))
        }
    }
}

/// 돌 하나. 목록이나 머리글에 쓴다.
struct StoneDot: View {
    let stone: Stone
    var size: CGFloat = 18

    var body: some View {
        Circle()
            .fill(stone == .black ? Color(white: 0.08) : Color(white: 0.97))
            .overlay(Circle().stroke(Color.black.opacity(0.45), lineWidth: 0.75))
            .frame(width: size, height: size)
    }
}

/// 대국 화면 위쪽의 한쪽 대국자. 차례인 쪽 아래에 인주색 줄이 그어진다.
struct PlayerBar<Trailing: View>: View {
    let stone: Stone
    let name: String
    let detail: String
    let active: Bool
    @ViewBuilder var trailing: Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                StoneDot(stone: stone)
                Text(name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                trailing
            }
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(Theme.subInk)
                .monospacedDigit()
            Rectangle()
                .fill(active ? Theme.seal : Theme.rule)
                .frame(height: active ? 3 : 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeOut(duration: 0.15), value: active)
    }
}

extension PlayerBar where Trailing == EmptyView {
    init(stone: Stone, name: String, detail: String, active: Bool) {
        self.init(stone: stone, name: name, detail: detail, active: active) { EmptyView() }
    }
}

/// 얇은 가로줄.
struct Hairline: View {
    var body: some View {
        Rectangle().fill(Theme.rule).frame(height: 1)
    }
}
