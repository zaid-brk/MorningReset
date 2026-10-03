import SwiftUI
import UIKit

enum ResetTheme {
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.10, green: 0.105, blue: 0.11, alpha: 1)
            : UIColor(red: 0.98, green: 0.965, blue: 0.94, alpha: 1)
    })
    static let card = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.15, green: 0.155, blue: 0.16, alpha: 1) : .white
    })
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.94, green: 0.61, blue: 0.38, alpha: 1)
            : UIColor(red: 0.66, green: 0.29, blue: 0.13, alpha: 1)
    })

    static func symbol(for title: String) -> String {
        let text = title.lowercased()
        if text.contains("push") { return "figure.strengthtraining.functional" }
        if text.contains("jump") { return "figure.jumprope" }
        if text.contains("stretch") { return "figure.flexibility" }
        if text.contains("teeth") { return "sparkles" }
        if text.contains("bathroom") { return "drop" }
        if text.contains("water") { return "drop.fill" }
        if text.contains("bed") { return "bed.double" }
        return "checkmark.circle"
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        if total < 60 { return "\(total) sec" }
        return total % 60 == 0 ? "\(total / 60) min" : "\(total / 60) min \(total % 60) sec"
    }
    static func countdown(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
    static func timeDate(_ time: LockTime) -> Date {
        Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: Date())!
    }
    static func lockTime(_ date: Date) -> LockTime {
        LockTime(hour: Calendar.current.component(.hour, from: date), minute: Calendar.current.component(.minute, from: date))
    }
}

struct ResetCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(ResetTheme.card, in: RoundedRectangle(cornerRadius: 24))
    }
}

struct PrimaryButton: View {
    var title: String
    var symbol: String? = nil
    var disabled = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                if let symbol { Image(systemName: symbol) }
            }
            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 17)
        }
        .buttonStyle(.borderedProminent).tint(ResetTheme.accent)
        .clipShape(RoundedRectangle(cornerRadius: 18)).disabled(disabled)
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(.caption.weight(.semibold)).tracking(2)
            .foregroundStyle(.secondary)
    }
}
