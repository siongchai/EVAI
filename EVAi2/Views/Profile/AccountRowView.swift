import SwiftUI

struct AccountRowView: View {
    @Environment(\.themeColors) private var colors

    let profile: UserProfile

    var body: some View {
        HStack(spacing: EVAiSpacing.md) {
            ProfileAvatarView(profile: profile, size: 44)

            VStack(alignment: .leading, spacing: EVAiSpacing.xxs) {
                Text(profile.displayName)
                    .font(EVAiTypography.headline)
                    .foregroundStyle(colors.primaryText)

                Text(subtitle)
                    .font(EVAiTypography.caption)
                    .foregroundStyle(colors.secondaryText)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(colors.secondaryText)
        }
        .padding(EVAiSpacing.md)
        .glassCard(padding: 0)
    }

    private var subtitle: String {
        let trimmedEmail = profile.email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedEmail.isEmpty ? "No email set" : trimmedEmail
    }
}
