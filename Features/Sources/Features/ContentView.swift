import SwiftUI
import Infrastructure
import DomainLogic
import CoreModels


// MARK: – local types

private enum InputMode: Hashable { case voice, text }

/// Pill-shaped two-button toggle with a sliding accent indicator.
private struct ModeToggle: View {
    @Binding var selection: InputMode
    var disabled: Bool

    @Namespace private var ns              // for matched-geometry slide

    var body: some View {
        HStack(spacing: 0) {
            cell(.voice, label: "Voice")
            cell(.text,  label: "Text")
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(.systemGray6))
        )
        .opacity(disabled ? 0.5 : 1)
        .animation(.easeInOut(duration: 0.18), value: selection)
        .allowsHitTesting(!disabled)       // greys out & blocks taps mid-clip
    }

    @ViewBuilder
    private func cell(_ mode: InputMode, label: String) -> some View {
        Button {
            selection = mode
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .padding(.vertical, 8)
                .padding(.horizontal, 20)                 // intrinsic width only
                .foregroundColor(selection == mode ? .white : .primary)
                .contentShape(Rectangle())
                .background(
                    ZStack {
                        if selection == mode {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.accentColor)
                                .matchedGeometryEffect(id: "slider", in: ns)
                        }
                    }
                )
        }
    }
}

// MARK: – main capture view

public struct ContentView: View {
    @State private var vm: CaptureViewModel
    @EnvironmentObject private var auth: AuthBridge

    @State private var mode: InputMode = .voice
    @State private var draft = ""
    @State private var showLibrary = false
    @State private var dreamToOpen: Dream?    // navigation trigger
    @FocusState private var textEntryFocused: Bool

    public init(viewModel: CaptureViewModel) {
        _vm = State(initialValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(label(for: vm.state))
                    .font(.custom("Avenir-Medium", size: 30))
                    .padding(.top, -50)

                LoopingVideoView(named: "campfire_fullrange")
                    .frame(width: 300, height: 300)
                    .fixedSize()
                    .cornerRadius(50)
                
                // Show mode toggle only when not recording AND (not clipped OR extending)
                if vm.state != .recording && (vm.state != .clipped || vm.isExtending) {
                    ModeToggle(selection: $mode, disabled: false)
                        .transition(.opacity)
                }

                // Show mic/text only when not clipped OR when extending (and not saving)
                if (vm.state != .clipped && vm.state != .saving) || vm.isExtending {
                    ZStack {
                        // Mic button – show only in Voice
                        if mode == .voice {
                            Button { vm.startOrStop() } label: {
                                Image(systemName: icon(for: vm.state))
                                    .resizable()
                                    .frame(width: 88, height: 88)
                                    .foregroundStyle(color(for: vm.state))
                            }
                            .buttonStyle(.plain)
                        }

                        // Text entry – show only in Text
                        if mode == .text {
                            TextClipEntry(
                                text: $draft,
                                disabled: false,
                                isFocused: $textEntryFocused,
                                onSave: {
                                    textEntryFocused = false
                                    vm.startOrStopText(draft)
                                    draft = ""
                                })
                        }
                    }
                    .frame(height: 88)
                    .animation(.easeInOut(duration: 0.2), value: mode)
                }
                
                if vm.state == .clipped && !vm.isExtending {
                    VStack(spacing: 12) {
                        // primary action – Complete Dream
                        Button {
                            vm.finish()
                        } label: {
                            Text("Complete Dream")
                                .font(.custom("Avenir-Heavy", size: 18))
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .foregroundColor(.white)
                                .background(
                                    Capsule()
                                        .fill(Color.accentColor)
                                )
                        }
                        
                        // secondary action – Extend Dream
                        Button {
                            vm.extend()
                        } label: {
                            Text("Extend Dream")
                                .font(.custom("Avenir-Heavy", size: 18))
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .foregroundColor(.secondary)
                                .background(
                                    Capsule()
                                        .stroke(Color.secondary, lineWidth: 2)
                                )
                        }
                    }
                    .transition(.opacity)
                    .padding(.top, 5)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: vm.isExtending)
            .navigationTitle("")  // These modifiers are now INSIDE NavigationStack
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Sign Out", role: .destructive) { auth.signOut() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showLibrary = true } label: {
                        Image(systemName: "books.vertical")
                    }
                }
            }
            .sheet(isPresented: $showLibrary) {
                NavigationStack {
                    DreamLibraryView(
                        viewModel: DreamLibraryViewModel(store: vm.store),
                        shouldRefresh: vm.state == .saved
                    )
                }
            }
            .onChange(of: draft) { newValue in
                // first keystroke flips to .recording and greys picker
                if mode == .text && !vm.isTyping && !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    vm.startOrStopText(newValue)
                }
            }
            .navigationDestination(item: $dreamToOpen) { dream in
                DreamEntryView(dream: dream, store: vm.store)
            }
            // 🏁 react to a save
            .onChange(of: vm.lastSavedDream) { dream in
                guard let dream else { return }
                // Use the completed dream directly - it has transcript consolidated
                dreamToOpen = dream
            }
            .onAppear {
                // If we're returning from a completed dream, reset for new recording
                if vm.state == .saved {
                    vm.reset()
                    vm.state = .idle
                }
            }
        }
    }

    // MARK: – helpers

    private func label(for s: CaptureState) -> String {
        switch s {
        case .idle:     "Record a New Dream"
        case .recording:"Recording…"
        case .clipped:   "Successfully recorded!"
        case .saving:   "Saving Dream…"
        case .saved:    "Saved"
        case .failed(let msg): msg
        }
    }

    private func icon(for s: CaptureState) -> String {
        s == .recording ? "stop.circle.fill" : "mic.circle.fill"
    }

    private func color(for s: CaptureState) -> Color {
        s == .recording ? .red : .accentColor
    }
}

#if canImport(UIKit)
extension View {
    /// Programmatically dismisses the on-screen keyboard.
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}
#endif


#if DEBUG                              // compiled only for the canvas / unit tests
import SwiftUI
import Infrastructure
import DomainLogic
import CoreModels

/// A throw-away folder under /tmp so the preview writes nowhere permanent.
private let previewRoot =
    URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("DreamPreview", isDirectory: true)

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {

        // 1.  The macOS build already ships a stubbed AudioRecorderActor that
        //     merely throws; on iOS the real one works with the Info.plist key.
        let recorder = AudioRecorderActor()

        // 2.  FileDreamStore can be pointed at the temp directory; every run
        //     starts with an empty cache and nothing ever leaves /tmp.
        let localStore = FileDreamStore(customRootURL: previewRoot)

        // 3.  RemoteDreamStore is given an inert base URL plus a fresh,
        //     ephemeral URLSession so any accidental request is a quick
        //     “connection refused” rather than a long timeout.
        let auth       = AuthStore()
        let remoteStore = RemoteDreamStore(
            baseURL: URL(string: "http://127.0.0.1")!,
            session: URLSession(configuration: .ephemeral),
            auth: auth
        )

        // 4.  The real SyncingDreamStore still glues the two halves together,
        //     but with these benign endpoints it never reaches the network.
        let syncStore = SyncingDreamStore(local: localStore, remote: remoteStore)

        // 5.  Finally hand everything to the production view-model.
        let vm = CaptureViewModel(recorder: recorder, store: syncStore)

        return ContentView(viewModel: vm)
            .previewDisplayName("Capture (safe preview)")
            .previewDevice("iPhone 15 Pro")
    }
}
#endif


