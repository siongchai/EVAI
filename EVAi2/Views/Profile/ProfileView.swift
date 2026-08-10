import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.themeColors) private var colors
    @Environment(\.modelContext) private var modelContext
    @Bindable var themeManager: ThemeManager
    @Query private var userProfiles: [UserProfile]
    @Query(sort: \Car.createdAt, order: .reverse) private var cars: [Car]

    @State private var showSignOutConfirmation = false
    @State private var signOutMessage: String?
    @State private var showAddCar = false
    @State private var selectedCar: Car?

    private var profile: UserProfile? {
        userProfiles.first
    }

    private var primaryCar: Car? {
        cars.first(where: \.isPrimary) ?? cars.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EVAiSpacing.sectionSpacing) {
                if let profile {
                    NavigationLink {
                        AccountDetailView(profile: profile)
                    } label: {
                        ProfileHeaderView(profile: profile)
                    }
                    .buttonStyle(.plain)
                }

                vehicleSection
                menuSection
                signOutSection
            }
            .padding(.horizontal, EVAiSpacing.horizontalPadding)
            .padding(.top, EVAiSpacing.sm)
            .padding(.bottom, EVAiSpacing.tabBarHeight)
        }
        .scrollIndicators(.hidden)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    AppSettingsView(themeManager: themeManager)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(colors.primaryText)
                }
            }
        }
        .onAppear {
            if userProfiles.isEmpty {
                _ = UserProfileService.ensureProfile(in: modelContext)
            }
        }
        .navigationDestination(isPresented: $showAddCar) {
            AddCarView()
        }
        .navigationDestination(item: $selectedCar) { car in
            CarDetailView(car: car)
        }
        .confirmationDialog("Sign Out?", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                performSignOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears saved cloud AI API keys from this device. Your charging sessions will remain on this device.")
        }
        .alert("Signed Out", isPresented: Binding(
            get: { signOutMessage != nil },
            set: { if !$0 { signOutMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(signOutMessage ?? "")
        }
    }

    private var vehicleSection: some View {
        ProfileVehicleCard(
            car: primaryCar,
            onSelectCar: {
                if let primaryCar {
                    selectedCar = primaryCar
                }
            },
            onAddVehicle: { showAddCar = true }
        )
    }

    private var menuSection: some View {
        ProfileMenuGroup {
            NavigationLink {
                AISettingsView()
            } label: {
                ProfileMenuRow(
                    icon: "brain.head.profile",
                    title: "AI Settings",
                    subtitle: "Configure AI extraction"
                )
            }
            .buttonStyle(.plain)

            menuDivider

            NavigationLink {
                ExportDataView()
            } label: {
                ProfileMenuRow(
                    icon: "tray.and.arrow.down.fill",
                    title: "Export Data",
                    subtitle: "Export your charging data"
                )
            }
            .buttonStyle(.plain)

            menuDivider

            NavigationLink {
                AboutView()
            } label: {
                ProfileMenuRow(
                    icon: "info.circle.fill",
                    title: "About",
                    subtitle: "App version and information"
                )
            }
            .buttonStyle(.plain)

            menuDivider

            NavigationLink {
                HelpSupportView()
            } label: {
                ProfileMenuRow(
                    icon: "questionmark.circle.fill",
                    title: "Help & Support",
                    subtitle: "FAQ and contact us"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var menuDivider: some View {
        Divider()
            .overlay(colors.cardBorder)
            .padding(.leading, 68)
    }

    private var signOutSection: some View {
        ProfileSignOutButton {
            showSignOutConfirmation = true
        }
    }

    private func performSignOut() {
        do {
            try SecureKeyManager.deleteAllAPIKeys()
            signOutMessage = "Cloud AI API keys have been removed from this device."
        } catch {
            signOutMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView(themeManager: ThemeManager())
    }
    .modelContainer(for: [ChargingSession.self, Car.self, AISettings.self, UserProfile.self], inMemory: true)
    .environment(ThemeManager())
    .applyTheme(ThemeManager())
}
