import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration { appearance() }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration { appearance() }

    private func appearance() -> ShieldConfiguration {
        let background = UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
                : UIColor(red: 0.98, green: 0.96, blue: 0.93, alpha: 1)
        }
        let accent = UIColor(red: 0.68, green: 0.29, blue: 0.12, alpha: 1)
        return ShieldConfiguration(backgroundBlurStyle: .systemMaterial, backgroundColor: background,
            icon: UIImage(systemName: "sun.horizon.fill"),
            title: .init(text: "A little space for your morning", color: .label),
            subtitle: .init(text: "Open Morning Reset to begin your routine or review your protection settings.", color: .secondaryLabel),
            primaryButtonLabel: .init(text: "Close", color: .white), primaryButtonBackgroundColor: accent)
    }
}
