import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.themeColors) private var colors
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChargingSession.startDate, order: .reverse) private var sessions: [ChargingSession]

    @State private var viewModel = HistoryViewModel()
    @State private var selectedSessionID: UUID?
    @State private var navigationSessionID: UUID?
    @State private var isSelectionMode = false
    @State private var selectedSessionIDs: Set<UUID> = []
    @State private var showBulkDeleteConfirmation = false

    private var filteredSessionIDs: Set<UUID> {
        Set(viewModel.filteredSessions.map(\.id))
    }

    private var allFilteredSessionsSelected: Bool {
        !viewModel.filteredSessions.isEmpty
            && filteredSessionIDs.isSubset(of: selectedSessionIDs)
    }

    private var isPad: Bool {
        DeviceType.isPad || horizontalSizeClass == .regular
    }

    private var sessionsFingerprint: [UUID] {
        sessions.map(\.id)
    }

    private var selectedSession: ChargingSession? {
        guard let selectedSessionID else { return nil }
        return sessions.first { $0.id == selectedSessionID }
    }

    var body: some View {
        Group {
            if isPad {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .onAppear {
            viewModel.load(sessions: sessions)
            if selectedSessionID == nil {
                selectedSessionID = sessions.first?.id
            }
        }
        .onChange(of: sessionsFingerprint) { _, _ in
            viewModel.load(sessions: sessions)
            selectedSessionIDs.formIntersection(filteredSessionIDs)
            if selectedSessionIDs.isEmpty {
                isSelectionMode = false
            }
            if let selectedSessionID, !sessions.contains(where: { $0.id == selectedSessionID }) {
                self.selectedSessionID = sessions.first?.id
            }
        }
    }

    private var iPadLayout: some View {
        HStack(spacing: 0) {
            historyListContent
                .frame(minWidth: 320, idealWidth: 380, maxWidth: 420)

            Divider()

            Group {
                if let session = selectedSession {
                    SessionDetailView(
                        session: session,
                        showsNavigationChrome: false,
                        onDelete: {
                            selectedSessionID = sessions.first(where: { $0.id != session.id })?.id
                        }
                    )
                } else {
                    historyDetailPlaceholder
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var iPhoneLayout: some View {
        historyListContent
            .navigationDestination(item: $navigationSessionID) { sessionID in
                if let session = sessions.first(where: { $0.id == sessionID }) {
                    SessionDetailView(session: session)
                }
            }
    }

    private var selectionBarTotalHeight: CGFloat {
        52 + (isPad ? 0 : EVAiSpacing.tabBarHeight)
    }

    private var historyListContent: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: EVAiSpacing.sectionSpacing) {
                    searchBar
                    searchScopePicker
                    filterToolbar
                    filterChips
                    sortPicker
                }
                .padding(.vertical, EVAiSpacing.sm)
                .listRowInsets(EdgeInsets(
                    top: 0,
                    leading: EVAiSpacing.horizontalPadding,
                    bottom: 0,
                    trailing: EVAiSpacing.horizontalPadding
                ))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                if viewModel.filteredSessions.isEmpty {
                    VStack(alignment: .leading, spacing: EVAiSpacing.sm) {
                        Text("No sessions found")
                            .font(EVAiTypography.headline)
                            .foregroundStyle(colors.primaryText)
                        Text("Try adjusting your search or filters.")
                            .font(EVAiTypography.subheadline)
                            .foregroundStyle(colors.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
                    .listRowInsets(EdgeInsets(
                        top: 0,
                        leading: EVAiSpacing.horizontalPadding,
                        bottom: 0,
                        trailing: EVAiSpacing.horizontalPadding
                    ))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(viewModel.displayedSessions, id: \.id) { session in
                        sessionRow(for: session)
                    }

                    if viewModel.hasMoreSessions {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, EVAiSpacing.sm)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
            } header: {
                SectionHeader(
                    title: "Sessions (\(viewModel.filteredSessions.count))"
                )
                .textCase(nil)
                .listRowInsets(EdgeInsets(
                    top: 0,
                    leading: EVAiSpacing.horizontalPadding,
                    bottom: 0,
                    trailing: EVAiSpacing.horizontalPadding
                ))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .safeAreaPadding(.bottom, isSelectionMode ? selectionBarTotalHeight : EVAiSpacing.tabBarHeight)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if isSelectionMode {
                    Button(allFilteredSessionsSelected ? "Deselect All" : "Select All") {
                        toggleSelectAllFilteredSessions()
                    }
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                if isSelectionMode {
                    if !selectedSessionIDs.isEmpty {
                        Button("Delete", role: .destructive) {
                            showBulkDeleteConfirmation = true
                        }
                    }
                    Button("Cancel") {
                        exitSelectionMode()
                    }
                } else if !viewModel.filteredSessions.isEmpty {
                    Button("Select") {
                        isSelectionMode = true
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isSelectionMode {
                selectionActionBar
            }
        }
        .confirmationDialog(
            "Delete \(selectedSessionIDs.count) session\(selectedSessionIDs.count == 1 ? "" : "s")?",
            isPresented: $showBulkDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Sessions", role: .destructive) {
                deleteSelectedSessions()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .sheet(isPresented: $viewModel.isShowingAdvancedFilters) {
            HistoryAdvancedFiltersSheet(
                filters: $viewModel.advancedFilters,
                availableNetworks: viewModel.availableNetworks,
                availableCars: viewModel.availableCars
            ) {
                viewModel.applyAdvancedFilters(viewModel.advancedFilters)
            }
        }
    }

    private var selectionActionBar: some View {
        HStack(spacing: EVAiSpacing.md) {
            Text("\(selectedSessionIDs.count) selected")
                .font(EVAiTypography.subheadline)
                .foregroundStyle(colors.secondaryText)

            Spacer()

            Button(role: .destructive) {
                showBulkDeleteConfirmation = true
            } label: {
                Text("Delete")
                    .font(EVAiTypography.headline)
            }
            .disabled(selectedSessionIDs.isEmpty)
        }
        .padding(.horizontal, EVAiSpacing.horizontalPadding)
        .padding(.top, EVAiSpacing.md)
        .padding(.bottom, EVAiSpacing.md + (isPad ? 0 : EVAiSpacing.tabBarHeight))
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Divider().opacity(0.3)
                }
        }
    }

    private func sessionRow(for session: ChargingSession) -> some View {
        Group {
            if isSelectionMode {
                Button {
                    toggleSessionSelection(session.id)
                } label: {
                    HStack(spacing: EVAiSpacing.md) {
                        Image(systemName: selectedSessionIDs.contains(session.id) ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(
                                selectedSessionIDs.contains(session.id) ? Color.primaryBlue : colors.secondaryText
                            )

                        SessionCard(session: session)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    selectedSessionID = session.id
                    navigationSessionID = session.id
                } label: {
                    SessionCard(session: session)
                        .overlay {
                            if isPad, selectedSessionID == session.id {
                                RoundedRectangle(cornerRadius: EVAiSpacing.buttonRadius, style: .continuous)
                                    .strokeBorder(Color.primaryBlue, lineWidth: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .listRowInsets(EdgeInsets(
            top: EVAiSpacing.xxs,
            leading: EVAiSpacing.horizontalPadding,
            bottom: EVAiSpacing.xxs,
            trailing: EVAiSpacing.horizontalPadding
        ))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if !isSelectionMode {
                Button(role: .destructive) {
                    deleteSession(session)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .onAppear {
            viewModel.loadMoreIfNeeded(currentSession: session)
        }
    }

    private func toggleSessionSelection(_ id: UUID) {
        if selectedSessionIDs.contains(id) {
            selectedSessionIDs.remove(id)
        } else {
            selectedSessionIDs.insert(id)
        }
    }

    private func toggleSelectAllFilteredSessions() {
        if allFilteredSessionsSelected {
            selectedSessionIDs.subtract(filteredSessionIDs)
        } else {
            selectedSessionIDs.formUnion(filteredSessionIDs)
        }
    }

    private func exitSelectionMode() {
        isSelectionMode = false
        selectedSessionIDs.removeAll()
    }

    private func deleteSelectedSessions() {
        let ids = selectedSessionIDs
        let sessionsToDelete = sessions.filter { ids.contains($0.id) }
        deleteSessions(sessionsToDelete)
        exitSelectionMode()
    }

    private func deleteSession(_ session: ChargingSession) {
        deleteSessions([session])
    }

    private func deleteSessions(_ sessionsToDelete: [ChargingSession]) {
        let deletedIDs = Set(sessionsToDelete.map(\.id))
        for session in sessionsToDelete {
            modelContext.delete(session)
        }

        do {
            try modelContext.save()
        } catch {
            return
        }

        if let selectedSessionID, deletedIDs.contains(selectedSessionID) {
            self.selectedSessionID = sessions.first(where: { !deletedIDs.contains($0.id) })?.id
        }
        if let navigationSessionID, deletedIDs.contains(navigationSessionID) {
            self.navigationSessionID = nil
        }

        syncDerivedSessionData()
    }

    private func syncDerivedSessionData() {
        let allSessions = (try? modelContext.fetch(FetchDescriptor<ChargingSession>())) ?? []
        WidgetDataStore.sync(from: allSessions)
        AnalyticsCacheService.save(
            AnalyticsCacheService.rebuildSummary(from: allSessions, month: .now.startOfMonth)
        )
    }

    private var searchBar: some View {
        HStack(spacing: EVAiSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(colors.secondaryText)

            TextField("Search location, network, car…", text: $viewModel.searchText)
                .font(EVAiTypography.body)
                .foregroundStyle(colors.primaryText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: viewModel.searchText) { _, newValue in
                    viewModel.updateSearch(newValue)
                }
        }
        .padding(.horizontal, EVAiSpacing.md)
        .padding(.vertical, EVAiSpacing.sm)
        .background {
            RoundedRectangle(cornerRadius: EVAiSpacing.buttonRadius, style: .continuous)
                .fill(colors.cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: EVAiSpacing.buttonRadius, style: .continuous)
                        .strokeBorder(colors.cardBorder, lineWidth: 0.5)
                }
        }
        .padding(.top, EVAiSpacing.sm)
    }

    private var searchScopePicker: some View {
        Picker("Search Scope", selection: Binding(
            get: { viewModel.searchScope },
            set: { viewModel.updateSearchScope($0) }
        )) {
            ForEach(SearchScope.allCases) { scope in
                Text(scope.title).tag(scope)
            }
        }
        .pickerStyle(.segmented)
    }

    private var filterToolbar: some View {
        HStack {
            if viewModel.advancedFilters.isActive {
                Text("Advanced filters active")
                    .font(EVAiTypography.caption)
                    .foregroundStyle(Color.primaryBlue)
            }

            Spacer()

            Button {
                viewModel.isShowingAdvancedFilters = true
            } label: {
                Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                    .font(EVAiTypography.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.primaryBlue)
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EVAiSpacing.sm) {
                ForEach(viewModel.availableFilters) { filter in
                    HistoryFilterChipView(
                        title: filter.title,
                        isSelected: viewModel.selectedFilter == filter
                    ) {
                        viewModel.selectFilter(filter)
                    }
                }
            }
        }
    }

    private var sortPicker: some View {
        VStack(alignment: .leading, spacing: EVAiSpacing.sm) {
            Text("Sort By")
                .font(EVAiTypography.caption)
                .foregroundStyle(colors.secondaryText)

            Picker("Sort By", selection: Binding(
                get: { viewModel.sortOption },
                set: { viewModel.selectSort($0) }
            )) {
                ForEach(HistorySortOption.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var historyDetailPlaceholder: some View {
        VStack(spacing: EVAiSpacing.md) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color.primaryBlue)
                .symbolRenderingMode(.hierarchical)

            Text("Select a Session")
                .font(EVAiTypography.title3)
                .foregroundStyle(colors.primaryText)

            Text("Choose a charging session from the list to preview details.")
                .font(EVAiTypography.subheadline)
                .foregroundStyle(colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, EVAiSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct HistoryFilterChipView: View {
    @Environment(\.themeColors) private var colors

    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(EVAiTypography.caption)
                .foregroundStyle(isSelected ? .white : colors.secondaryText)
                .padding(.horizontal, EVAiSpacing.md)
                .padding(.vertical, EVAiSpacing.xs)
                .background {
                    Capsule(style: .continuous)
                        .fill(isSelected ? AnyShapeStyle(EVAiGradients.button) : AnyShapeStyle(colors.cardBackground))
                        .overlay {
                            if !isSelected {
                                Capsule(style: .continuous)
                                    .strokeBorder(colors.cardBorder, lineWidth: 0.5)
                            }
                        }
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .modelContainer(for: ChargingSession.self, inMemory: true)
    .environment(ThemeManager())
    .applyTheme(ThemeManager())
}
