import SwiftUI

struct CarRowView: View {
    @Environment(\.themeColors) private var colors

    let car: Car

    var body: some View {
        HStack(spacing: EVAiSpacing.md) {
            CarAvatarView(car: car, size: 44)

            VStack(alignment: .leading, spacing: EVAiSpacing.xxs) {
                Text(car.displayName)
                    .font(EVAiTypography.headline)
                    .foregroundStyle(colors.primaryText)

                Text(subtitle)
                    .font(EVAiTypography.caption)
                    .foregroundStyle(colors.secondaryText)

                if car.batterySizeKWh > 0 {
                    Text("\(String(format: "%.1f", car.batterySizeKWh)) kWh battery")
                        .font(EVAiTypography.caption2)
                        .foregroundStyle(colors.secondaryText)
                }
            }

            Spacer()

            if car.isPrimary {
                Text("Default")
                    .font(EVAiTypography.caption2)
                    .foregroundStyle(Color.primaryBlue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primaryBlue.opacity(0.12), in: Capsule())
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(colors.secondaryText)
        }
        .padding(EVAiSpacing.md)
        .glassCard(padding: 0)
    }

    private var subtitle: String {
        var parts: [String] = []
        let plate = car.licensePlate.trimmingCharacters(in: .whitespacesAndNewlines)
        if !plate.isEmpty {
            parts.append(plate)
        }
        if let collectionDate = car.collectionDate {
            parts.append("Collected \(collectionDate.dayMonthYearDisplay)")
        }
        if car.initialOdometerKM > 0 {
            parts.append("\(Int(car.initialOdometerKM)) km")
        }
        if car.initialSOCPercent > 0 {
            parts.append("\(Int(car.initialSOCPercent))% SOC")
        }
        if car.purchasePriceSGD > 0 {
            parts.append(car.purchasePriceSGD.currencyFormatted)
        }
        if parts.isEmpty {
            return car.make
        }
        return parts.joined(separator: " · ")
    }
}
