import UIKit

enum Haptics {
    static let settingKey = "hapticsEnabled"

    private static var enabled: Bool {
        UserDefaults.standard.object(forKey: settingKey) as? Bool ?? true
    }

    static func select() {
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func place() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func gameOver(won: Bool) {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(won ? .success : .error)
    }
}
