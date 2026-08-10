import SwiftUI

struct SessionCard: View {
    @Environment(\.themeColors) private var colors

    let session: ChargingSession

    var body: some View {
        HStack(spacing: EVAiSpacing.md) {
            NetworkBadge(network: session.chargingNetwork, initials: session.networkInitials)

            VStack(alignment: .leading, spacing: EVAiSpacing.xxs) {
                Text(session.chargingLocation)
                    .font(EVAiTypography.headline)
                    .foregroundStyle(colors.primaryText)
                    .lineLimit(1)

                Text("\(session.startDate.dayMonthYearDisplay) · \(session.startDate.timeDisplay)")
                    .font(EVAiTypography.caption)
                    .foregroundStyle(colors.secondaryText)
            }

            Spacer(minLength: EVAiSpacing.sm)

            VStack(alignment: .trailing, spacing: EVAiSpacing.xxs) {
                Text(session.energyKWh.energyFormatted)
                    .font(EVAiTypography.subheadline)
                    .foregroundStyle(colors.primaryText)

                Text(session.amountSGD.currencyFormatted)
                    .font(EVAiTypography.caption)
                    .foregroundStyle(colors.secondaryText)
            }
        }
        .padding(EVAiSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: EVAiSpacing.buttonRadius, style: .continuous)
                .fill(colors.cardBackground.opacity(0.6))
                .overlay {
                    RoundedRectangle(cornerRadius: EVAiSpacing.buttonRadius, style: .continuous)
                        .strokeBorder(colors.cardBorder.opacity(0.6), lineWidth: 1)
                }
        }
    }
}

struct NetworkBadge: View {
    let network: String
    let initials: String

    var badgeColor: Color {
        switch network.lowercased() {
        case let name where name.contains("sp"): Color.primaryBlue
        case let name where name.contains("charge"): Color.aiPurple
        case let name where name.contains("shell"): Color(hex: 0xFFD60A)
        case let name where name.contains("home"): Color.electricCyan
        default: Color.secondaryGray
        }
    }

    var body: some View {
        Text(initials)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(badgeColor.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
