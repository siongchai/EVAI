import SwiftUI
import SwiftData

struct AISettingsView: View {
    @Environment(\.themeColors) private var colors
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsRecords: [AISettings]

    @State private var viewModel = SettingsViewModel()

    private var settings: AISettings? {
        settingsRecords.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EVAiSpacing.sectionSpacing) {
                cloudProviderSection
                openAISection
                claudeSection
                confidenceSection
                autoReviewSection
                fieldSourceSection
                promptSection
            }
            .padding(.horizontal, EVAiSpacing.horizontalPadding)
            .padding(.bottom, EVAiSpacing.xxxl)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("AI Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            ensureSettingsRecord()
            if let settings {
                viewModel.bind(settings: settings)
            }
        }
        .onChange(of: settingsRecords.count) { _, _ in
            if let settings {
                viewModel.bind(settings: settings)
            }
        }
    }

    private var cloudProviderSection: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.md) {
            SectionHeader(title: "Cloud Extraction")

            Text("Choose which vision model to use when both API keys are saved. Without a cloud key, the app uses Apple Intelligence or on-device OCR.")
                .font(EVAiTypography.footnote)
                .foregroundStyle(colors.secondaryText)

            Picker("Preferred Provider", selection: Binding(
                get: { viewModel.preferredCloudProvider },
                set: { viewModel.updatePreferredCloudProvider($0) }
            )) {
                ForEach(CloudExtractionProvider.allCases) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.preferredCloudProvider) { _, _ in
                try? viewModel.save(using: modelContext)
            }
            .glassCard()
        }
    }

    private var openAISection: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.md) {
            SectionHeader(title: "OpenAI API Key")

            Text(CloudExtractionProvider.openAI.keyHelpText)
                .font(EVAiTypography.footnote)
                .foregroundStyle(colors.secondaryText)

            VStack(alignment: .leading, spacing: EVAiSpacing.sm) {
                HStack {
                    Text(viewModel.hasStoredOpenAIKey ? "OpenAI key configured" : "No OpenAI key saved")
                        .font(EVAiTypography.subheadline)
                        .foregroundStyle(viewModel.hasStoredOpenAIKey ? Color(hex: 0x34C759) : colors.secondaryText)
                    Spacer()
                    if viewModel.hasStoredOpenAIKey {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color(hex: 0x34C759))
                    }
                }

                SecureField(CloudExtractionProvider.openAI.keyPlaceholder, text: $viewModel.openAIKeyInput)
                    .font(EVAiTypography.body)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, EVAiSpacing.sm)
                    .padding(.vertical, EVAiSpacing.xs + 2)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(colors.cardBorder.opacity(0.35))
                    }

                if let error = viewModel.openAIKeyError {
                    Text(error)
                        .font(EVAiTypography.caption)
                        .foregroundStyle(Color(hex: 0xFF3B30))
                }

                if viewModel.openAIKeySaved {
                    Text("OpenAI key saved securely.")
                        .font(EVAiTypography.caption)
                        .foregroundStyle(Color(hex: 0x34C759))
                }

                HStack(spacing: EVAiSpacing.sm) {
                    GradientButton(title: "Save Key", iconName: "key.fill", isEnabled: !viewModel.openAIKeyInput.isEmpty) {
                        viewModel.saveOpenAIKey()
                    }

                    if viewModel.hasStoredOpenAIKey {
                        OutlineButton(title: "Remove Key") {
                            viewModel.deleteOpenAIKey()
                        }
                    }
                }
            }
            .glassCard()
        }
        .preventScreenshots()
    }

    private var claudeSection: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.md) {
            SectionHeader(title: "Claude API Key")

            Text(CloudExtractionProvider.claude.keyHelpText)
                .font(EVAiTypography.footnote)
                .foregroundStyle(colors.secondaryText)

            VStack(alignment: .leading, spacing: EVAiSpacing.sm) {
                HStack {
                    Text(viewModel.hasStoredClaudeKey ? "Claude key configured" : "No Claude key saved")
                        .font(EVAiTypography.subheadline)
                        .foregroundStyle(viewModel.hasStoredClaudeKey ? Color(hex: 0x34C759) : colors.secondaryText)
                    Spacer()
                    if viewModel.hasStoredClaudeKey {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color(hex: 0x34C759))
                    }
                }

                SecureField(CloudExtractionProvider.claude.keyPlaceholder, text: $viewModel.claudeKeyInput)
                    .font(EVAiTypography.body)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, EVAiSpacing.sm)
                    .padding(.vertical, EVAiSpacing.xs + 2)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(colors.cardBorder.opacity(0.35))
                    }

                if let error = viewModel.claudeKeyError {
                    Text(error)
                        .font(EVAiTypography.caption)
                        .foregroundStyle(Color(hex: 0xFF3B30))
                }

                if viewModel.claudeKeySaved {
                    Text("Claude key saved securely.")
                        .font(EVAiTypography.caption)
                        .foregroundStyle(Color(hex: 0x34C759))
                }

                HStack(spacing: EVAiSpacing.sm) {
                    GradientButton(title: "Save Key", iconName: "key.fill", isEnabled: !viewModel.claudeKeyInput.isEmpty) {
                        viewModel.saveClaudeKey()
                    }

                    if viewModel.hasStoredClaudeKey {
                        OutlineButton(title: "Remove Key") {
                            viewModel.deleteClaudeKey()
                        }
                    }
                }
            }
            .glassCard()
        }
        .preventScreenshots()
    }

    private var confidenceSection: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.md) {
            SectionHeader(title: "Confidence Threshold")

            VStack(alignment: .leading, spacing: EVAiSpacing.sm) {
                HStack {
                    Text("Minimum confidence for auto-accept")
                        .font(EVAiTypography.subheadline)
                        .foregroundStyle(colors.primaryText)
                    Spacer()
                    Text("\(Int((settings?.confidenceThreshold ?? 0.85) * 100))%")
                        .font(EVAiTypography.headline)
                        .foregroundStyle(Color.primaryBlue)
                }

                Slider(
                    value: Binding(
                        get: { settings?.confidenceThreshold ?? 0.85 },
                        set: { viewModel.updateConfidenceThreshold($0) }
                    ),
                    in: 0.5...1.0,
                    step: 0.05
                )
                .tint(Color.primaryBlue)
            }
            .glassCard()
        }
    }

    private var autoReviewSection: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.md) {
            SectionHeader(title: "Auto Review Rules")

            VStack(spacing: EVAiSpacing.sm) {
                settingsToggle(
                    title: "Review Energy Values",
                    isOn: Binding(
                        get: { settings?.autoReviewEnergy ?? true },
                        set: { viewModel.updateAutoReviewEnergy($0) }
                    )
                )
                settingsToggle(
                    title: "Review Amount Values",
                    isOn: Binding(
                        get: { settings?.autoReviewAmount ?? true },
                        set: { viewModel.updateAutoReviewAmount($0) }
                    )
                )
                settingsToggle(
                    title: "Review SOC Values",
                    isOn: Binding(
                        get: { settings?.autoReviewSOCValues ?? true },
                        set: { viewModel.updateAutoReviewSOCValues($0) }
                    )
                )
                settingsToggle(
                    title: "Review Session Duration",
                    isOn: Binding(
                        get: { settings?.autoReviewSessionDuration ?? true },
                        set: { viewModel.updateAutoReviewSessionDuration($0) }
                    )
                )
                settingsToggle(
                    title: "Review Odometer",
                    isOn: Binding(
                        get: { settings?.autoReviewOdometer ?? false },
                        set: { viewModel.updateAutoReviewOdometer($0) }
                    )
                )
            }
        }
    }

    private var fieldSourceSection: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.md) {
            SectionHeader(title: "Field Display")

            settingsToggle(
                title: "Show Field Source",
                isOn: Binding(
                    get: { settings?.showFieldSources ?? true },
                    set: { viewModel.updateShowFieldSources($0) }
                )
            )
        }
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.md) {
            SectionHeader(title: "Extraction Prompt")

            Text("Read-only system prompt used for session extraction.")
                .font(EVAiTypography.footnote)
                .foregroundStyle(colors.secondaryText)

            Text(viewModel.effectiveExtractionPrompt)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(colors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(EVAiSpacing.md)
                .glassCard(padding: 0)

            OutlineButton(title: "Restore Default Prompt") {
                viewModel.restoreDefaultPrompt()
            }
            .disabled(viewModel.isUsingDefaultPrompt)
        }
    }

    private func settingsToggle(title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(EVAiTypography.subheadline)
                .foregroundStyle(colors.primaryText)
        }
        .tint(Color.primaryBlue)
        .padding(EVAiSpacing.md)
        .glassCard(padding: 0)
        .onChange(of: isOn.wrappedValue) { _, _ in
            try? viewModel.save(using: modelContext)
        }
    }

    private func ensureSettingsRecord() {
        guard settingsRecords.isEmpty else { return }
        modelContext.insert(AISettings.defaults())
        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        AISettingsView()
    }
    .modelContainer(for: AISettings.self, inMemory: true)
    .environment(ThemeManager())
    .applyTheme(ThemeManager())
}
