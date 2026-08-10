import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class HistoryViewModel {
    var searchText = ""
    var searchScope: SearchScope = .all
    var sortOption: HistorySortOption = .date
    var selectedFilter: HistoryFilterChip = .all
    var advancedFilters = HistoryAdvancedFilters()
    var isShowingAdvancedFilters = false

    private(set) var filteredSessions: [ChargingSession] = []
    private(set) var displayedSessions: [ChargingSession] = []
    private(set) var hasMoreSessions = false
    private(set) var availableFilters: [HistoryFilterChip] = [.all]
    private(set) var availableNetworks: [String] = []
    private(set) var availableCars: [String] = []

    private var allSessions: [ChargingSession] = []
    private var visibleCount = 40
    private let pageSize = 40

    func load(sessions: [ChargingSession]) {
        allSessions = sessions
        visibleCount = pageSize
        rebuildFilters()
        refresh()
    }

    func loadMoreIfNeeded(currentSession: ChargingSession) {
        guard let index = displayedSessions.firstIndex(where: { $0.id == currentSession.id }),
              index >= displayedSessions.count - 8,
              hasMoreSessions else { return }
        visibleCount += pageSize
        updateDisplayedSessions()
    }

    func selectFilter(_ filter: HistoryFilterChip) {
        selectedFilter = filter
        refresh()
    }

    func selectSort(_ option: HistorySortOption) {
        sortOption = option
        refresh()
    }

    func updateSearch(_ text: String) {
        searchText = text
        refresh()
    }

    func updateSearchScope(_ scope: SearchScope) {
        searchScope = scope
        refresh()
    }

    func applyAdvancedFilters(_ filters: HistoryAdvancedFilters) {
        advancedFilters = filters
        refresh()
    }

    func resetAdvancedFilters() {
        advancedFilters.reset()
        refresh()
    }

    private func rebuildFilters() {
        var filters: [HistoryFilterChip] = [.all]

        let months = Set(allSessions.map { $0.startDate.startOfMonth })
            .sorted(by: >)
            .prefix(6)
        filters.append(contentsOf: months.map { .month($0) })

        availableNetworks = Set(allSessions.map(\.chargingNetwork).filter { !$0.isEmpty }).sorted()
        filters.append(contentsOf: availableNetworks.map { .network($0) })

        availableCars = Set(allSessions.map(\.carModel).filter { !$0.isEmpty }).sorted()
        filters.append(contentsOf: availableCars.map { .car($0) })

        availableFilters = filters

        if !availableFilters.contains(selectedFilter) {
            selectedFilter = .all
        }
    }

    private func refresh() {
        var results = HistoryFilterEngine.apply(
            sessions: allSessions,
            chip: selectedFilter,
            advanced: advancedFilters
        )

        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            results = SearchEngine.search(sessions: results, query: searchText, scope: searchScope)
        }

        filteredSessions = sort(sessions: results)
        updateDisplayedSessions()
    }

    private func updateDisplayedSessions() {
        displayedSessions = Array(filteredSessions.prefix(visibleCount))
        hasMoreSessions = filteredSessions.count > displayedSessions.count
    }

    private func sort(sessions: [ChargingSession]) -> [ChargingSession] {
        switch sortOption {
        case .date:
            return sessions.sorted { $0.startDate > $1.startDate }
        case .month:
            return sessions.sorted {
                if $0.startDate.startOfMonth != $1.startDate.startOfMonth {
                    return $0.startDate.startOfMonth > $1.startDate.startOfMonth
                }
                return $0.startDate > $1.startDate
            }
        case .network:
            return sessions.sorted {
                if $0.chargingNetwork != $1.chargingNetwork {
                    return $0.chargingNetwork.localizedCaseInsensitiveCompare($1.chargingNetwork) == .orderedAscending
                }
                return $0.startDate > $1.startDate
            }
        case .car:
            return sessions.sorted {
                if $0.carModel != $1.carModel {
                    return $0.carModel.localizedCaseInsensitiveCompare($1.carModel) == .orderedAscending
                }
                return $0.startDate > $1.startDate
            }
        }
    }
}
