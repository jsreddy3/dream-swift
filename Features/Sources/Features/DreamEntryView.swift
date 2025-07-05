import SwiftUI
import Infrastructure
import DomainLogic
import CoreModels

// MARK: ‑ View

struct DreamEntryView: View {
    @StateObject private var vm: DreamEntryViewModel
    @FocusState private var addlInfoFocused: Bool
    
    @Environment(\.dismiss) private var dismiss

    init(dream: Dream, store: DreamStore) {
        _vm = StateObject(wrappedValue: DreamEntryViewModel(dream: dream, store: store))
    }

    var body: some View {
        ZStack {
            if let err = vm.errorMessage {
                    // ───────────── failed or timed-out ─────────────
                    VStack(spacing: 16) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(err)
                            .font(.custom("Avenir-Medium", size: 18))
                            .multilineTextAlignment(.center)
                        Button("Close") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if vm.dream.summary == nil {
                    // ───────────── still working ─────────────
                    VStack(spacing: 24) {
                        LoopingVideoView(named: "campfire_fullrange")
                            .frame(width: 240, height: 240)
                            .cornerRadius(40)
                        Text("Interpreting your dream…")
                            .font(.custom("Avenir-Medium", size: 20))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        // Title
                        Text(vm.dream.title)
                            .font(.custom("Avenir-Heavy", size: 32))
                            .padding(.top, 8)

                        // Interpret button (only if analysis missing)
                        if vm.dream.analysis == nil {
                            Button {
                                Task { await vm.interpret() }
                            } label: {
                                Label("Interpret", systemImage: "sparkles")
                                    .font(.custom("Avenir-Medium", size: 16))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Capsule().fill(Color.accentColor))
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)
                        }

                        // Collapsible summary
                        CollapsibleText(text: vm.dream.summary!)

                        Divider()

                        // Additional info (future editable area)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Additional Info")
                                .font(.custom("Avenir-Medium", size: 18))
                                .foregroundColor(.secondary)

                            ZStack(alignment: .topLeading) {
                                TextEditor(text: Binding(
                                    get: { vm.dream.additionalInfo ?? "" },
                                    set: { _ in /* not persisted yet */ }
                                ))
                                .focused($addlInfoFocused)
                                .frame(minHeight: 120)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))

                                if (vm.dream.additionalInfo ?? "").isEmpty && !addlInfoFocused {
                                    Text("Tap to add…")
                                        .font(.custom("Avenir-Book", size: 16))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                }
                            }
                        }

                        // Analysis section (if available)
                        if let analysis = vm.dream.analysis {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Interpretation")
                                    .font(.custom("Avenir-Medium", size: 18))
                                    .foregroundColor(.secondary)
                                Text(analysis)
                                    .font(.custom("Avenir-Book", size: 18))
                            }
                        }
                    }
                    .padding(24)
                }
            }

            // Busy overlay (for interpretation / manual refresh)
            if vm.isBusy {
                Color.black.opacity(0.25).ignoresSafeArea()
                ProgressView().scaleEffect(1.6)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: ‑ CollapsibleText ------------------------------------------------

private struct CollapsibleText: View {
    let text: String
    @State private var expanded = false
    private let lineLimit = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text)
                .font(.custom("Avenir-Book", size: 18))
                .lineLimit(expanded ? nil : lineLimit)
                .animation(.easeInOut, value: expanded)

            if text.count > 180 {
                Button(expanded ? "Show Less" : "Show More") {
                    withAnimation { expanded.toggle() }
                }
                .font(.custom("Avenir-Medium", size: 14))
                .foregroundColor(.accentColor)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray6)))
    }
}

// MARK: ‑ Preview --------------------------------------------------------

#if DEBUG
#Preview {
    let sample = Dream(
        title: "Flying Over the Campfire",
        transcript: "I was soaring above a campfire in the woods…",
        summary: nil,                       // ← to demo loader
        additionalInfo: nil,
        analysis: nil
    )
    return NavigationStack {
        DreamEntryView(dream: sample, store: StubStore())
    }
}

private struct StubStore: DreamStore {
    func insertNew(_ dream: Dream) async throws {}
    func appendSegment(dreamID: UUID, segment: Segment) async throws {}
    func removeSegment(dreamID: UUID, segmentID: UUID) async throws {}
    func markCompleted(_ id: UUID) async throws {}
    func updateTitle(dreamID: UUID, title: String) async throws {}
    func segments(dreamID: UUID) async throws -> [Segment] { [] }
    func allDreams() async throws -> [Dream] { [] }
    func getTranscript(dreamID: UUID) async throws -> String? { nil }
    func getVideoURL(dreamID: UUID) async throws -> URL? { nil }
    func uploads() -> AsyncStream<UploadResult> { .init { _ in } }
    func getDream(_ id: UUID) async throws -> Dream { Dream(title: "Stub") }
    func requestAnalysis(for id: UUID) async throws {}
    func generateSummary(for id: UUID) async throws -> String { "" }
}
#endif
