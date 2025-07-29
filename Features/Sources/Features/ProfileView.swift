import SwiftUI
import CoreModels
import Infrastructure
import DomainLogic

// MARK: - Main Profile View

public struct ProfileView: View {
    @StateObject private var viewModel: ProfileViewModel
    @State private var scrollOffset: CGFloat = 0
    
    public init(store: DreamStore) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(store: store))
    }
    
    public var body: some View {
        ZStack {
            // Background
            backgroundGradient
            
            ScrollView {
                VStack(spacing: 0) {
                    // Hero Section - Dream Keeper
                    DreamArchetypeView(archetype: viewModel.currentArchetype)
                        .padding(.top, 50)
                        .padding(.bottom, 30)
                    
                    // Today's Dream Wisdom
                    DreamInsightsCard(
                        message: viewModel.todayMessage,
                        recentSymbols: viewModel.recentSymbols
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
                    
                    // Emotional Landscape
                    EmotionalLandscapeView(emotions: viewModel.emotionalData)
                        .frame(height: 200)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 30)
                    
                    // Dream Statistics
                    DreamStatisticsView(statistics: viewModel.statistics)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 100) // Space for tab bar
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
        .ignoresSafeArea()
        .task {
            await viewModel.loadProfile()
        }
    }
    
    private var backgroundGradient: some View {
        ZStack {
            Color.black
            
            // Archetype-specific gradient
            LinearGradient(
                colors: viewModel.currentArchetype.colors.map { Color(hex: $0).opacity(0.3) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Animated stars
            StarsBackgroundView()
                .opacity(0.5)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Dream Archetype View

struct DreamArchetypeView: View {
    let archetype: DreamArchetype
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
                .frame(width: 150, height: 150)
                
                // Avatar
                Circle()
                    .fill(
                        RadialGradient(
                            colors: archetype.colors.map { Color(hex: $0) },
                            center: .center,
                            startRadius: 5,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .overlay(
                        Text(archetype.symbol)
                            .font(.system(size: 50))
                    )
                    .shadow(color: Color(hex: archetype.colors.first!).opacity(0.6), radius: 20)
            }
            
            // Archetype Name
            Text(archetype.name)
                .font(.custom("Avenir-Heavy", size: 28))
                .foregroundColor(.white)
            
            // Dream Streak
            Text("15 nights of dreams")
                .font(.custom("Avenir-Medium", size: 16))
                .foregroundColor(.white.opacity(0.7))
            
            // Dream Pattern Chart
            DreamPatternChart()
                .frame(height: 60)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Dream Pattern Chart

struct DreamPatternChart: View {
    let days = 30
    @State private var dreamData: [Bool] = []
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<days, id: \.self) { day in
                Circle()
                    .fill(dreamData.indices.contains(day) && dreamData[day] 
                        ? Color.white 
                        : Color.white.opacity(0.2))
                    .frame(width: 8, height: 8)
            }
        }
        .onAppear {
            // Mock data - replace with real dream dates
            dreamData = (0..<days).map { _ in Bool.random() }
        }
    }
}

// MARK: - Dream Insights Card

struct DreamInsightsCard: View {
    let message: String
    let recentSymbols: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tonight's Portal")
                .font(.custom("Avenir-Heavy", size: 20))
                .foregroundColor(.white)
            
            Text(message)
                .font(.custom("Avenir-Book", size: 16))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            if !recentSymbols.isEmpty {
                HStack(spacing: 12) {
                    Text("Recent Symbols:")
                        .font(.custom("Avenir-Medium", size: 14))
                        .foregroundColor(.white.opacity(0.6))
                    
                    ForEach(recentSymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.system(size: 24))
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.1))
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
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
                .font(.custom("Avenir-Heavy", size: 20))
                .foregroundColor(.white)
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
                .font(.custom("Avenir-Heavy", size: 20))
                .foregroundColor(.white)
            
            VStack(spacing: 16) {
                StatRow(label: "Total Dreams", value: "\(statistics.totalDreams)")
                StatRow(label: "Longest Dream", value: statistics.longestDream)
                
                if !statistics.topThemes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dream Themes")
                            .font(.custom("Avenir-Medium", size: 16))
                            .foregroundColor(.white.opacity(0.7))
                        
                        ForEach(statistics.topThemes) { theme in
                            HStack {
                                Text(theme.name)
                                    .font(.custom("Avenir-Book", size: 14))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Spacer()
                                
                                Text("\(theme.percentage)%")
                                    .font(.custom("Avenir-Medium", size: 14))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.1))
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
                .font(.custom("Avenir-Book", size: 16))
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            Text(value)
                .font(.custom("Avenir-Medium", size: 16))
                .foregroundColor(.white)
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