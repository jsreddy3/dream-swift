import SwiftUI
import Infrastructure       // concrete actors
import DomainLogic

public struct ContentView: View {
    @State private var vm: CaptureViewModel
    @State private var showLibrary = false

    public init(viewModel: CaptureViewModel) {
        _vm = State(initialValue: viewModel)
    }

    public var body: some View {
        NavigationStack {                        // ← just this wrapper is new
            VStack(spacing: 24) {                // ← your existing layout
                LoopingVideoView(named: "campfire_fullrange")
                    .frame(width: 300, height: 300)
                    .fixedSize()
                    .cornerRadius(50)
                
                Text(label(for: vm.state)).font(.headline)

                Button(action: { vm.startOrStop() }) {
                    Image(systemName: icon(for: vm.state))
                        .resizable()
                        .frame(width: 88, height: 88)
                        .foregroundStyle(color(for: vm.state))
                }
                .buttonStyle(.plain)
                
                if case .paused = vm.state {
                    TextField("Dream title", text: $vm.title)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                    Button("Complete Dream Recording") { vm.finish() }.font(.title3)
                }

                if !vm.segments.isEmpty {
                    List {
                        ForEach(vm.segments, id: \.id) { seg in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Clip \(seg.order) – \(Int(seg.duration)) s")
                                    .fontWeight(.semibold)
                                if let t = seg.transcript, !t.isEmpty {
                                    Text(t)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)     // truncate long sentences nicely
                                }
                            }
                        }
                        .onDelete { idx in
                            vm.remove(vm.segments[idx.first!])
                        }
                    }
                    .listStyle(.plain)
                    .frame(maxHeight: 200)
                }
            }
            // .padding(.horizontal)
            // .padding(.bottom)
            // .padding(.top, 8)
           .navigationTitle("Capture")          // ← nav-bar title
            // .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {      // ← fix ①
                    Button { showLibrary = true } label: {            // ← fix ②
                        Image(systemName: "books.vertical")
                    }
                }
            }
            .sheet(isPresented: $showLibrary) { // ← modal library
                NavigationStack {
                    DreamLibraryView(
                        viewModel: DreamLibraryViewModel(store: vm.store)
                    )
                }
            }
        }
    }

    // MARK: private helpers

    private func label(for s: CaptureState) -> String {
        switch s {
        case .idle:     "Tap to record"
        case .recording:"Recording…"
        case .paused:   "Paused"
        case .saving:   "Saving…"
        case .saved:    "Saved ✅"
        case .failed(let msg): msg
        }
    }

    private func icon(for s: CaptureState) -> String {
        switch s {
        case .recording: "stop.circle.fill"
        default:         "mic.circle.fill"
        }
    }

    private func color(for s: CaptureState) -> Color {
        s == .recording ? .red : .accentColor
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let recorder = AudioRecorderActor()
        let localStore = FileDreamStore()
        let remoteStore = RemoteDreamStore(baseURL: URL(string: "http://localhost:8000")!)
        let syncStore = SyncingDreamStore(local: localStore, remote: remoteStore)
        let sampleViewModel = CaptureViewModel(recorder: recorder, store: syncStore)
        
        return ContentView(viewModel: sampleViewModel)
    }
}
