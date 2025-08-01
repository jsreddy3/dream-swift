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
            // Background - use standard app background
            DreamBackground()
            
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
                                .fill(DesignSystem.Gradients.emberGlow)
                                .frame(width: DesignSystem.Sizes.dreamOrbInner, height: DesignSystem.Sizes.dreamOrbInner)
                                .blur(radius: 15)
                                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: vm.statusMessage)
                            
                            Circle()
                                .fill(DesignSystem.Gradients.darkOverlay)
                                .frame(width: DesignSystem.Sizes.dreamOrbIntermediate, height: DesignSystem.Sizes.dreamOrbIntermediate)
                            
                            Image(systemName: "sparkles")
                                .font(.system(size: 60))
                                .foregroundColor(DesignSystem.Colors.textPrimary)
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
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
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
                                    .padding(DesignSystem.Spacing.xxSmall)
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
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Interpretation")
                                    .font(DesignSystem.Typography.subheadline())
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                
                                // Show expanded analysis if available, otherwise show brief analysis
                                if let expandedAnalysis = vm.dream.expandedAnalysis {
                                    FormattedAnalysisView(analysisText: expandedAnalysis)
                                } else {
                                    Text(analysis)
                                        .font(DesignSystem.Typography.body())
                                        .foregroundColor(DesignSystem.Colors.textPrimary)
                                }
                                
                                // Buttons row
                                HStack(spacing: 12) {
                                    // Tell Me More button or loading state
                                    if vm.isExpandingAnalysis {
                                        HStack {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                            Text(vm.expandedAnalysisMessage ?? "Expanding analysis...")
                                                .font(DesignSystem.Typography.caption())
                                                .foregroundColor(DesignSystem.Colors.textTertiary)
                                        }
                                    } else if vm.dream.expandedAnalysis == nil {
                                        Button {
                                            Haptics.light() // Tell Me More tap
                                            Task {
                                                await vm.requestExpandedAnalysis()
                                            }
                                        } label: {
                                            Text("Tell Me More")
                                                .font(DesignSystem.Typography.bodyMedium())
                                                .foregroundColor(DesignSystem.Colors.ember)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(
                                                    Capsule()
                                                        .stroke(DesignSystem.Colors.ember, lineWidth: 1)
                                                )
                                        }
                                    }
                                    
                                    // Visualize button or content policy message
                                    if vm.hasContentPolicyViolation {
                                        Text("This dream contains content that was flagged by our copyright and safety system")
                                            .font(DesignSystem.Typography.caption())
                                            .foregroundColor(DesignSystem.Colors.textTertiary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                    } else if vm.isGeneratingImage {
                                        HStack {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                            Text(vm.imageGenerationMessage ?? "Creating dreamscape...")
                                                .font(DesignSystem.Typography.caption())
                                                .foregroundColor(DesignSystem.Colors.textTertiary)
                                        }
                                    } else if vm.dream.imageUrl == nil {
                                        Button {
                                            Haptics.light() // Visualize tap
                                            Task {
                                                await vm.generateImage()
                                            }
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: "sparkles")
                                                    .font(.system(size: 14))
                                                Text("Visualize")
                                            }
                                            .font(DesignSystem.Typography.bodyMedium())
                                            .foregroundColor(DesignSystem.Colors.ember)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                Capsule()
                                                    .stroke(DesignSystem.Colors.ember, lineWidth: 1)
                                            )
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Generated Image section (if available)
                        if let imageUrl = vm.dream.imageUrl {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Dreamscape")
                                    .font(DesignSystem.Typography.subheadline())
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                
                                // Image display with loading state
                                AsyncImage(url: URL(string: imageUrl)) { phase in
                                    switch phase {
                                    case .empty:
                                        ZStack {
                                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                                                .fill(DesignSystem.Colors.cardBackground)
                                                .frame(height: 300)
                                            
                                            ProgressView()
                                                .scaleEffect(1.2)
                                        }
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(maxHeight: 400)
                                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
                                            .onTapGesture {
                                                vm.showingImageFullscreen = true
                                            }
                                    case .failure(_):
                                        ZStack {
                                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                                                .fill(DesignSystem.Colors.cardBackground)
                                                .frame(height: 300)
                                            
                                            VStack(spacing: 8) {
                                                Image(systemName: "photo")
                                                    .font(.system(size: 48))
                                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                                                Text("Image unavailable")
                                                    .font(DesignSystem.Typography.caption())
                                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                                            }
                                        }
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                
                                if let generatedAt = vm.dream.imageGeneratedAt {
                                    Text("Generated \(generatedAt, style: .relative) ago")
                                        .font(DesignSystem.Typography.caption())
                                        .foregroundColor(DesignSystem.Colors.textTertiary)
                                }
                            }
                        }
                    }
                    .padding(DesignSystem.Spacing.cardPadding)
                }
            }

            // Busy overlay (for interpretation / manual refresh)
            if vm.isBusy && vm.statusMessage != nil {
                // Full screen loading with status messages
                ZStack {
                    DesignSystem.Colors.backgroundPrimary.opacity(DesignSystem.Opacity.prominent).ignoresSafeArea()
                    
                    VStack(spacing: 24) {
                        // Dream interpretation orb
                        ZStack {
                            Circle()
                                .fill(DesignSystem.Gradients.emberGlow)
                                .frame(width: DesignSystem.Sizes.dreamOrbInner, height: DesignSystem.Sizes.dreamOrbInner)
                                .blur(radius: 15)
                                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: vm.statusMessage)
                            
                            Circle()
                                .fill(DesignSystem.Gradients.darkOverlay)
                                .frame(width: DesignSystem.Sizes.dreamOrbIntermediate, height: DesignSystem.Sizes.dreamOrbIntermediate)
                            
                            Image(systemName: "sparkles")
                                .font(.system(size: 60))
                                .foregroundColor(DesignSystem.Colors.textPrimary)
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
                DesignSystem.Colors.overlayDim.ignoresSafeArea()
                ProgressView().scaleEffect(1.6)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Generate share text when view appears
            if vm.shareText == nil {
                vm.generateShareText()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if let shareText = vm.shareText {
                    // Copy button
                    Button {
                        UIPasteboard.general.string = shareText
                        Haptics.light() // Copy feedback
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(DesignSystem.Colors.ember)
                    }
                    
                    // Share button
                    ShareLink(
                        item: shareText,
                        subject: Text(vm.dream.title.isEmpty ? "Dream" : vm.dream.title)
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(DesignSystem.Colors.ember)
                    }
                } else {
                    Button {
                        vm.generateShareText()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(DesignSystem.Colors.ember)
                    }
                }
            }
        }
        .sheet(isPresented: $vm.showingImageFullscreen) {
            if let imageUrl = vm.dream.imageUrl {
                FullscreenImageView(imageUrl: imageUrl)
            }
        }
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

// MARK: ‑ FormattedAnalysisView ------------------------------------------

private struct FormattedAnalysisView: View {
    let analysisText: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(parseAnalysisSections(from: analysisText), id: \.title) { section in
                VStack(alignment: .leading, spacing: 6) {
                    if !section.title.isEmpty {
                        Text(section.title)
                            .font(DesignSystem.Typography.bodyMedium())
                            .foregroundColor(DesignSystem.Colors.ember)
                    }
                    Text(section.content)
                        .font(DesignSystem.Typography.body())
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
            }
        }
    }
    
    private func parseAnalysisSections(from text: String) -> [(title: String, content: String)] {
        var sections: [(title: String, content: String)] = []
        let lines = text.components(separatedBy: .newlines)
        
        var currentTitle = ""
        var currentContent = ""
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("##") {
                // Save previous section if exists
                if !currentContent.isEmpty {
                    sections.append((title: currentTitle, content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
                // Start new section
                currentTitle = trimmed.replacingOccurrences(of: "##", with: "").trimmingCharacters(in: .whitespaces)
                currentContent = ""
            } else if !trimmed.isEmpty {
                if !currentContent.isEmpty {
                    currentContent += " "
                }
                currentContent += trimmed
            }
        }
        
        // Add the last section
        if !currentContent.isEmpty {
            sections.append((title: currentTitle, content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        
        // If no sections were found (no markdown headers), treat the whole text as one section
        if sections.isEmpty && !text.isEmpty {
            sections.append((title: "", content: text))
        }
        
        return sections
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
    func requestAnalysis(for id: UUID, type: AnalysisType? = nil) async throws {}
    func requestExpandedAnalysis(for id: UUID) async throws {}
    func generateSummary(for id: UUID) async throws -> String { "" }
    func deleteDream(_ id: UUID) async throws {}
    func generateImage(for id: UUID) async throws -> Dream { Dream(title: "Stub") }
}


#endif

// MARK: - Fullscreen Image Viewer
struct FullscreenImageView: View {
    let imageUrl: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Dark background
            Color.black.ignoresSafeArea()
            
            // Image with zoom capability
            AsyncImage(url: URL(string: imageUrl)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .onTapGesture {
                            dismiss()
                        }
                case .failure(_):
                    VStack(spacing: 16) {
                        Image(systemName: "photo")
                            .font(.system(size: 64))
                            .foregroundColor(.gray)
                        Text("Failed to load image")
                            .foregroundColor(.gray)
                    }
                @unknown default:
                    EmptyView()
                }
            }
            
            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white, .gray.opacity(0.7))
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
}
