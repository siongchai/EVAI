import SwiftUI

struct ProfileAvatarView: View {
    @Environment(\.themeColors) private var colors

    let name: String
    var image: UIImage? = nil
    var size: CGFloat = 56

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.primaryBlue.opacity(0.85), Color.aiPurple.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text(initials)
                        .font(.system(size: size * 0.34, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(colors.cardBorder, lineWidth: 1)
        }
    }

    private var initials: String {
        let parts = name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
        if parts.isEmpty { return "?" }
        return parts.joined().uppercased()
    }
}

extension ProfileAvatarView {
    init(profile: UserProfile, size: CGFloat = 56) {
        self.init(name: profile.displayName, image: profile.photoImage, size: size)
    }
}

struct ProfileHeaderView: View {
    @Environment(\.themeColors) private var colors

    let profile: UserProfile

    var body: some View {
        HStack(spacing: EVAiSpacing.md) {
            ProfileAvatarView(profile: profile, size: 56)

            VStack(alignment: .leading, spacing: EVAiSpacing.xxs) {
                Text(profile.displayName)
                    .font(EVAiTypography.title3)
                    .foregroundStyle(colors.primaryText)

                Text(emailDisplay)
                    .font(EVAiTypography.subheadline)
                    .foregroundStyle(colors.secondaryText)
            }

            Spacer(minLength: 0)
        }
    }

    private var emailDisplay: String {
        let trimmed = profile.email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Add your email" : trimmed
    }
}

struct ProfileVehicleCard: View {
    @Environment(\.themeColors) private var colors

    let car: Car?
    var onSelectCar: (() -> Void)? = nil
    var onAddVehicle: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.md) {
            Text("My Vehicle")
                .font(EVAiTypography.caption)
                .foregroundStyle(colors.secondaryText)

            if let car {
                Button {
                    onSelectCar?()
                } label: {
                    HStack(alignment: .center, spacing: EVAiSpacing.sm) {
                        VStack(alignment: .leading, spacing: EVAiSpacing.xs) {
                            HStack(spacing: EVAiSpacing.xs) {
                                Text(car.displayName)
                                    .font(EVAiTypography.headline)
                                    .foregroundStyle(colors.primaryText)
                                    .lineLimit(2)

                                if car.isPrimary {
                                    Text("Primary")
                                        .font(EVAiTypography.caption2)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.primaryBlue, in: Capsule())
                                }
                            }
                        }

                        Spacer(minLength: EVAiSpacing.sm)

                        vehicleImage(for: car)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Text("No vehicle added yet")
                    .font(EVAiTypography.subheadline)
                    .foregroundStyle(colors.secondaryText)
            }

            Button {
                onAddVehicle?()
            } label: {
                HStack(spacing: EVAiSpacing.xxs) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Add Vehicle")
                        .font(EVAiTypography.subheadline.weight(.semibold))
                }
                .foregroundStyle(Color.primaryBlue)
                .padding(.horizontal, EVAiSpacing.sm)
                .padding(.vertical, EVAiSpacing.xs)
                .background(Color.primaryBlue.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    @ViewBuilder
    private func vehicleImage(for car: Car) -> some View {
        Group {
            if let image = car.photoImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.primaryBlue.opacity(0.10))
                    Image(systemName: "car.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(Color.primaryBlue)
                }
            }
        }
        .frame(width: 112, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct ProfileMenuRow: View {
    @Environment(\.themeColors) private var colors

    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: EVAiSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.primaryBlue)
                .frame(width: 40, height: 40)
                .background(Color.primaryBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(EVAiTypography.headline)
                    .foregroundStyle(colors.primaryText)

                Text(subtitle)
                    .font(EVAiTypography.caption)
                    .foregroundStyle(colors.secondaryText)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(colors.secondaryText.opacity(0.8))
        }
        .padding(.horizontal, EVAiSpacing.md)
        .padding(.vertical, EVAiSpacing.sm + 2)
        .contentShape(Rectangle())
    }
}

struct ProfileMenuGroup<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .glassCard(padding: 0)
    }
}

struct ProfileSignOutButton: View {
    @Environment(\.themeColors) private var colors

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Sign Out")
                .font(EVAiTypography.headline)
                .foregroundStyle(colors.destructive)
                .frame(maxWidth: .infinity)
                .padding(.vertical, EVAiSpacing.md)
        }
        .buttonStyle(.plain)
        .glassCard(padding: 0)
    }
}
