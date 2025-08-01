import SwiftUI
import CoreModels
import Infrastructure
import DomainLogic
import Combine
import MessageUI
import UIKit

// MARK: - Main Profile View

public struct ProfileView: View {
    @StateObject private var viewModel: ProfileViewModel
    @State private var scrollOffset: CGFloat = 0
    
    public init(profileStore: RemoteProfileStore, dreamStore: DreamStore) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(
            profileStore: profileStore,
            dreamStore: dreamStore
        ))
    }
    
    public var body: some View {
        ZStack {
            // Background - use standard app background
            DreamBackground()
            
            if viewModel.isLoading && viewModel.userProfile == nil {
                // Initial loading state
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(DesignSystem.Colors.ember)
                    
                    Text("Loading your dream profile...")
                        .font(DesignSystem.Typography.body())
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // Cached data indicator
                        if viewModel.isShowingCachedData {
                            HStack(spacing: 8) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 14))
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                                
                                Text("Showing cached data")
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                                
                                if let cacheAge = viewModel.cacheAge {
                                    Text("• \(cacheAge)")
                                        .font(DesignSystem.Typography.caption())
                                        .foregroundColor(DesignSystem.Colors.textQuaternary)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(DesignSystem.Colors.cardBackground.opacity(0.8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(DesignSystem.Colors.cardBorder, lineWidth: 0.5)
                                    )
                            )
                            .padding(.top, 20)
                            .padding(.bottom, 10)
                        }
                        
                        // Calculation in progress banner
                        if viewModel.isCalculating {
                            HStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                                
                                Text("Analyzing your dreams...")
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(DesignSystem.Colors.ember)
                            .cornerRadius(20)
                            .padding(.top, viewModel.isShowingCachedData ? 10 : 20)
                            .padding(.bottom, 10)
                        }
                        
                        // Hero Section - Dream Keeper
                        DreamArchetypeView(
                            archetype: viewModel.currentArchetype,
                            totalDreams: viewModel.statistics.totalDreams,
                            dreamDates: viewModel.dreamDates
                        )
                            .padding(.top, viewModel.isCalculating ? 40 : 70)
                            .padding(.bottom, 30)
                        
                        // Today's Dream Wisdom
                        DreamInsightsCard(
                            message: viewModel.todayMessage,
                            recentSymbols: viewModel.recentSymbols
                        )
                        .padding(.horizontal, 24)
                        .padding(.bottom, 30)
                        
                        // Emotional Landscape
                        if !viewModel.emotionalData.isEmpty {
                            EmotionalLandscapeView(emotions: viewModel.emotionalData)
                                .frame(height: 200)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 30)
                        }
                        
                        // Dream Statistics
                        DreamStatisticsView(statistics: viewModel.statistics)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 30)
                        
                        // Send Feedback Button
                        FeedbackButtonView()
                            .padding(.horizontal, 24)
                            .padding(.bottom, 100) // Space for tab bar
                        
                        // Error state
                        if viewModel.error != nil {
                            VStack(spacing: 12) {
                                Image(systemName: "wifi.slash")
                                    .font(.system(size: 40))
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                                
                                Text("Couldn't load profile")
                                    .font(DesignSystem.Typography.bodyMedium())
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                
                                Text("Showing local data")
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                            }
                            .padding()
                            .glassCard()
                            .padding(.horizontal, 24)
                            .padding(.bottom, 20)
                        }
                    }
                    .background(GeometryReader { geo in
                        Color.clear.preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geo.frame(in: .named("scroll")).origin.y
                        )
                    })
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                }
            }
        }
        .ignoresSafeArea()
        .task {
            await viewModel.loadProfile()
        }
    }
}

// MARK: - Dream Archetype View

struct DreamArchetypeView: View {
    let archetype: DreamArchetype
    let totalDreams: Int
    let dreamDates: [Date]
    @State private var particleSystem = ParticleSystem()
    
    var body: some View {
        VStack(spacing: 20) {
            // Archetype Avatar with particles
            ZStack {
                // Particle effect
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        particleSystem.update(at: timeline.date)
                        particleSystem.draw(in: &context, size: size)
                    }
                }
                .frame(width: DesignSystem.Sizes.profileImageLarge, height: DesignSystem.Sizes.profileImageLarge)
                
                // Avatar
                Circle()
                    .fill(DesignSystem.Gradients.emberGlow)
                    .frame(width: DesignSystem.Sizes.profileImageMedium, height: DesignSystem.Sizes.profileImageMedium)
                    .overlay(
                        Text(archetype.symbol)
                            .font(.system(size: 50))
                    )
                    .shadow(color: DesignSystem.Colors.ember.opacity(0.6), radius: 20)
            }
            
            // Archetype Name
            Text(archetype.name)
                .font(DesignSystem.Typography.title2())
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            // Total Dreams
            Text("\(totalDreams) \(totalDreams == 1 ? "dream" : "dreams") recorded")
                .font(DesignSystem.Typography.bodyMedium())
                .foregroundColor(DesignSystem.Colors.textTertiary)
            
            // Academic reference (subtle)
            Text("\(archetype.researcher) • \(archetype.theory)")
                .font(DesignSystem.Typography.caption())
                .foregroundColor(DesignSystem.Colors.textQuaternary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // Dream Pattern Chart
            DreamPatternChart(dreamDates: dreamDates)
                .frame(height: 60)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Dream Pattern Chart

struct DreamPatternChart: View {
    let days = 30
    let dreamDates: [Date]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<days, id: \.self) { day in
                Circle()
                    .fill(getDotColor(for: day))
                    .frame(width: DesignSystem.Sizes.iconSmall, height: DesignSystem.Sizes.iconSmall)
            }
        }
    }
    
    private func getDotColor(for day: Int) -> Color {
        // Create pattern in real-time based on current dreamDates
        let calendar = Calendar.current
        let today = Date()
        
        // Convert day index to date (0 = 30 days ago, 29 = today)
        let daysAgo = days - day - 1
        
        // Check if any dream falls on this day
        for dreamDate in dreamDates {
            let daysBetween = calendar.dateComponents([.day], from: dreamDate, to: today).day ?? 0
            if daysBetween == daysAgo {
                return DesignSystem.Colors.ember
            }
        }
        
        return DesignSystem.Colors.textPrimary.opacity(0.1)
    }
}

// MARK: - Dream Insights Card

struct DreamInsightsCard: View {
    let message: DreamMessage
    let recentSymbols: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Tonight's Portal")
                .font(DesignSystem.Typography.headline())
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            VStack(alignment: .leading, spacing: 12) {
                // Main message
                Text(message.message)
                    .font(DesignSystem.Typography.body())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Scientific inspiration in italics
                Text(message.inspiration)
                    .font(DesignSystem.Typography.captionItalic())
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if !recentSymbols.isEmpty {
                HStack(spacing: 12) {
                    Text("Recent Symbols:")
                        .font(DesignSystem.Typography.caption())
                        .foregroundColor(DesignSystem.Colors.textQuaternary)
                    
                    ForEach(recentSymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.system(size: 20))
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(DesignSystem.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(DesignSystem.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - Emotional Landscape View

struct EmotionalLandscapeView: View {
    let emotions: [EmotionData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Emotional Tides")
                .font(DesignSystem.Typography.headline())
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .padding(.horizontal, 24)
            
            // Wave chart placeholder
            ZStack {
                ForEach(emotions) { emotion in
                    WaveShape(emotion: emotion)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: emotion.color).opacity(0.6),
                                    Color(hex: emotion.color).opacity(0.2)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
            .frame(height: 150)
        }
    }
}

// MARK: - Dream Statistics View

struct DreamStatisticsView: View {
    let statistics: DreamStatistics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Dream Insights")
                .font(DesignSystem.Typography.headline())
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            VStack(spacing: 16) {
                StatRow(label: "Total Dreams", value: "\(statistics.totalDreams)")
                StatRow(label: "Longest Dream", value: statistics.longestDream)
                
                if !statistics.topThemes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dream Themes")
                            .font(DesignSystem.Typography.bodyMedium())
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                        
                        ForEach(statistics.topThemes) { theme in
                            HStack {
                                Text(theme.name)
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundColor(DesignSystem.Colors.textQuaternary)
                                
                                Spacer()
                                
                                Text("\(theme.percentage)%")
                                    .font(DesignSystem.Typography.captionMedium())
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }
                }
            }
            .padding(DesignSystem.Spacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(DesignSystem.Colors.cardBackground)
            )
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(DesignSystem.Typography.bodySmall())
                .foregroundColor(DesignSystem.Colors.textTertiary)
            
            Spacer()
            
            Text(value)
                .font(DesignSystem.Typography.bodyMedium())
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
    }
}

// MARK: - Helper Types

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct WaveShape: Shape {
    let emotion: EmotionData
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midHeight = height * CGFloat(emotion.intensity)
        
        path.move(to: CGPoint(x: 0, y: midHeight))
        
        for x in stride(from: 0, to: width, by: 5) {
            let relativeX = x / width
            let y = midHeight + sin(relativeX * .pi * 4 + emotion.phase) * 20
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        
        return path
    }
}


// MARK: - Particle System

class ParticleSystem {
    private var particles: [Particle] = []
    private let maxParticles = 30
    
    func update(at date: Date) {
        // Remove dead particles
        particles.removeAll { $0.lifetime <= 0 }
        
        // Add new particles
        if particles.count < maxParticles {
            particles.append(Particle())
        }
        
        // Update existing particles
        for i in particles.indices {
            particles[i].update()
        }
    }
    
    func draw(in context: inout GraphicsContext, size: CGSize) {
        for particle in particles {
            let center = CGPoint(
                x: size.width / 2 + particle.position.x,
                y: size.height / 2 + particle.position.y
            )
            
            context.fill(
                Path(ellipseIn: CGRect(
                    x: center.x - particle.size / 2,
                    y: center.y - particle.size / 2,
                    width: particle.size,
                    height: particle.size
                )),
                with: .color(.white.opacity(particle.opacity))
            )
        }
    }
}

struct Particle {
    var position: CGPoint
    var velocity: CGVector
    var size: CGFloat
    var lifetime: Double
    var opacity: Double {
        lifetime / 100
    }
    
    init() {
        let angle = Double.random(in: 0...(2 * .pi))
        let speed = Double.random(in: 0.2...1)
        
        position = .zero
        velocity = CGVector(
            dx: cos(angle) * speed,
            dy: sin(angle) * speed
        )
        size = CGFloat.random(in: 2...6)
        lifetime = 100
    }
    
    mutating func update() {
        position.x += velocity.dx
        position.y += velocity.dy
        lifetime -= 1
    }
}


// MARK: - Feedback Button View

struct FeedbackButtonView: View {
    @State private var showingMessageComposer = false
    @State private var messageResult: Result<MessageComposeResult, Error>? = nil
    @State private var showingFallbackAlert = false
    @State private var isPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Help us improve")
                .font(DesignSystem.Typography.headline())
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Button(action: {
                print("DEBUG: Feedback button tapped")
                let canSendText = MFMessageComposeViewController.canSendText()
                print("DEBUG: Can send text: \(canSendText)")
                
                if canSendText {
                    print("DEBUG: Opening message composer")
                    showingMessageComposer = true
                } else {
                    print("DEBUG: Messages not available, showing fallback alert")
                    showingFallbackAlert = true
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "message")
                        .font(.system(size: 20))
                        .foregroundColor(DesignSystem.Colors.ember)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Send Feedback")
                            .font(DesignSystem.Typography.bodyMedium())
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text("Willing to send us feedback?")
                            .font(DesignSystem.Typography.caption())
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.textQuaternary)
                }
                .padding(DesignSystem.Spacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(DesignSystem.Colors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(DesignSystem.Colors.cardBorder, lineWidth: 0.5)
                        )
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .opacity(isPressed ? 0.8 : 1.0)
            }
            .buttonStyle(PlainButtonStyle())
            .contentShape(Rectangle()) // Ensure entire button area is tappable
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
            .sheet(isPresented: $showingMessageComposer) {
                FeedbackMessageComposer(result: $messageResult)
            }
            .alert("Text Feedback", isPresented: $showingFallbackAlert) {
                Button("Copy Phone Number") {
                    UIPasteboard.general.string = "+1 707-653-6763"
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Messages app is not available. You can copy our phone number and send feedback manually:\n\n+1 707-653-6763")
            }
        }
    }
}

// MARK: - Message Composer

struct FeedbackMessageComposer: UIViewControllerRepresentable {
    @Binding var result: Result<MessageComposeResult, Error>?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let messageComposer = MFMessageComposeViewController()
        messageComposer.messageComposeDelegate = context.coordinator
        
        // Pre-fill phone number
        messageComposer.recipients = ["+17076536763"]
        
        // Pre-fill message body
        let messageBody = "Hi! I'm a beta tester of Dream App. Here's some feedback I had: "
        messageComposer.body = messageBody
        
        return messageComposer
    }
    
    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    @MainActor
    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        var parent: FeedbackMessageComposer
        
        init(_ parent: FeedbackMessageComposer) {
            self.parent = parent
        }
        
        nonisolated func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            Task { @MainActor in
                print("DEBUG: Message composer finished with result: \(result.rawValue)")
                parent.result = .success(result)
                
                // Log the result for debugging
                switch result {
                case .cancelled:
                    print("DEBUG: User cancelled message")
                case .sent:
                    print("DEBUG: Message sent successfully")
                case .failed:
                    print("DEBUG: Message failed to send")
                @unknown default:
                    print("DEBUG: Unknown message result")
                }
                
                parent.dismiss()
            }
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}