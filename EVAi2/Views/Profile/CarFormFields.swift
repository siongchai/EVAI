import SwiftUI
import PhotosUI
import UIKit

struct CarFormFields: View {
    @Environment(\.themeColors) private var colors
    @Bindable var viewModel: CarManagementViewModel
    @Binding var photoPickerItems: [PhotosPickerItem]
    let onTakePhoto: () -> Void

    private var canUseCamera: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        VStack(spacing: EVAiSpacing.sm) {
            photoSection
            carNameField
            brandPickerSection
            modelPickerSection
            variantPickerSection
            carField("License Plate", text: $viewModel.licensePlateText)
            carField("Battery Size (kWh)", text: $viewModel.batterySizeText, keyboard: .decimalPad)
            carField("Initial Odometer (km)", text: $viewModel.initialOdometerText, keyboard: .numberPad)
            carField("Initial SOC (%)", text: $viewModel.initialSOCText, keyboard: .numberPad)
            collectionDateField
            carField("Purchase Price (SGD)", text: $viewModel.purchasePriceText, keyboard: .decimalPad)

            Toggle("Default Car", isOn: $viewModel.isPrimary)
                .font(EVAiTypography.subheadline)
                .tint(Color.primaryBlue)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(EVAiTypography.caption)
                    .foregroundStyle(Color(hex: 0xFF3B30))
            }
        }
    }

    private var brandPickerSection: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.sm) {
            VStack(alignment: .leading, spacing: EVAiSpacing.xxs) {
                Text("Brand")
                    .font(EVAiTypography.caption)
                    .foregroundStyle(colors.secondaryText)

                Picker("Brand", selection: $viewModel.brandSelection) {
                    Text("Select brand").tag("")
                    ForEach(CarBrandCatalog.pickerOptions(including: viewModel.customBrandText), id: \.self) { brand in
                        Text(brand).tag(brand)
                    }
                }
                .pickerStyle(.menu)
                .font(EVAiTypography.body)
                .padding(.horizontal, EVAiSpacing.sm)
                .padding(.vertical, EVAiSpacing.xs + 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(colors.cardBorder.opacity(0.35))
                }
            }
            .onChange(of: viewModel.brandSelection) { _, _ in
                viewModel.handleBrandChanged()
            }

            if viewModel.brandSelection == CarBrandCatalog.other {
                carField("Custom Brand", text: $viewModel.customBrandText)
            }
        }
        .onChange(of: viewModel.customBrandText) { _, _ in
            viewModel.applySuggestedCarNameIfNeeded()
        }
    }

    private var modelPickerSection: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.sm) {
            if viewModel.showsModelCatalog {
                VStack(alignment: .leading, spacing: EVAiSpacing.xxs) {
                    Text("Model")
                        .font(EVAiTypography.caption)
                        .foregroundStyle(colors.secondaryText)

                    Picker("Model", selection: $viewModel.modelSelection) {
                        Text("Select model").tag("")
                        ForEach(
                            CarModelCatalog.pickerOptions(
                                for: viewModel.brandSelection,
                                including: viewModel.customModelText
                            ),
                            id: \.self
                        ) { model in
                            Text(model).tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(EVAiTypography.body)
                    .padding(.horizontal, EVAiSpacing.sm)
                    .padding(.vertical, EVAiSpacing.xs + 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(colors.cardBorder.opacity(0.35))
                    }
                }

                if viewModel.modelSelection == CarModelCatalog.other {
                    carField("Custom Model", text: $viewModel.customModelText)
                }
            } else {
                carField("Model", text: $viewModel.customModelText)
            }
        }
        .onChange(of: viewModel.modelSelection) { _, _ in
            viewModel.handleModelChanged()
        }
        .onChange(of: viewModel.customModelText) { _, _ in
            viewModel.handleModelChanged()
        }
    }

    private var variantPickerSection: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.sm) {
            if viewModel.showsVariantCatalog {
                VStack(alignment: .leading, spacing: EVAiSpacing.xxs) {
                    Text("Variant")
                        .font(EVAiTypography.caption)
                        .foregroundStyle(colors.secondaryText)

                    Picker("Variant", selection: $viewModel.variantSelection) {
                        Text("Select variant").tag("")
                        ForEach(
                            CarVariantCatalog.pickerOptions(
                                for: viewModel.brandSelection == CarBrandCatalog.other
                                    ? viewModel.customBrandText
                                    : viewModel.brandSelection,
                                model: viewModel.modelSelection == CarModelCatalog.other
                                    ? viewModel.customModelText
                                    : viewModel.modelSelection,
                                including: viewModel.customVariantText
                            ),
                            id: \.self
                        ) { variant in
                            Text(variant).tag(variant)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(EVAiTypography.body)
                    .padding(.horizontal, EVAiSpacing.sm)
                    .padding(.vertical, EVAiSpacing.xs + 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(colors.cardBorder.opacity(0.35))
                    }
                }

                if viewModel.variantSelection == CarVariantCatalog.other {
                    carField("Custom Variant", text: $viewModel.customVariantText)
                }
            } else {
                carField("Variant", text: $viewModel.customVariantText)
            }
        }
    }

    private var collectionDateField: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.xxs) {
            Text("Collection Date")
                .font(EVAiTypography.caption)
                .foregroundStyle(colors.secondaryText)

            DatePicker(
                "Collection Date",
                selection: $viewModel.collectionDate,
                displayedComponents: .date
            )
            .labelsHidden()
            .font(EVAiTypography.body)
            .padding(.horizontal, EVAiSpacing.sm)
            .padding(.vertical, EVAiSpacing.xs + 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(colors.cardBorder.opacity(0.35))
            }
        }
    }

    private var carNameField: some View {
        carField("Car Name", text: $viewModel.carName)
            .onChange(of: viewModel.carName) { _, newValue in
                viewModel.handleCarNameEdited(newValue)
            }
    }

    private var photoSection: some View {
        VStack(spacing: EVAiSpacing.sm) {
            CarAvatarView(image: viewModel.photoPreview, size: 112)

            HStack(spacing: EVAiSpacing.sm) {
                PhotosPicker(
                    selection: $photoPickerItems,
                    maxSelectionCount: 1,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Text(viewModel.photoPreview == nil ? "Upload Photo" : "Change Photo")
                        .font(EVAiTypography.subheadline)
                        .foregroundStyle(Color.primaryBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, EVAiSpacing.sm)
                        .background {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.primaryBlue.opacity(0.35), lineWidth: 1)
                        }
                }
                .photosPickerStyle(.presentation)
                .buttonStyle(.plain)

                if canUseCamera {
                    Button(action: onTakePhoto) {
                        Text("Take Photo")
                            .font(EVAiTypography.subheadline)
                            .foregroundStyle(Color.primaryBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, EVAiSpacing.sm)
                            .background {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.primaryBlue.opacity(0.35), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            if viewModel.photoPreview != nil {
                Button("Remove Photo") {
                    viewModel.removePhoto()
                }
                .font(EVAiTypography.subheadline)
                .foregroundStyle(colors.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, EVAiSpacing.sm)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(colors.cardBorder.opacity(0.25))
                }
                .buttonStyle(.plain)
            }

            Text("Choose from your photo library or take a new photo. Save the car to keep the photo.")
                .font(EVAiTypography.caption)
                .foregroundStyle(colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func carField(_ label: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.xxs) {
            Text(label)
                .font(EVAiTypography.caption)
                .foregroundStyle(colors.secondaryText)

            TextField(label, text: text)
                .font(EVAiTypography.body)
                .keyboardType(keyboard)
                .padding(.horizontal, EVAiSpacing.sm)
                .padding(.vertical, EVAiSpacing.xs + 2)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(colors.cardBorder.opacity(0.35))
                }
        }
    }
}
