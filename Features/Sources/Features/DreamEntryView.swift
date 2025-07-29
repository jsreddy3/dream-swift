import SwiftUI
import Infrastructure
import DomainLogic
import CoreModels

// MARK: ‑ View

struct DreamEntryView: View {
    @StateObject private var vm: DreamEntryViewModel
    
    @Environment(\.dismiss) private var dismiss

    init(dream: Dream, store: DreamStore) {
        _vm = StateObject(wrappedValue: DreamEntryViewModel(dream: dream, store: store))
    }

    var body: some View {
        ZStack {
            // Background - matching profile page style
            Color.black.ignoresSafeArea()
            
            // Gradient overlay (warm and welcoming)
            LinearGradient(
                colors: [
                    DesignSystem.Colors.ember.opacity(0.25),
                    DesignSystem.Colors.ember.opacity(0.1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Animated stars background (brighter)
            StarsBackgroundView()
                .opacity(0.5)
                .ignoresSafeArea()
            
            if let err = vm.errorMessage {
                    // ───────────── failed or timed-out ─────────────
                    VStack(spacing: 16) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Text(err)
                            .font(DesignSystem.Typography.subheadline())
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        switch vm.errorAction {
                        case .retry:
                            Button("Try Again") {
                                Task { await vm.interpret() }
                            }
                            .buttonStyle(.borderedProminent)
                        case .wait:
                            Button("OK") {
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                        case .close, .none:
                            Button("Close") {
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                } else if vm.dream.summary == nil {
                    // ───────────── still working ─────────────
                    VStack(spacing: 24) {
                        // Dream interpretation orb
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            DesignSystem.Colors.ember.opacity(0.6),
                                            DesignSystem.Colors.ember.opacity(0.1),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 30,
                                        endRadius: 120
                                    )
                                )
                                .frame(width: 240, height: 240)
                                .blur(radius: 15)
                                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: vm.statusMessage)
                            
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color.black.opacity(0.8),
                                            Color.black.opacity(0.3)
                                        ],
                                        center: .center,
                                        startRadius: 30,
                                        endRadius: 100
                                    )
                                )
                                .frame(width: 200, height: 200)
                            
                            Image(systemName: "sparkles")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                                .symbolEffect(.pulse, value: vm.statusMessage)
                        }
                        Text(vm.statusMessage ?? "Interpreting your dream…")
                            .font(DesignSystem.Typography.headline())
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .animation(.easeInOut(duration: 0.3), value: vm.statusMessage)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        // Title
                        if vm.isEditMode {
                            TextField("Dream Title", text: $vm.editedTitle, axis: .vertical)
                                .font(DesignSystem.Typography.title1())
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(nil)
                                .padding(.top, 8)
                        } else {
                            Text(vm.dream.title)
                                .font(DesignSystem.Typography.title1())
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .padding(.top, 8)
                        }
                        
                        // Date and day
                        Text(formatDate(vm.dream.created_at))
                            .font(DesignSystem.Typography.bodyMedium())
                            .foregroundColor(DesignSystem.Colors.ember)

                        // Interpret button (only if analysis missing)
                        if vm.dream.analysis == nil {
                            Button {
                                Task { await vm.interpret() }
                            } label: {
                                Label("Interpret", systemImage: "sparkles")
                                    .font(DesignSystem.Typography.bodyMedium())
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Capsule().fill(Color.accentColor))
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)
                        }

                        // Collapsible summary
                        if vm.isEditMode {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Dream Summary")
                                    .font(DesignSystem.Typography.subheadline())
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                
                                TextEditor(text: $vm.editedSummary)
                                    .font(DesignSystem.Typography.body())
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                    .frame(minHeight: 120)
                                    .padding(8)
                                    .background(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium).fill(DesignSystem.Colors.cardBackground))
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Dream Summary")
                                    .font(DesignSystem.Typography.subheadline())
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                
                                CollapsibleText(text: vm.dream.summary!)
                            }
                        }

                        Divider()

                        // Analysis section (if available)
                        if let analysis = vm.dream.analysis {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Interpretation")
                                    .font(DesignSystem.Typography.subheadline())
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                Text(analysis)
                                    .font(DesignSystem.Typography.body())
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                            }
                        }
                    }
                    .padding(24)
                }
            }

            // Busy overlay (for interpretation / manual refresh)
            if vm.isBusy && vm.statusMessage != nil {
                // Full screen loading with status messages
                ZStack {
                    Color.black.opacity(0.8).ignoresSafeArea()
                    
                    VStack(spacing: 24) {
                        // Dream interpretation orb
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            DesignSystem.Colors.ember.opacity(0.6),
                                            DesignSystem.Colors.ember.opacity(0.1),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 30,
                                        endRadius: 120
                                    )
                                )
                                .frame(width: 240, height: 240)
                                .blur(radius: 15)
                                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: vm.statusMessage)
                            
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color.black.opacity(0.8),
                                            Color.black.opacity(0.3)
                                        ],
                                        center: .center,
                                        startRadius: 30,
                                        endRadius: 100
                                    )
                                )
                                .frame(width: 200, height: 200)
                            
                            Image(systemName: "sparkles")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                                .symbolEffect(.pulse, value: vm.statusMessage)
                        }
                        
                        Text(vm.statusMessage ?? "Interpreting your dream…")
                            .font(DesignSystem.Typography.headline())
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .animation(.easeInOut(duration: 0.3), value: vm.statusMessage)
                    }
                }
            } else if vm.isBusy {
                // Simple progress overlay for other operations
                Color.black.opacity(0.25).ignoresSafeArea()
                ProgressView().scaleEffect(1.6)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // Format date as "Monday, December 25, 2024"
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: date)
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
                .font(DesignSystem.Typography.body())
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .lineLimit(expanded ? nil : lineLimit)
                .animation(.easeInOut, value: expanded)

            if text.count > 180 {
                Button(expanded ? "Show Less" : "Show More") {
                    withAnimation { expanded.toggle() }
                }
                .font(DesignSystem.Typography.captionMedium())
                .foregroundColor(DesignSystem.Colors.ember)
            }
        }
        .dreamCardStyle()
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
    func markCompleted(_ id: UUID) async throws -> Dream { Dream(id: id, title: "Completed") }
    func updateTitle(dreamID: UUID, title: String) async throws {}
    func updateSummary(dreamID: UUID, summary: String) async throws {}
    func updateTitleAndSummary(dreamID: UUID, title: String, summary: String) async throws {}
    func segments(dreamID: UUID) async throws -> [Segment] { [] }
    func allDreams() async throws -> [Dream] { [] }
    func getTranscript(dreamID: UUID) async throws -> String? { nil }
    func getVideoURL(dreamID: UUID) async throws -> URL? { nil }
    func uploads() -> AsyncStream<UploadResult> { .init { _ in } }
    func getDream(_ id: UUID) async throws -> Dream { Dream(title: "Stub") }
    func requestAnalysis(for id: UUID) async throws {}
    func generateSummary(for id: UUID) async throws -> String { "" }
    func deleteDream(_ id: UUID) async throws {}
}
#endif
