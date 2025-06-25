import SwiftUI
import AVKit
import CoreModels
import Infrastructure
import DomainLogic
import Foundation

// MARK: - Library ----------------------------------------------------------

struct DreamLibraryView: View {
    @State private var vm: DreamLibraryViewModel       // keeps instance alive
    @State private var open: UUID?               = nil
    @State private var clips: [UUID: [AudioSegment]] = [:]
    @State private var editing: Dream?           = nil
    @State private var draft                     = ""
    @State private var playing: Dream?           = nil       // video sheet binding

    init(viewModel: DreamLibraryViewModel) {
        _vm = State(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            if vm.dreams.isEmpty {
                Text("No dreams recorded yet")
                    .font(.custom("Avenir-Medium", size: 18))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemBackground))
            } else {
                List(vm.dreams) { dream in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { open == dream.id && editing == nil },
                            set: { expanded in
                                open = expanded ? dream.id : nil
                                if expanded && clips[dream.id] == nil {
                                    Task { clips[dream.id] = try? await vm.segments(for: dream) }
                                }
                            })
                    ) {
                        if let segs = clips[dream.id] {
                            ForEach(segs, id: \.id) { seg in
                                Text("Clip \(seg.order) – \(Int(seg.duration)) s")
                            }
                        } else {
                            ProgressView()
                        }
                    } label: {
                        rowLabel(for: dream)
                    }
                    .swipeActions {
                        Button("Rename") {
                            draft   = dream.title
                            editing = dream
                        }
                    }
                }
            }
        }
        .task { @MainActor in await vm.refresh() }           // no Sendable warning
        .navigationTitle("Dream Library")
        .navigationBarTitleDisplayMode(.large)
        .onAppear(perform: configureNavFont)
        .sheet(item: $playing) { dream in
            VideoLoadingView(dream: dream,
                             store: vm.store,
                             isPresented: $playing)
        }
        .sheet(item: $editing) { dream in
            renameSheet(for: dream)
        }
    }

    // MARK: row label ------------------------------------------------------

    @ViewBuilder
    private func rowLabel(for dream: Dream) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dream.title.isEmpty ? "Untitled" : dream.title)
                    .fontWeight(.semibold)

                if let t = dream.transcript, !t.isEmpty {
                    Text(t)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 2) {
                Text(dream.state == .draft
                        ? "Draft"
                        : dream.state == .video_generated ? "Video Ready" : "Done")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .onAppear {
                        print("Dream \(dream.id): state=\(dream.state.rawValue), videoS3Key=\(dream.videoS3Key ?? "nil")")
                    }

                if dream.state == .video_generated,
                   dream.videoS3Key != nil {
                    Button { playing = dream } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                } else if dream.state == .video_generated {
                    // Debug: video_generated but no S3 key
                    Text("No S3 Key")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
        }
    }

    // MARK: rename sheet ---------------------------------------------------

    @ViewBuilder
    private func renameSheet(for dream: Dream) -> some View {
        NavigationStack {
            Form {
                TextField("Title", text: $draft)
                Button("Save") {
                    Task { await vm.rename(dream, to: draft) }
                    editing = nil
                }
            }
            .navigationTitle("Rename Dream")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { editing = nil }
                }
            }
        }
    }

    // MARK: nav bar font ---------------------------------------------------

    private func configureNavFont() {
        let appearance = UINavigationBarAppearance()
        appearance.largeTitleTextAttributes = [
            .font: UIFont(name: "Avenir-Heavy", size: 34)!
        ]
        appearance.titleTextAttributes = [
            .font: UIFont(name: "Avenir-Medium", size: 18)!
        ]
        UINavigationBar.appearance().standardAppearance  = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Video loader -----------------------------------------------------

struct VideoLoadingView: View {
    let dream: Dream
    let store: SyncingDreamStore
    @Binding var isPresented: Dream?

    @State private var videoURL: URL?
    @State private var isLoading  = true
    @State private var errorMsg:  String?

    var body: some View {
        Group {
            if isLoading {
                VStack {
                    ProgressView("Loading video…").padding()
                    Button("Cancel") { isPresented = nil }
                }
            } else if let url = videoURL {
                VideoPlayerView(url: url, isPresented: Binding(
                    get: { isPresented != nil },
                    set: { if !$0 { isPresented = nil } }
                ))
            } else {
                VStack {
                    Text("Failed to load video")
                        .font(.headline)
                    if let e = errorMsg {
                        Text(e).font(.caption).foregroundColor(.secondary)
                    }
                    Button("Close") { isPresented = nil }.padding()
                }
            }
        }
        .task {
            do {
                if let url = try await store.getVideoURL(dreamID: dream.id) {
                    videoURL   = url
                } else {
                    errorMsg   = "No video URL available"
                }
            } catch {
                errorMsg   = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Preview ----------------------------------------------------------

#Preview {
    let local  = FileDreamStore()
    let remote = RemoteDreamStore(baseURL: URL(string: "http://localhost:8000")!)
    let sync   = SyncingDreamStore(local: local, remote: remote)
    NavigationStack {
        DreamLibraryView(viewModel: DreamLibraryViewModel(store: sync))
    }
}
