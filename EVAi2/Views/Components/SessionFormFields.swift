import SwiftUI

struct SessionFormSection<Content: View>: View {
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

struct SessionFormField: View {
    @Environment(\.themeColors) private var colors

    let label: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var isEditable: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.xxs) {
            Text(label)
                .font(EVAiTypography.caption)
                .foregroundStyle(colors.secondaryText)

            if isEditable {
                TextField(label, text: $text)
                    .font(EVAiTypography.body)
                    .foregroundStyle(colors.primaryText)
                    .keyboardType(keyboard)
                    .padding(.horizontal, EVAiSpacing.sm)
                    .padding(.vertical, EVAiSpacing.xs + 2)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(colors.cardBorder.opacity(0.35))
                    }
            } else {
                Text(text.isEmpty ? "—" : text)
                    .font(EVAiTypography.body)
                    .foregroundStyle(colors.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct SessionChargerTypePicker: View {
    @Environment(\.themeColors) private var colors

    let label: String
    @Binding var chargerType: String
    var chargerPowerKW: Binding<String>? = nil
    var showsLabel: Bool = true
    var isUncertain: Bool = false

    private var selection: Binding<ChargerTypeOption> {
        Binding(
            get: { ChargerTypeOption.from(storedValue: chargerType) },
            set: { newType in
                chargerType = newType.rawValue
                if let chargerPowerKW {
                    chargerPowerKW.wrappedValue = ChargerPowerCatalog.normalizedPowerString(
                        current: chargerPowerKW.wrappedValue,
                        chargerType: newType.rawValue
                    )
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.xxs) {
            if showsLabel {
                Text(label)
                    .font(EVAiTypography.caption)
                    .foregroundStyle(colors.secondaryText)
            }

            Picker(label, selection: selection) {
                ForEach(ChargerTypeOption.editableOptions) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu)
            .font(EVAiTypography.body)
            .foregroundStyle(colors.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        }
    }
}

struct SessionChargerPowerPicker: View {
    @Environment(\.themeColors) private var colors

    let label: String
    @Binding var chargerType: String
    @Binding var chargerPowerKW: String
    var showsLabel: Bool = true
    var isUncertain: Bool = false

    private var typeOption: ChargerTypeOption {
        ChargerTypeOption.from(storedValue: chargerType)
    }

    private var powerSelection: Binding<Double> {
        Binding(
            get: {
                let current = Double(chargerPowerKW.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                if current > 0, ChargerPowerCatalog.isValid(current, for: typeOption) {
                    return current
                }
                return ChargerPowerCatalog.defaultPower(for: typeOption) ?? 0
            },
            set: { chargerPowerKW = ChargerPowerCatalog.format($0) }
        )
    }

    var body: some View {
        if typeOption == .others {
            SessionFormField(
                label: label,
                text: $chargerPowerKW,
                keyboard: .decimalPad
            )
        } else {
            VStack(alignment: .leading, spacing: EVAiSpacing.xxs) {
                if showsLabel {
                    Text(label)
                        .font(EVAiTypography.caption)
                        .foregroundStyle(colors.secondaryText)
                }

                Picker(label, selection: powerSelection) {
                    if typeOption == .acCharger {
                        ForEach(ChargerPowerCatalog.acPowers, id: \.self) { kilowatts in
                            Text(ChargerPowerCatalog.powerLabel(kilowatts)).tag(kilowatts)
                        }
                    } else {
                        Section("Standard DC (50–100 kW)") {
                            ForEach(ChargerPowerCatalog.dcStandardPowers, id: \.self) { kilowatts in
                                Text(ChargerPowerCatalog.powerLabel(kilowatts)).tag(kilowatts)
                            }
                        }
                        Section("Ultra-Fast DC (120–350 kW)") {
                            ForEach(ChargerPowerCatalog.dcUltraFastPowers, id: \.self) { kilowatts in
                                Text(ChargerPowerCatalog.powerLabel(kilowatts)).tag(kilowatts)
                            }
                        }
                    }
                }
                .pickerStyle(.menu)
                .font(EVAiTypography.body)
                .foregroundStyle(colors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
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
            }
        }
    }
}

struct SessionDetailRow: View {
    @Environment(\.themeColors) private var colors

    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(EVAiTypography.caption)
                .foregroundStyle(colors.secondaryText)
                .frame(width: 120, alignment: .leading)

            Text(value)
                .font(EVAiTypography.subheadline)
                .foregroundStyle(colors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
