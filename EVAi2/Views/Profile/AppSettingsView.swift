import SwiftUI
import SwiftData

struct AppSettingsView: View {
    @Environment(\.themeColors) private var colors
    @Environment(\.modelContext) private var modelContext
    @Bindable var themeManager: ThemeManager
    @Query private var settingsRecords: [AISettings]

    @State private var viewModel = SettingsViewModel()
    @State private var showDeleteConfirmation = false
    @State private var showClearCacheConfirmation = false
    @State private var showResetPromptConfirmation = false
    @State private var ltaAccountKey = LTAChargerCatalogSyncService.accountKey ?? ""
    @State private var isRefreshingChargerCatalog = false
    @State private var statusMessage: String?
    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EVAiSpacing.sectionSpacing) {
                appearanceSection
                aiSection
                chargerCatalogSection
                storageSection
                dataSection
                exportSection
                if let statusMessage {
                    Text(statusMessage)
                        .font(EVAiTypography.caption)
                        .foregroundStyle(Color.primaryBlue)
                        .glassCard()
                }
            }
            .padding(.horizontal, EVAiSpacing.horizontalPadding)
            .padding(.bottom, EVAiSpacing.xxxl)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let settings = settingsRecords.first {
                viewModel.bind(settings: settings)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
        .confirmationDialog("Delete all local data?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Everything", role: .destructive) {
                performDeleteAllData()
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Clear image cache?", isPresented: $showClearCacheConfirmation, titleVisibility: .visible) {
            Button("Clear Cache", role: .destructive) {
                viewModel.clearImageCache()
                statusMessage = "Image cache cleared."
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Reset extraction prompt?", isPresented: $showResetPromptConfirmation, titleVisibility: .visible) {
            Button("Reset Prompt", role: .destructive) {
                viewModel.restoreDefaultPrompt()
                statusMessage = "Extraction prompt restored to default."
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var appearanceSection: some View {
        settingsGroup(title: "Appearance") {
            Picker("Theme", selection: $themeManager.selectedTheme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }
            .pickerStyle(.segmented)
            .evaiAccessibleLabel("App theme", hint: "Choose light, dark, or system theme")
        }
    }

    private var aiSection: some View {
        settingsGroup(title: "AI Extraction") {
            if let settings = viewModel.settings {
                VStack(alignment: .leading, spacing: EVAiSpacing.sm) {
                    Text("Confidence Threshold")
                        .font(EVAiTypography.subheadline)
                        .foregroundStyle(colors.secondaryText)
                    Slider(
                        value: Binding(
                            get: { settings.confidenceThreshold },
                            set: { viewModel.updateConfidenceThreshold($0) }
                        ),
                        in: 0.5...1.0,
                        step: 0.05
                    )
                    Text("\(Int(settings.confidenceThreshold * 100))%")
                        .font(EVAiTypography.caption)
                        .foregroundStyle(colors.secondaryText)
                }

                NavigationLink {
                    AISettingsView()
                } label: {
                    settingsActionRow(title: "Advanced AI Settings", icon: "brain.head.profile")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var chargerCatalogSection: some View {
        settingsGroup(title: "Charger Catalog") {
            VStack(alignment: .leading, spacing: EVAiSpacing.sm) {
                Text("LTA DataMall Account Key")
                    .font(EVAiTypography.subheadline)
                    .foregroundStyle(colors.secondaryText)
                SecureField("Optional API key", text: $ltaAccountKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: ltaAccountKey) { _, newValue in
                        LTAChargerCatalogSyncService.accountKey = newValue.nilIfEmpty
                    }
                Text("Used to refresh Singapore charger type and power data from LTA before Excel import.")
                    .font(EVAiTypography.caption)
                    .foregroundStyle(colors.secondaryText)
            }

            Button {
                refreshChargerCatalog()
            } label: {
                HStack(spacing: EVAiSpacing.md) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(Color.primaryBlue)
                    Text(isRefreshingChargerCatalog ? "Refreshing..." : "Refresh Charger Catalog")
                        .font(EVAiTypography.subheadline)
                        .foregroundStyle(colors.primaryText)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .disabled(isRefreshingChargerCatalog || ltaAccountKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func refreshChargerCatalog() {
        guard !isRefreshingChargerCatalog else { return }
        isRefreshingChargerCatalog = true
        Task {
            defer { isRefreshingChargerCatalog = false }
            do {
                let count = try await LTAChargerCatalogSyncService.refreshCatalogIfConfigured()
                statusMessage = "Refreshed \(count) charger catalog entries from LTA."
            } catch {
                statusMessage = "Unable to refresh charger catalog: \(error.localizedDescription)"
            }
        }
    }

    private var storageSection: some View {
        settingsGroup(title: "Storage") {
            settingsInfoRow(title: "Image Storage", value: viewModel.formattedStorageUsage)
            settingsInfoRow(title: "Pending Retries", value: "\(viewModel.pendingExtractionCount(in: modelContext))")

            Button {
                showClearCacheConfirmation = true
            } label: {
                settingsActionRow(title: "Clear Image Cache", icon: "photo.on.rectangle.angled")
            }
            .buttonStyle(.plain)
        }
    }

    private var dataSection: some View {
        settingsGroup(title: "Data") {
            Button {
                showResetPromptConfirmation = true
            } label: {
                settingsActionRow(title: "Reset Extraction Prompt", icon: "arrow.counterclockwise")
            }
            .buttonStyle(.plain)

            Button {
                showDeleteConfirmation = true
            } label: {
                settingsActionRow(title: "Delete All Local Data", icon: "trash.fill", isDestructive: true)
            }
            .buttonStyle(.plain)
        }
    }

    private var exportSection: some View {
        settingsGroup(title: "Export Settings") {
            Button {
                exportSettings()
            } label: {
                settingsActionRow(title: "Export Settings Snapshot", icon: "square.and.arrow.up")
            }
            .buttonStyle(.plain)
        }
    }

    private func settingsGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.md) {
            SectionHeader(title: title)
            VStack(alignment: .leading, spacing: EVAiSpacing.md) {
                content()
            }
            .glassCard()
        }
    }

    private func settingsInfoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(EVAiTypography.subheadline)
                .foregroundStyle(colors.primaryText)
            Spacer()
            Text(value)
                .font(EVAiTypography.caption)
                .foregroundStyle(colors.secondaryText)
        }
    }

    private func settingsActionRow(title: String, icon: String, isDestructive: Bool = false) -> some View {
        HStack(spacing: EVAiSpacing.md) {
            Image(systemName: icon)
                .foregroundStyle(isDestructive ? .red : Color.primaryBlue)
            Text(title)
                .font(EVAiTypography.subheadline)
                .foregroundStyle(isDestructive ? .red : colors.primaryText)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(colors.secondaryText)
        }
    }

    private func performDeleteAllData() {
        do {
            try viewModel.deleteAllLocalData(using: modelContext)
            statusMessage = "All local data deleted."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func exportSettings() {
        let snapshot = viewModel.exportSettingsSnapshot(settings: settingsRecords.first)
        if let url = viewModel.writeSettingsExport(snapshot) {
            shareItems = [url]
            showShareSheet = true
        }
    }
}
