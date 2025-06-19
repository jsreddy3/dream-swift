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
                    Button("Done") { vm.finish() }.font(.title3)

                }

                if !vm.segments.isEmpty {
                    List {
                        ForEach(vm.segments, id: \.id) { seg in
                            Text("Clip \(seg.order) – \(Int(seg.duration)) s")
                        }
                        .onDelete { idx in vm.remove(vm.segments[idx.first!]) }
                    }
                    .listStyle(.plain)
                    .frame(maxHeight: 200)
                }
            }
            .padding()
            .navigationTitle("Capture")          // ← nav-bar title
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
        case .idle:     "Ready"
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
