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

    init(viewModel: DreamLibraryViewModel) {
        _vm = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            if vm.dreams.isEmpty {
                Text("No dreams recorded yet")
                    .font(.custom("Avenir-Medium", size: 18))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            } else {
                List(vm.dreams) { dream in
                    NavigationLink(value: dream) {
                        row(for: dream)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Dream Library")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: Dream.self) { dream in
            DreamEntryView(dream: dream, store: vm.store)
        }
        .task { await vm.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await vm.refresh() }
        }
        .onAppear { 
            configureNavFont()
            Task { await vm.refresh() }
        }
    }

    // MARK: Row -----------------------------------------------------------

    @ViewBuilder
    private func row(for dream: Dream) -> some View {
        let _ = print("📱 DreamLibraryView.row: Rendering dream \(dream.id) with title '\(dream.title)'")
        VStack(alignment: .leading, spacing: 4) {
            Text(dream.title.isEmpty ? "Untitled" : dream.title)
                .font(.custom("Avenir-Heavy", size: 18))

            if let summary = dream.summary, !summary.isEmpty {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else if let transcript = dream.transcript, !transcript.isEmpty {
                Text(transcript)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: Nav Bar Font --------------------------------------------------

    private func configureNavFont() {
        let appearance = UINavigationBarAppearance()
        appearance.largeTitleTextAttributes = [
            .font: UIFont(name: "Avenir-Heavy", size: 34) as Any
        ]
        appearance.titleTextAttributes = [
            .font: UIFont(name: "Avenir-Medium", size: 18) as Any
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
