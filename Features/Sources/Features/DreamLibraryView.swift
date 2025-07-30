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
            // Use the new unified dream background
            DreamBackground()
            
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
        
        // Sort section keys properly with special handling for Today/Yesterday
        let sortedKeys = sectioned.keys.sorted { key1, key2 in
            // Special cases for Today and Yesterday
            if key1 == "Today" { return true }
            if key2 == "Today" { return false }
            if key1 == "Yesterday" && key2 != "Today" { return true }
            if key2 == "Yesterday" && key1 != "Today" { return false }
            
            // For all other cases, we need to compare the actual dates
            // Find the first dream in each section to get the date
            if let dream1 = sectioned[key1]?.first,
               let dream2 = sectioned[key2]?.first {
                return dream1.created_at > dream2.created_at
            }
            
            // Fallback to string comparison
            return key1 > key2
        }
        
        return ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                ForEach(sortedKeys, id: \.self) { key in
                    if let dreamGroup = sectioned[key] {
                        // Sort dreams within each section by created_at, newest first
                        let sortedDreams = dreamGroup.sorted { $0.created_at > $1.created_at }
                        Section {
                            ForEach(sortedDreams) { dream in
                                NavigationLink(value: dream) {
                                    DreamCardView(dream: dream)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .padding(.top, dream.id == sortedDreams.first?.id ? 8 : 0)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        Haptics.warning() // Delete warning haptic
                                        Task { await vm.deleteDream(dream.id) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            HStack {
                                Text(key)
                                    .font(DesignSystem.Typography.subheadline())
                                    .foregroundColor(DesignSystem.Colors.ember)
                                    .textCase(.none)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(
                                    colors: [
                                        DesignSystem.Colors.backgroundSecondary.opacity(0.95),
                                        DesignSystem.Colors.backgroundSecondary.opacity(0.9)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                    }
                }
            }
        }
        .refreshable {
            Haptics.medium() // Pull-to-refresh haptic
            await vm.refresh()
        }
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
            .padding(DesignSystem.Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: DesignSystem.CornerRadius.medium)
            .dreamShadow()
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
        appearance.configureWithOpaqueBackground()
        
        // Create a UIImage from the gradient to use as background
        let gradientImage = createGradientImage()
        appearance.backgroundImage = gradientImage
        appearance.shadowImage = UIImage() // Remove the bottom line
        appearance.shadowColor = .clear
        
        appearance.largeTitleTextAttributes = [
            .font: UIFont(name: DesignSystem.Typography.fontFamilyHeavy, size: 32) ?? UIFont.systemFont(ofSize: 32, weight: .heavy),
            .foregroundColor: UIColor.white
        ]
        appearance.titleTextAttributes = [
            .font: UIFont(name: DesignSystem.Typography.fontFamilyMedium, size: 17) ?? UIFont.systemFont(ofSize: 17, weight: .medium),
            .foregroundColor: UIColor.white
        ]
        
        UINavigationBar.appearance().standardAppearance  = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
    
    private func createGradientImage() -> UIImage? {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 200)
        
        // Match the dream gradient colors
        gradientLayer.colors = [
            UIColor(red: 255/255, green: 145/255, blue: 0/255, alpha: 0.6).cgColor, // ember
            UIColor(red: 128/255, green: 0/255, blue: 128/255, alpha: 0.3).cgColor, // purple
            UIColor(red: 255/255, green: 192/255, blue: 203/255, alpha: 0.2).cgColor  // pink
        ]
        
        // Match the gradient direction (topLeading to bottomTrailing)
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        
        // Add dark background behind gradient
        let backgroundLayer = CALayer()
        backgroundLayer.frame = gradientLayer.frame
        backgroundLayer.backgroundColor = UIColor(white: 0.15, alpha: 1.0).cgColor
        
        // Render to image
        UIGraphicsBeginImageContextWithOptions(gradientLayer.frame.size, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        backgroundLayer.render(in: context)
        gradientLayer.render(in: context)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
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
