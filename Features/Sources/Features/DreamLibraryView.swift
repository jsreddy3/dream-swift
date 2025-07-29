//  DreamLibraryView.swift
//  DreamCatcher
//
//  Minimalistic dream library – taps to open DreamEntryView.
//  No rename, no video playback, no clip disclosure.
//

import SwiftUI
import CoreModels
import Infrastructure
import DomainLogic

// MARK: - View -----------------------------------------------------------

struct DreamLibraryView: View {
    @StateObject private var vm: DreamLibraryViewModel
    private let shouldRefresh: Bool

    init(viewModel: DreamLibraryViewModel, shouldRefresh: Bool = false) {
        _vm = StateObject(wrappedValue: viewModel)
        self.shouldRefresh = shouldRefresh
    }

    var body: some View {
        ZStack {
            // Much lighter base - almost grey
            Color(white: 0.15).ignoresSafeArea()
            
            // Very bright gradient overlay
            LinearGradient(
                colors: [
                    DesignSystem.Colors.ember.opacity(0.6),
                    Color.purple.opacity(0.3),
                    Color.pink.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Very bright stars
            StarsBackgroundView()
                .opacity(1.0)
                .ignoresSafeArea()
            
            Group {
                if vm.dreams.isEmpty {
                    Text("No dreams recorded yet")
                        .font(DesignSystem.Typography.subheadline())
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    dreamList
                }
            }
        }
        .navigationTitle("Dream Library")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: Dream.self) { dream in
            DreamEntryView(dream: dream, store: vm.store)
        }
        .task { 
            // Refresh if we have no dreams (first load) or explicitly requested
            if vm.dreams.isEmpty || shouldRefresh {
                await vm.refresh()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await vm.refresh() }
        }
        .onAppear { 
            configureNavFont()
        }
    }

    // MARK: Date-Grouped List ------------------------------------------------
    
    private var dreamList: some View {
        let sectioned = groupDreamsByDate(vm.dreams)
        
        return List {
            ForEach(sectioned.keys.sorted(by: >), id: \.self) { key in
                if let dreamGroup = sectioned[key] {
                    Section(header: Text(key).foregroundColor(DesignSystem.Colors.ember)) {
                        ForEach(dreamGroup) { dream in
                            NavigationLink(value: dream) {
                                row(for: dream)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    Task { await vm.deleteDream(dream.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
    }
    
    /// Groups dreams by relevant date descriptions - Today, Yesterday, weekdays, or date
    private func groupDreamsByDate(_ dreams: [Dream]) -> [String: [Dream]] {
        let cal = Calendar.current
        let now = Date()
        
        return Dictionary(grouping: dreams) { dream -> String in
            let date = dream.created_at
            
            if cal.isDateInToday(date) {
                return "Today"
            } else if cal.isDateInYesterday(date) {
                return "Yesterday"
            } else if cal.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
                // Same week, return day name
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE" // Full day name
                return formatter.string(from: date)
            } else {
                // Different week, return formatted date
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return formatter.string(from: date)
            }
        }
    }
    
    // MARK: Row -----------------------------------------------------------

    // MARK: Dream Row ------------------------------------------------------

    @ViewBuilder
    private func row(for dream: Dream) -> some View {
        DreamCardView(dream: dream)
            .listRowSeparator(.hidden)              // hide default divider
            .listRowInsets(.init())                 // edge-to-edge card
            .listRowBackground(Color.clear)         // transparent list bg
    }

    /// A rounded card-style representation of a dream.
    private struct DreamCardView: View {
        let dream: Dream
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                // Title + optional state icon
                HStack(alignment: .firstTextBaseline) {
                    Text(dream.title.isEmpty ? "Untitled" : dream.title)
                        .font(DesignSystem.Typography.subheadline())
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Spacer(minLength: 4)
                    stateIcon
                }
                
                // Summary ⇢ Transcript fallback
                if let text = primaryText, !text.isEmpty {
                    Text(text)
                        .font(DesignSystem.Typography.caption())
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(3)
                }
                
                // Date footer with day
                Text(formatDateWithDay(dream.created_at))
                    .font(.caption2)
                    .foregroundColor(DesignSystem.Colors.ember)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(DesignSystem.Colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
        }
        
        // MARK: Helpers
        private var primaryText: String? {
            if let summary = dream.summary, !summary.isEmpty { return summary }
            return dream.transcript
        }
        
        @ViewBuilder
        private var stateIcon: some View {
            switch dream.state {
            case .completed:
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(DesignSystem.Colors.ember)
                    .font(.system(size: 14, weight: .semibold))
            case .video_generated:
                Image(systemName: "video.fill")
                    .foregroundStyle(DesignSystem.Colors.ember)
                    .font(.system(size: 14, weight: .semibold))
            default:
                EmptyView()
            }
        }
        
        private func formatDateWithDay(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d, yyyy"  // e.g., "Monday, Dec 25, 2024"
            return formatter.string(from: date)
        }
    }

    // MARK: Nav Bar Font --------------------------------------------------

    private func configureNavFont() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.largeTitleTextAttributes = [
            .font: UIFont(name: "Avenir-Heavy", size: 34) as Any,
            .foregroundColor: UIColor.white
        ]
        appearance.titleTextAttributes = [
            .font: UIFont(name: "Avenir-Medium", size: 18) as Any,
            .foregroundColor: UIColor.white
        ]
        UINavigationBar.appearance().standardAppearance  = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Dream ⇢ Hashable ----------------------------------------------

extension Dream: Hashable {
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
    public static func == (lhs: Dream, rhs: Dream) -> Bool { lhs.id == rhs.id }
}

// MARK: - Preview --------------------------------------------------------


#if DEBUG
#Preview {
    let local  = FileDreamStore()
    let auth   = AuthStore()
    let remote = RemoteDreamStore(baseURL: URL(string: "http://localhost:8000")!, auth: auth)
    let sync   = SyncingDreamStore(local: local, remote: remote)
    let vm     = DreamLibraryViewModel(store: sync)
    return NavigationStack { DreamLibraryView(viewModel: vm) }
}
#endif
