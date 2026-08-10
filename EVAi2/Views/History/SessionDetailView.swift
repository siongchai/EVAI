import SwiftUI
import SwiftData

struct SessionDetailView: View {
    @Environment(\.themeColors) private var colors
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Car.createdAt, order: .reverse) private var cars: [Car]

    @Bindable var session: ChargingSession
    var showsNavigationChrome: Bool = true
    var onDelete: (() -> Void)?

    @State private var isEditing = false
    @State private var draft = EditableSessionDraft()
    @State private var showDeleteConfirmation = false
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""

    private var computedMetrics: SessionComputedMetrics {
        SessionCalculator.compute(
            from: draft,
            batterySizeKWh: cars.first(where: \.isPrimary)?.batterySizeKWh
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EVAiSpacing.sectionSpacing) {
                summaryHeader
                confidenceSection
                locationSection
                timingSection
                carSection
                energySection
                if isEditing {
                    SessionComputedMetricsCard(metrics: computedMetrics)
                }
                sourceImagesSection
                metadataSection
                actionSection
            }
            .padding(.horizontal, EVAiSpacing.horizontalPadding)
            .padding(.bottom, EVAiSpacing.xxxl)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(showsNavigationChrome ? "Session Detail" : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsNavigationChrome {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Done" : "Edit") {
                        toggleEditing()
                    }
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Done" : "Edit") {
                        toggleEditing()
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete this charging session?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Session", role: .destructive) {
                deleteSession()
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Save Error", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage)
        }
        .onAppear {
            draft = EditableSessionDraft(from: session)
        }
        .onChange(of: draft.startDate) { _, _ in applyAutoCalculations() }
        .onChange(of: draft.endDate) { _, _ in applyAutoCalculations() }
        .onChange(of: draft.sessionDurationMinutes) { _, _ in applyAutoCalculations() }
        .onChange(of: draft.idleDurationMinutes) { _, _ in applyAutoCalculations() }
        .onChange(of: draft.energyKWh) { _, _ in applyAutoCalculations() }
        .onChange(of: draft.amountSGD) { _, _ in applyAutoCalculations() }
    }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.sm) {
            HStack(spacing: EVAiSpacing.md) {
                NetworkBadge(network: session.chargingNetwork, initials: session.networkInitials)

                VStack(alignment: .leading, spacing: EVAiSpacing.xxs) {
                    Text(isEditing ? draft.chargingLocation : session.chargingLocation)
                        .font(EVAiTypography.title2)
                        .foregroundStyle(colors.primaryText)
                        .lineLimit(2)

                    Text("\(session.startDate.dayMonthYearDisplay) · \(session.startDate.timeDisplay)")
                        .font(EVAiTypography.subheadline)
                        .foregroundStyle(colors.secondaryText)
                }
            }

            HStack(spacing: EVAiSpacing.md) {
                summaryMetric(title: "Cost", value: session.amountSGD.currencyFormatted)
                summaryMetric(title: "Energy", value: session.energyKWh.energyFormatted)
                summaryMetric(title: "$/kWh", value: session.costPerKWh.costPerKWhFormatted)
            }
        }
        .padding(.top, EVAiSpacing.sm)
    }

    private func summaryMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.xxs) {
            Text(title)
                .font(EVAiTypography.caption)
                .foregroundStyle(colors.secondaryText)
            Text(value)
                .font(EVAiTypography.headline)
                .foregroundStyle(colors.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: EVAiSpacing.sm)
    }

    private var confidenceSection: some View {
        SessionFormSection(title: "Confidence Score") {
            HStack {
                VStack(alignment: .leading, spacing: EVAiSpacing.xxs) {
                    Text("\(Int(session.extractionConfidence * 100))%")
                        .font(EVAiTypography.title2)
                        .foregroundStyle(colors.primaryText)

                    Text(confidenceLabel)
                        .font(EVAiTypography.caption)
                        .foregroundStyle(Color.primaryBlue)
                }

                Spacer()

                Image(systemName: session.extractionConfidence >= 0.85 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(session.extractionConfidence >= 0.85 ? Color.primaryBlue : Color(hex: 0xFF9500))
                    .symbolRenderingMode(.hierarchical)
            }
        }
    }

    private var confidenceLabel: String {
        if session.extractionConfidence >= 0.9 { return "High Confidence" }
        if session.extractionConfidence >= 0.75 { return "Medium Confidence" }
        return "Review Recommended"
    }

    private var locationSection: some View {
        SessionFormSection(title: "Location & Charger") {
            if isEditing {
                SessionFormField(label: "Location", text: $draft.chargingLocation)
                SessionFormField(label: "Charger ID", text: $draft.chargerId)
                SessionFormField(label: "Network", text: $draft.chargingNetwork)
                SessionChargerTypePicker(
                    label: "Charger Type",
                    chargerType: $draft.chargerType,
                    chargerPowerKW: $draft.chargerPowerKW
                )
                SessionChargerPowerPicker(
                    label: "Power (kW)",
                    chargerType: $draft.chargerType,
                    chargerPowerKW: $draft.chargerPowerKW
                )
            } else {
                SessionDetailRow(label: "Location", value: session.chargingLocation)
                SessionDetailRow(label: "Charger ID", value: session.chargerId)
                SessionDetailRow(label: "Network", value: session.chargingNetwork)
                SessionDetailRow(label: "Charger Type", value: ChargerTypeOption.displayLabel(for: session.chargerType))
                SessionDetailRow(
                    label: "Power",
                    value: ChargerPowerCatalog.displayLabel(
                        kilowatts: session.chargerPowerKW,
                        chargerType: session.chargerType
                    )
                )
            }
        }
    }

    private var timingSection: some View {
        SessionFormSection(title: "Session Timing") {
            if isEditing {
                DatePicker("Start", selection: $draft.startDate)
                DatePicker("End", selection: $draft.endDate)
                SessionFormField(
                    label: "Total Session",
                    text: $draft.sessionDurationMinutes,
                    keyboard: .numbersAndPunctuation
                )
                SessionFormField(
                    label: "Idle",
                    text: $draft.idleDurationMinutes,
                    keyboard: .numbersAndPunctuation
                )
                SessionDetailRow(
                    label: "Active Charging",
                    value: draft.chargingDurationMinutes.minutesDurationFormatted
                )
            } else {
                SessionDetailRow(label: "Start", value: "\(session.startDate.dayMonthYearDisplay) \(session.startDate.timeDisplay)")
                SessionDetailRow(label: "End", value: "\(session.endDate.dayMonthYearDisplay) \(session.endDate.timeDisplay)")
                SessionDetailRow(label: "Charging Duration", value: session.chargingDurationSeconds.durationFormatted)
                SessionDetailRow(label: "Idle", value: session.idleDuration.durationFormatted)
            }
        }
    }

    private var carSection: some View {
        SessionFormSection(title: "Car") {
            if isEditing {
                SessionFormField(label: "Car Model", text: $draft.carModel)
                SessionFormField(label: "Start SOC %", text: $draft.startSOCPercent, keyboard: .numberPad)
                SessionFormField(label: "End SOC %", text: $draft.endSOCPercent, keyboard: .numberPad)
                SessionFormField(label: "Odometer (km)", text: $draft.odometerKM, keyboard: .numberPad)
            } else {
                SessionDetailRow(label: "Model", value: session.carModel)
                SessionDetailRow(label: "Start SOC", value: session.startSOCPercent.percentFormatted)
                SessionDetailRow(label: "End SOC", value: session.endSOCPercent.percentFormatted)
                SessionDetailRow(label: "SOC Gain", value: (session.endSOCPercent - session.startSOCPercent).percentFormatted)
                SessionDetailRow(label: "Odometer", value: session.odometerKM > 0 ? String(format: "%.0f km", session.odometerKM) : "—")
            }
        }
    }

    private var energySection: some View {
        SessionFormSection(title: "Energy & Cost") {
            if isEditing {
                SessionFormField(label: "Energy (kWh)", text: $draft.energyKWh, keyboard: .decimalPad)
                SessionFormField(label: "Amount (SGD)", text: $draft.amountSGD, keyboard: .decimalPad)
            } else {
                SessionDetailRow(label: "Energy", value: session.energyKWh.energyFormatted)
                SessionDetailRow(label: "Amount", value: session.amountSGD.currencyFormatted)
                SessionDetailRow(label: "Cost / kWh", value: session.costPerKWh.costPerKWhFormatted)
            }
        }
    }

    private var sourceImagesSection: some View {
        SessionFormSection(title: "Source Images") {
            if session.sourceImageIDList.isEmpty {
                Text("No source images stored for this session.")
                    .font(EVAiTypography.subheadline)
                    .foregroundStyle(colors.secondaryText)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: EVAiSpacing.sm) {
                        ForEach(session.sourceImageIDList, id: \.self) { imageID in
                            if let thumbnail = ImageCacheService.shared.thumbnail(for: imageID)
                                ?? ImageStorageManager.loadThumbnail(id: imageID) {
                                Image(uiImage: thumbnail)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 88, height: 88)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .accessibilityLabel("Stored charging session image")
                            }
                        }
                    }
                }
            }

            if !session.rawAIResponse.isEmpty {
                Text("Raw extraction response")
                    .font(EVAiTypography.caption)
                    .foregroundStyle(colors.secondaryText)

                Text(session.decryptedRawAIResponse)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(colors.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(EVAiSpacing.sm)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(colors.cardBorder.opacity(0.25))
                    }
            }
        }
        .preventScreenshots()
    }

    private var metadataSection: some View {
        SessionFormSection(title: "Metadata") {
            SessionDetailRow(label: "Session ID", value: session.id.uuidString)
            SessionDetailRow(label: "Created", value: session.createdAt.dayMonthYearDisplay)
            SessionDetailRow(label: "Updated", value: session.updatedAt.dayMonthYearDisplay)
        }
    }

    private var actionSection: some View {
        VStack(spacing: EVAiSpacing.sm) {
            if isEditing {
                GradientButton(title: "Save Changes", iconName: "checkmark") {
                    saveChanges()
                }
            }

            OutlineButton(title: "Delete Session") {
                showDeleteConfirmation = true
            }
        }
    }

    private func toggleEditing() {
        if isEditing {
            saveChanges()
        } else {
            draft = EditableSessionDraft(from: session)
            isEditing = true
        }
    }

    private func saveChanges() {
        guard !draft.chargingLocation.trimmingCharacters(in: .whitespaces).isEmpty else {
            saveErrorMessage = "Charging location is required."
            showSaveError = true
            return
        }

        SessionCalculator.applyAutoCalculations(
            to: &draft,
            batterySizeKWh: cars.first(where: \.isPrimary)?.batterySizeKWh
        )
        draft.apply(to: session)

        do {
            try modelContext.save()
            isEditing = false
        } catch {
            saveErrorMessage = error.localizedDescription
            showSaveError = true
        }
    }

    private func deleteSession() {
        modelContext.delete(session)
        try? modelContext.save()
        onDelete?()
        dismiss()
    }

    private func applyAutoCalculations() {
        guard isEditing else { return }
        SessionCalculator.applyAutoCalculations(
            to: &draft,
            batterySizeKWh: cars.first(where: \.isPrimary)?.batterySizeKWh
        )
    }
}

#Preview {
    NavigationStack {
        SessionDetailView(
            session: ChargingSession(
                chargingLocation: "Marina Bay Sands",
                chargerId: "SP-001",
                chargingNetwork: "SP Group",
                chargerType: "DC Fast",
                chargerPowerKW: 120,
                startDate: .now,
                endDate: .now,
                startSOCPercent: 20,
                endSOCPercent: 80,
                odometerKM: 12000,
                energyKWh: 42,
                amountSGD: 18.5,
                sessionDuration: 3600,
                idleDuration: 300,
                carModel: "Tesla Model 3",
                extractionConfidence: 0.92
            )
        )
    }
    .modelContainer(for: ChargingSession.self, inMemory: true)
    .environment(ThemeManager())
    .applyTheme(ThemeManager())
}
