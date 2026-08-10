import WidgetKit
import SwiftUI

struct EVAiMonthlyWidget: Widget {
    let kind = "EVAiMonthlyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EVAiWidgetProvider()) { entry in
            EVAiMonthlyWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Monthly Summary")
        .description("Monthly cost and energy usage.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct EVAiLastSessionWidget: Widget {
    let kind = "EVAiLastSessionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EVAiWidgetProvider()) { entry in
            EVAiLastSessionWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Last Session")
        .description("Your most recent charging session.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct EVAiWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct EVAiWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> EVAiWidgetEntry {
        EVAiWidgetEntry(date: .now, snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (EVAiWidgetEntry) -> Void) {
        completion(EVAiWidgetEntry(date: .now, snapshot: WidgetSnapshotReader.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EVAiWidgetEntry>) -> Void) {
        let entry = EVAiWidgetEntry(date: .now, snapshot: WidgetSnapshotReader.load())
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct EVAiMonthlyWidgetView: View {
    let entry: EVAiWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bolt.car.fill")
                    .foregroundStyle(.blue)
                Text("EVAi")
                    .font(.headline)
            }

            Text("Monthly Cost")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(entry.snapshot.monthlyCost, format: .currency(code: "SGD"))
                .font(.title2.bold())

            Text("Energy: \(entry.snapshot.monthlyEnergy, format: .number.precision(.fractionLength(0))) kWh")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct EVAiLastSessionWidgetView: View {
    let entry: EVAiWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last Session")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(entry.snapshot.lastSessionLocation)
                .font(.subheadline.bold())
                .lineLimit(2)

            HStack {
                Text(entry.snapshot.lastSessionCost, format: .currency(code: "SGD"))
                Text("·")
                Text("\(entry.snapshot.lastSessionEnergy, format: .number.precision(.fractionLength(1))) kWh")
            }
            .font(.caption)

            Text(entry.snapshot.lastSessionDate, style: .date)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

@main
struct EVAiWidgetBundle: WidgetBundle {
    var body: some Widget {
        EVAiMonthlyWidget()
        EVAiLastSessionWidget()
    }
}
