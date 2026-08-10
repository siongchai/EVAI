import SwiftUI

struct HistoryAdvancedFiltersSheet: View {
    @Environment(\.themeColors) private var colors
    @Environment(\.dismiss) private var dismiss

    @Binding var filters: HistoryAdvancedFilters
    let availableNetworks: [String]
    let availableCars: [String]
    let onApply: () -> Void

    @State private var minCostText = ""
    @State private var maxCostText = ""
    @State private var minEnergyText = ""
    @State private var maxEnergyText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Date Range") {
                    DatePicker("From", selection: bindingDate($filters.startDate), displayedComponents: .date)
                    DatePicker("To", selection: bindingDate($filters.endDate), displayedComponents: .date)
                }

                Section("Network") {
                    if availableNetworks.isEmpty {
                        Text("No networks available")
                    } else {
                        ForEach(availableNetworks, id: \.self) { network in
                            Toggle(network, isOn: bindingSet($filters.selectedNetworks, value: network))
                        }
                    }
                }

                Section("Car") {
                    if availableCars.isEmpty {
                        Text("No cars available")
                    } else {
                        ForEach(availableCars, id: \.self) { car in
                            Toggle(car, isOn: bindingSet($filters.selectedCars, value: car))
                        }
                    }
                }

                Section("Cost Range (SGD)") {
                    TextField("Minimum", text: $minCostText)
                        .keyboardType(.decimalPad)
                    TextField("Maximum", text: $maxCostText)
                        .keyboardType(.decimalPad)
                }

                Section("Energy Range (kWh)") {
                    TextField("Minimum", text: $minEnergyText)
                        .keyboardType(.decimalPad)
                    TextField("Maximum", text: $maxEnergyText)
                        .keyboardType(.decimalPad)
                }

                Section("Location") {
                    TextField("Search location", text: $filters.locationQuery)
                }
            }
            .navigationTitle("Advanced Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        filters.reset()
                        minCostText = ""
                        maxCostText = ""
                        minEnergyText = ""
                        maxEnergyText = ""
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        filters.minCost = Double(minCostText)
                        filters.maxCost = Double(maxCostText)
                        filters.minEnergy = Double(minEnergyText)
                        filters.maxEnergy = Double(maxEnergyText)
                        onApply()
                        dismiss()
                    }
                }
            }
            .onAppear {
                minCostText = filters.minCost.map { String(format: "%.2f", $0) } ?? ""
                maxCostText = filters.maxCost.map { String(format: "%.2f", $0) } ?? ""
                minEnergyText = filters.minEnergy.map { String(format: "%.1f", $0) } ?? ""
                maxEnergyText = filters.maxEnergy.map { String(format: "%.1f", $0) } ?? ""
            }
        }
    }

    private func bindingDate(_ date: Binding<Date?>) -> Binding<Date> {
        Binding(
            get: { date.wrappedValue ?? .now },
            set: { date.wrappedValue = $0 }
        )
    }

    private func bindingSet(_ set: Binding<Set<String>>, value: String) -> Binding<Bool> {
        Binding(
            get: { set.wrappedValue.contains(value) },
            set: { isOn in
                if isOn {
                    set.wrappedValue.insert(value)
                } else {
                    set.wrappedValue.remove(value)
                }
            }
        )
    }
}
