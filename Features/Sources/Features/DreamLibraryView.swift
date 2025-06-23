import CoreModels
import Infrastructure
import DomainLogic
import Foundation
import SwiftUI
import AVKit

struct DreamLibraryView: View {
    @State private var vm: DreamLibraryViewModel
    @State private var open: UUID? = nil                 // restore
    @State private var clips: [UUID: [AudioSegment]] = [:]
    @State private var editing: Dream? = nil
    @State private var draft = ""
    @State private var playingDream: Dream? = nil  // Changed to track which dream is playing

    init(viewModel: DreamLibraryViewModel) {
        _vm = State(initialValue: viewModel)
    }

    var body: some View {
        List(vm.dreams) { dream in
            // ――― helpers so each closure is tiny ―――
            let isExpanded = Binding(
                get: { open == dream.id && editing == nil },
                set: { expanded in
                    open = expanded ? dream.id : nil
                    if expanded && clips[dream.id] == nil {
                        Task { clips[dream.id] = try? await vm.segments(for: dream) }
                    }
                })

            let clipList = Group {
                if let segs = clips[dream.id] {
                    ForEach(segs, id: \.id) {
                        Text("Clip \($0.order) – \(Int($0.duration)) s")
                    }
                } else { ProgressView() }
            }

            let rowLabel = HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dream.title.isEmpty ? "Untitled" : dream.title)
                        .fontWeight(.semibold)

                    if let t = dream.transcript, !t.isEmpty {
                        Text(t)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)                     // truncate long transcripts
                    }
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(dream.state == .draft ? "Draft" : dream.state == .video_generated ? "Video Ready" : "Done")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if dream.state == .video_generated && dream.videoS3Key != nil {
                        Button(action: {
                            print("Play button tapped for dream: \(dream.id)")
                            playingDream = dream
                        }) {
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(.accentColor)
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }


            DisclosureGroup(isExpanded: isExpanded) { clipList } label: { rowLabel }
                .swipeActions {
                    Button("Rename") {
                        draft   = dream.title
                        editing = dream
                    }
                }
        }
        .task { await vm.refresh() }
        .navigationTitle("Dream Library")
        // ――― video player ―――
        .sheet(item: $playingDream) { dream in
            VideoLoadingView(dream: dream, store: vm.store, isPresented: $playingDream)
        }
        // ――― rename sheet ―――
        .sheet(item: $editing) { dream in
            NavigationStack {
                Form {
                    TextField("Title", text: $draft)
                    Button("Save") {
                        Task { await vm.rename(dream, to: draft) }   // ← correct helper
                        editing = nil
                    }
                }
                .navigationTitle("Rename Dream")
                .toolbar { ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { editing = nil }
                }}
            }
        }
    }
}

// New view to handle async loading
struct VideoLoadingView: View {
    let dream: Dream
    let store: SyncingDreamStore
    @Binding var isPresented: Dream?
    @State private var videoURL: URL?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        Group {
            if isLoading {
                VStack {
                    ProgressView("Loading video...")
                        .padding()
                    Button("Cancel") {
                        isPresented = nil
                    }
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
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Button("Close") {
                        isPresented = nil
                    }
                    .padding()
                }
            }
        }
        .task {
            do {
                print("VideoLoadingView: Fetching URL for dream \(dream.id)")
                if let url = try await store.getVideoURL(dreamID: dream.id) {
                    print("VideoLoadingView: Got URL: \(url)")
                    videoURL = url
                    isLoading = false
                } else {
                    print("VideoLoadingView: No URL returned")
                    errorMessage = "No video URL available"
                    isLoading = false
                }
            } catch {
                print("VideoLoadingView: Error: \(error)")
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

struct DreamLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        let localStore = FileDreamStore()
        let remoteStore = RemoteDreamStore(baseURL: URL(string: "http://localhost:8000")!)
        let syncStore = SyncingDreamStore(local: localStore, remote: remoteStore)
        let sampleViewModel = DreamLibraryViewModel(store: syncStore)
        
        return NavigationStack {
            DreamLibraryView(viewModel: sampleViewModel)
        }
    }
}
