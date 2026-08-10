import SwiftUI
import SwiftData

struct ReviewConfirmView: View {
    @Environment(\.themeColors) private var colors
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsRecords: [AISettings]
    @Query(sort: \Car.createdAt, order: .reverse) private var cars: [Car]
    @Bindable var viewModel: CaptureViewModel

    @State private var saveError: String?
    @State private var showSaveError = false

    @State private var debugExpanded = false

    private var showFieldSources: Bool {
        settingsRecords.first?.showFieldSources ?? viewModel.showFieldSources
    }

    private var computedMetrics: SessionComputedMetrics {
        SessionCalculator.compute(
            from: viewModel.sessionDraft,
            batterySizeKWh: cars.first(where: \.isPrimary)?.batterySizeKWh
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EVAiSpacing.sectionSpacing) {
                header

                if !viewModel.validationMessages.isEmpty {
                    validationBanner
                }

                locationSection
                timingSection
                carSection
                energySection
                SessionComputedMetricsCard(metrics: computedMetrics)
                confidenceSection
                extractionDebugSection
            }
            .padding(.horizontal, EVAiSpacing.horizontalPadding)
            .padding(.bottom, EVAiSpacing.lg)
        }
        .scrollIndicators(.hidden)
        .preventScreenshots()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionButtons
                .padding(.horizontal, EVAiSpacing.horizontalPadding)
                .padding(.top, EVAiSpacing.sm)
                .padding(.bottom, EVAiSpacing.tabBarHeight)
                .background {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .background(colors.tabBarBackground.opacity(0.95))
                }
        }
        .onAppear {
            viewModel.showFieldSources = settingsRecords.first?.showFieldSources ?? true
            applyDefaultCarModel()
            applyAutoCalculations()
        }
        .onChange(of: viewModel.sessionDraft.startDate) { _, _ in applyAutoCalculations() }
        .onChange(of: viewModel.sessionDraft.endDate) { _, _ in applyAutoCalculations() }
        .onChange(of: viewModel.sessionDraft.sessionDurationMinutes) { _, _ in applyAutoCalculations() }
        .onChange(of: viewModel.sessionDraft.idleDurationMinutes) { _, _ in applyAutoCalculations() }
        .onChange(of: viewModel.sessionDraft.energyKWh) { _, _ in applyAutoCalculations() }
        .onChange(of: viewModel.sessionDraft.amountSGD) { _, _ in applyAutoCalculations() }
        .alert("Save Error", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "Unable to save session.")
        }
    }

    private var chargingDurationDisplay: String {
        viewModel.sessionDraft.chargingDurationMinutes.minutesDurationFormatted
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.xs) {
            Text("Review & Confirm")
                .font(EVAiTypography.title2)
                .foregroundStyle(colors.primaryText)

            Text("Review and edit any extracted fields before saving.")
                .font(EVAiTypography.subheadline)
                .foregroundStyle(colors.secondaryText)

            if !viewModel.extractionEngineName.isEmpty {
                Text("Extracted using \(viewModel.extractionEngineName)")
                    .font(EVAiTypography.caption)
                    .foregroundStyle(Color.primaryBlue)
            }
        }
        .padding(.top, EVAiSpacing.sm)
    }

    private var validationBanner: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.xs) {
            ForEach(viewModel.validationMessages, id: \.self) { message in
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(EVAiTypography.footnote)
                    .foregroundStyle(Color(hex: 0xFF9500))
            }
        }
        .padding(EVAiSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: EVAiSpacing.buttonRadius, style: .continuous)
                .fill(Color(hex: 0xFF9500).opacity(0.10))
        }
    }

    private var locationSection: some View {
        ReviewSection(title: "Location & Charger") {
            ReviewFieldRow(
                label: "Location",
                text: viewModel.binding(\.chargingLocation),
                field: .chargingLocation,
                viewModel: viewModel,
                showFieldSources: showFieldSources
            )
            ReviewFieldRow(
                label: "Charger ID",
                text: viewModel.binding(\.chargerId),
                field: .chargerId,
                viewModel: viewModel,
                showFieldSources: showFieldSources
            )
            ReviewFieldRow(
                label: "Network",
                text: viewModel.binding(\.chargingNetwork),
                field: .chargingNetwork,
                viewModel: viewModel,
                showFieldSources: showFieldSources
            )
            ReviewLabeledRow(
                label: "Charger Type",
                field: .chargerType,
                viewModel: viewModel,
                showFieldSources: showFieldSources
            ) {
                SessionChargerTypePicker(
                    label: "Charger Type",
                    chargerType: viewModel.binding(\.chargerType),
                    chargerPowerKW: viewModel.binding(\.chargerPowerKW),
                    showsLabel: false,
                    isUncertain: viewModel.isFieldUncertain(.chargerType)
                )
            }
            ReviewLabeledRow(
                label: "Power (kW)",
                field: .chargerPowerKW,
                viewModel: viewModel,
                showFieldSources: showFieldSources
            ) {
                SessionChargerPowerPicker(
                    label: "Power (kW)",
                    chargerType: viewModel.binding(\.chargerType),
                    chargerPowerKW: viewModel.binding(\.chargerPowerKW),
                    showsLabel: false,
                    isUncertain: viewModel.isFieldUncertain(.chargerPowerKW)
                )
            }
        }
    }

    private var timingSection: some View {
        ReviewSection(title: "Session Timing") {
            ReviewLabeledRow(label: "Start", field: .startDate, viewModel: viewModel, showFieldSources: showFieldSources) {
                DatePicker("Start", selection: viewModel.binding(\.startDate))
                    .font(EVAiTypography.subheadline)
            }

            ReviewLabeledRow(label: "End", field: .endDate, viewModel: viewModel, showFieldSources: showFieldSources) {
                DatePicker("End", selection: viewModel.binding(\.endDate))
                    .font(EVAiTypography.subheadline)
            }

            ReviewFieldRow(
                label: "Total Session",
                text: viewModel.binding(\.sessionDurationMinutes),
                field: .sessionDuration,
                viewModel: viewModel,
                showFieldSources: showFieldSources,
                keyboard: .numbersAndPunctuation,
                placeholder: "e.g. 113 or 1h 53m"
            )
            ReviewFieldRow(
                label: "Idle",
                text: viewModel.binding(\.idleDurationMinutes),
                field: .idleDuration,
                viewModel: viewModel,
                showFieldSources: showFieldSources,
                keyboard: .numbersAndPunctuation,
                placeholder: "e.g. 15 or 15m"
            )
            ReviewLabeledRow(
                label: "Active Charging",
                field: .sessionDuration,
                viewModel: viewModel,
                showFieldSources: false
            ) {
                Text(chargingDurationDisplay)
                    .font(EVAiTypography.body)
                    .foregroundStyle(colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var carSection: some View {
        ReviewSection(title: "Car Information") {
            ReviewFieldRow(
                label: "Car Model",
                text: viewModel.binding(\.carModel),
                field: .carModel,
                viewModel: viewModel,
                showFieldSources: showFieldSources
            )

            HStack(alignment: .top, spacing: EVAiSpacing.sm) {
                ReviewFieldRow(
                    label: "Start SOC %",
                    text: viewModel.binding(\.startSOCPercent),
                    field: .startSOCPercent,
                    viewModel: viewModel,
                    showFieldSources: showFieldSources,
                    keyboard: .numberPad
                )
                ReviewFieldRow(
                    label: "End SOC %",
                    text: viewModel.binding(\.endSOCPercent),
                    field: .endSOCPercent,
                    viewModel: viewModel,
                    showFieldSources: showFieldSources,
                    keyboard: .numberPad
                )
            }

            ReviewFieldRow(
                label: "Odometer (km)",
                text: viewModel.binding(\.odometerKM),
                field: .odometerKM,
                viewModel: viewModel,
                showFieldSources: showFieldSources,
                keyboard: .numberPad
            )
        }
    }

    private var energySection: some View {
        ReviewSection(title: "Energy & Cost") {
            HStack(alignment: .top, spacing: EVAiSpacing.sm) {
                ReviewFieldRow(
                    label: "Energy (kWh)",
                    text: viewModel.binding(\.energyKWh),
                    field: .energyKWh,
                    viewModel: viewModel,
                    showFieldSources: showFieldSources,
                    keyboard: .decimalPad
                )
                ReviewFieldRow(
                    label: "Amount (SGD)",
                    text: viewModel.binding(\.amountSGD),
                    field: .amountSGD,
                    viewModel: viewModel,
                    showFieldSources: showFieldSources,
                    keyboard: .decimalPad
                )
            }
        }
    }

    private var extractionDebugSection: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.xs) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { debugExpanded.toggle() }
            } label: {
                HStack {
                    Text("Extraction Details")
                        .font(EVAiTypography.caption)
                        .foregroundStyle(colors.secondaryText)
                    Spacer()
                    Image(systemName: debugExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(colors.secondaryText)
                }
            }
            .buttonStyle(.plain)

            if debugExpanded {
                VStack(alignment: .leading, spacing: EVAiSpacing.sm) {
                    if !viewModel.extractionWarnings.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Fusion notes")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(colors.secondaryText)
                            ForEach(viewModel.extractionWarnings, id: \.self) { note in
                                Text("• \(note)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(colors.secondaryText)
                            }
                        }
                    }

                    if !viewModel.rawAIResponse.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Raw AI response")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(colors.secondaryText)
                            ScrollView(.horizontal, showsIndicators: false) {
                                Text(viewModel.rawAIResponse.prefix(1200))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(colors.secondaryText)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
                .padding(EVAiSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(colors.cardBorder.opacity(0.18))
                }
            }
        }
    }

    private var confidenceSection: some View {
        ReviewSection(title: "AI Confidence") {
            HStack {
                VStack(alignment: .leading, spacing: EVAiSpacing.xxs) {
                    Text("\(Int(viewModel.sessionDraft.extractionConfidence * 100))%")
                        .font(EVAiTypography.title2)
                        .foregroundStyle(colors.primaryText)

                    Text(viewModel.confidenceLabel)
                        .font(EVAiTypography.caption)
                        .foregroundStyle(Color.primaryBlue)
                }

                Spacer()

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.primaryBlue)
                    .symbolRenderingMode(.hierarchical)
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: EVAiSpacing.sm) {
            HStack(spacing: EVAiSpacing.sm) {
                OutlineButton(title: "View Sources") {
                    viewModel.showSourceImages()
                }

                OutlineButton(title: "Retake Images") {
                    viewModel.retakeImages()
                }
            }

            GradientButton(title: "Save Session", iconName: "checkmark") {
                saveSession()
            }
        }
    }

    private func saveSession() {
        SessionCalculator.applyAutoCalculations(
            to: &viewModel.sessionDraft,
            batterySizeKWh: cars.first(where: \.isPrimary)?.batterySizeKWh
        )
        do {
            try viewModel.saveSession(using: modelContext)
        } catch {
            saveError = error.localizedDescription
            showSaveError = true
        }
    }

    private func applyDefaultCarModel() {
        guard viewModel.sessionDraft.carModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let defaultName = cars.first(where: \.isPrimary)?.displayName.nilIfEmpty else {
            return
        }
        viewModel.sessionDraft.carModel = defaultName
    }

    private func applyAutoCalculations() {
        SessionCalculator.applyAutoCalculations(
            to: &viewModel.sessionDraft,
            batterySizeKWh: cars.first(where: \.isPrimary)?.batterySizeKWh
        )
    }
}

private struct ReviewSection<Content: View>: View {
    @Environment(\.themeColors) private var colors

    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.md) {
            Text(title)
                .font(EVAiTypography.title3)
                .foregroundStyle(colors.primaryText)

            VStack(spacing: EVAiSpacing.md) {
                content()
            }
            .padding(EVAiSpacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(padding: 0)
        }
    }
}

private struct ReviewFieldRow: View {
    @Environment(\.themeColors) private var colors

    let label: String
    @Binding var text: String
    let field: ExtractionFieldKey
    var viewModel: CaptureViewModel
    var showFieldSources: Bool
    var keyboard: UIKeyboardType = .default
    var placeholder: String = ""

    private var metadata: ExtractionFieldMetadata? {
        viewModel.metadata(for: field)
    }

    private var isUncertain: Bool {
        viewModel.isFieldUncertain(field)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.xxs) {
            HStack(spacing: EVAiSpacing.xs) {
                Text(label)
                    .font(EVAiTypography.caption)
                    .foregroundStyle(colors.secondaryText)

                Spacer()

                if let metadata, metadata.confidence > 0 {
                    ConfidenceBadge(confidence: metadata.confidence)
                }
            }

            TextField(placeholder.isEmpty ? label : placeholder, text: $text)
                .font(EVAiTypography.body)
                .foregroundStyle(colors.primaryText)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(keyboard != .default)
                .padding(.horizontal, EVAiSpacing.sm)
                .padding(.vertical, EVAiSpacing.xs + 2)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isUncertain ? Color(hex: 0xFF9500).opacity(0.12) : colors.cardBorder.opacity(0.35))
                        .overlay {
                            if isUncertain {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color(hex: 0xFF9500).opacity(0.45), lineWidth: 1)
                            }
                        }
                }

            if showFieldSources, let source = metadata?.sourceCategory {
                Text("Source: \(source.title)")
                    .font(EVAiTypography.caption2)
                    .foregroundStyle(colors.secondaryText)
            }
        }
    }
}

private struct ReviewLabeledRow<Content: View>: View {
    @Environment(\.themeColors) private var colors

    let label: String
    let field: ExtractionFieldKey
    var viewModel: CaptureViewModel
    var showFieldSources: Bool
    @ViewBuilder var content: () -> Content

    private var metadata: ExtractionFieldMetadata? {
        viewModel.metadata(for: field)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.xxs) {
            HStack {
                Text(label)
                    .font(EVAiTypography.caption)
                    .foregroundStyle(colors.secondaryText)
                Spacer()
                if let metadata, metadata.confidence > 0 {
                    ConfidenceBadge(confidence: metadata.confidence)
                }
            }
            content()
            if showFieldSources, let source = metadata?.sourceCategory {
                Text("Source: \(source.title)")
                    .font(EVAiTypography.caption2)
                    .foregroundStyle(colors.secondaryText)
            }
        }
        .padding(.vertical, EVAiSpacing.xxs)
        .padding(.horizontal, EVAiSpacing.sm)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(viewModel.isFieldUncertain(field) ? Color(hex: 0xFF9500).opacity(0.10) : colors.cardBorder.opacity(0.20))
        }
    }
}

private struct ConfidenceBadge: View {
    let confidence: Double

    private var color: Color {
        if confidence >= 0.9 { return Color(hex: 0x34C759) }
        if confidence >= 0.75 { return Color.primaryBlue }
        return Color(hex: 0xFF9500)
    }

    var body: some View {
        Text("\(Int(confidence * 100))%")
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }
}

#Preview {
    ReviewConfirmView(viewModel: CaptureViewModel())
        .modelContainer(for: [ChargingSession.self, AISettings.self], inMemory: true)
        .environment(ThemeManager())
        .applyTheme(ThemeManager())
}
