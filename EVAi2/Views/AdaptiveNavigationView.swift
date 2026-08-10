import SwiftUI

struct AdaptiveNavigationView: View {
    @Environment(\.themeColors) private var colors
    @Bindable var coordinator: AppCoordinator
    @Bindable var themeManager: ThemeManager

    var body: some View {
        Group {
            if DeviceType.isPad {
                iPadNavigation
            } else {
                iPhoneNavigation
            }
        }
    }

    private var iPhoneNavigation: some View {
        ZStack(alignment: .bottom) {
            AmbientBackground()

            TabView(selection: $coordinator.selectedTab) {
                tabContent(for: .home)
                    .tag(AppTab.home)

                tabContent(for: .history)
                    .tag(AppTab.history)

                tabContent(for: .capture)
                    .tag(AppTab.capture)

                tabContent(for: .analytics)
                    .tag(AppTab.analytics)

                tabContent(for: .profile)
                    .tag(AppTab.profile)
            }
            .toolbar(.hidden, for: .tabBar)

            phoneTabBar
        }
    }

    private var phoneTabBar: some View {
        HStack {
            ForEach(AppTab.phoneTabs) { tab in
                if tab == .capture {
                    Spacer()
                    FloatingCaptureButton(isSelected: coordinator.selectedTab == tab) {
                        coordinator.selectTab(.capture)
                    }
                    Spacer()
                } else {
                    phoneTabItem(tab)
                }
            }
        }
        .padding(.horizontal, EVAiSpacing.lg)
        .padding(.top, EVAiSpacing.sm)
        .padding(.bottom, EVAiSpacing.md)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .background(colors.tabBarBackground)
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    Divider().opacity(0.3)
                }
        }
    }

    private func phoneTabItem(_ tab: AppTab) -> some View {
        Button {
            coordinator.selectTab(tab)
        } label: {
            VStack(spacing: EVAiSpacing.xxs) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 20, weight: coordinator.selectedTab == tab ? .semibold : .regular))
                    .symbolRenderingMode(.hierarchical)

                Text(tab.title)
                    .font(EVAiTypography.tabLabel)
            }
            .foregroundStyle(coordinator.selectedTab == tab ? Color.primaryBlue : colors.secondaryText)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var iPadNavigation: some View {
        NavigationSplitView(columnVisibility: $coordinator.columnVisibility) {
            List(AppTab.sidebarTabs, selection: $coordinator.sidebarSelection) { tab in
                Label(tab.title, systemImage: tab.iconName)
                    .tag(tab)
            }
            .navigationTitle(AppConstants.appName)
        } detail: {
            ZStack {
                AmbientBackground()
                tabContent(for: coordinator.sidebarSelection ?? .home)
            }
        }
        .onChange(of: coordinator.sidebarSelection) { _, newValue in
            if let newValue {
                coordinator.selectedTab = newValue
            }
        }
    }

    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        NavigationStack {
            Group {
                switch tab {
                case .home:
                    HomeDashboardView(coordinator: coordinator)
                case .history:
                    HistoryView()
                case .capture:
                    CaptureView()
                case .analytics:
                    AnalyticsView()
                case .profile:
                    ProfileView(themeManager: themeManager)
                case .settings:
                    AISettingsView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if tab != .home && tab != .capture && tab != .profile {
                    ToolbarItem(placement: .principal) {
                        Text(tab.title)
                            .font(EVAiTypography.headline)
                            .foregroundStyle(colors.primaryText)
                    }
                }
            }
        }
    }
}

#Preview("iPhone") {
    AdaptiveNavigationView(
        coordinator: AppCoordinator(),
        themeManager: ThemeManager()
    )
    .applyTheme(ThemeManager())
}
