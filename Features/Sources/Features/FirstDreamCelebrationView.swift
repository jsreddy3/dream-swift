import SwiftUI
import Infrastructure

struct FirstDreamCelebrationView: View {
    @Binding var isPresented: Bool
    @State private var showContent = false
    @State private var confettiAnimation = false
    @State private var textScale: CGFloat = 0.1
    @State private var buttonOpacity: Double = 0
    @State private var showNotificationSetup = false
    let wakeTime: String?
    
    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture { } // Prevent dismissal by tapping background
            
            // Confetti particles
            ZStack {
                ForEach(0..<80) { index in
                    ConfettiParticle(
                        color: confettiColors[index % confettiColors.count],
                        delay: Double(index) * 0.01
                    )
                    .opacity(confettiAnimation ? 1 : 0)
                }
            }
            
            // Main content
            VStack(spacing: 32) {
                // Emoji and title
                VStack(spacing: 16) {
                    Text("🎉")
                        .font(.system(size: 80))
                        .scaleEffect(textScale)
                    
                    Text("Congratulations!")
                        .font(DesignSystem.Typography.displayLarge())
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .scaleEffect(textScale)
                    
                    Text("You've recorded your first dream")
                        .font(DesignSystem.Typography.title3())
                        .foregroundColor(DesignSystem.Colors.ember)
                        .scaleEffect(textScale)
                }
                
                // Message
                VStack(spacing: 16) {
                    Text("Every dream is a window into your subconscious")
                        .font(DesignSystem.Typography.subheadline())
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    Text("Come back tomorrow to continue building your dream profile and unlock deeper insights about yourself")
                        .font(DesignSystem.Typography.body())
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 32)
                .opacity(buttonOpacity)
                
                // Continue button
                Button {
                    // Track dismissal
                    AnalyticsService.shared.track(.firstDreamCelebrationDismissed)
                    
                    // Check if notifications have already been set up
                    if UserDefaults.standard.bool(forKey: "hasSetupFirstDreamNotifications") {
                        // Already set up, just dismiss
                        withAnimation(.easeOut(duration: 0.3)) {
                            isPresented = false
                        }
                    } else {
                        // Show notification setup
                        showNotificationSetup = true
                    }
                } label: {
                    Text("Continue Your Journey")
                        .font(DesignSystem.Typography.subheadline())
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Gradients.dreamGradient)
                        )
                }
                .opacity(buttonOpacity)
            }
            .padding()
        }
        .onAppear {
            startAnimations()
            
            // Track showing
            AnalyticsService.shared.track(.firstDreamCelebrationShown)
            
            // Haptic feedback
            Haptics.success() // Celebration haptic
        }
        .fullScreenCover(isPresented: $showNotificationSetup) {
            FirstDreamNotificationSetupView(isPresented: $showNotificationSetup, wakeTime: wakeTime)
        }
        .onChange(of: showNotificationSetup) { isShowing in
            if !isShowing {
                // When notification setup is dismissed, also dismiss celebration
                withAnimation(.easeOut(duration: 0.3)) {
                    isPresented = false
                }
            }
        }
    }
    
    private func startAnimations() {
        // Confetti starts immediately
        withAnimation(.easeOut(duration: 0.5)) {
            confettiAnimation = true
        }
        
        // Text scales up with bounce
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0)) {
            textScale = 1.0
        }
        
        // Message and button fade in after text
        withAnimation(.easeIn(duration: 0.5).delay(0.5)) {
            buttonOpacity = 1.0
        }
    }
    
    private let confettiColors: [Color] = [
        DesignSystem.Colors.ember,
        DesignSystem.Colors.ember.opacity(0.8),
        Color.yellow,
        Color.yellow.opacity(0.8),
        Color.orange,
        Color.pink,
        Color.purple.opacity(0.8),
        Color.blue.opacity(0.8),
        Color.green.opacity(0.8),
        DesignSystem.Colors.textPrimary.opacity(0.9)
    ]
}

// MARK: - Confetti Particle

struct ConfettiParticle: View {
    let color: Color
    let delay: Double
    
    // Random starting position across the screen width, slightly above center
    @State private var offsetY: CGFloat
    @State private var offsetX: CGFloat
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1
    
    private let size = CGFloat.random(in: 8...16)
    private let shape = Int.random(in: 0...2)
    private let horizontalSpread = CGFloat.random(in: -150...150)
    private let verticalSpeed = CGFloat.random(in: 0.8...1.2)
    
    init(color: Color, delay: Double) {
        self.color = color
        self.delay = delay
        // Start from random position across the screen width, slightly above center
        let screenWidth = UIScreen.main.bounds.width
        self._offsetX = State(initialValue: CGFloat.random(in: -screenWidth/3...screenWidth/3))
        self._offsetY = State(initialValue: -50)
    }
    
    var body: some View {
        Group {
            switch shape {
            case 0:
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
            case 1:
                Rectangle()
                    .fill(color)
                    .frame(width: size, height: size * 0.6)
            default:
                ConfettiStar(corners: 5, smoothness: 0.5)
                    .fill(color)
                    .frame(width: size, height: size)
            }
        }
        .rotationEffect(.degrees(rotation))
        .offset(x: offsetX, y: offsetY)
        .opacity(opacity)
        .onAppear {
            // Initial burst upward and outward
            withAnimation(.easeOut(duration: 0.4).delay(delay)) {
                offsetY -= CGFloat.random(in: 50...150)
                offsetX += horizontalSpread * 0.5
            }
            
            // Then fall down with gravity
            withAnimation(.easeIn(duration: 2.5).delay(delay + 0.4)) {
                offsetY = UIScreen.main.bounds.height * verticalSpeed
                offsetX += horizontalSpread
                rotation = Double.random(in: 360...720)
            }
            
            // Fade out near the end
            withAnimation(.easeIn(duration: 0.5).delay(delay + 2.4)) {
                opacity = 0
            }
        }
    }
}

// MARK: - Star Shape

struct ConfettiStar: Shape {
    let corners: Int
    let smoothness: CGFloat
    
    func path(in rect: CGRect) -> Path {
        guard corners >= 2 else { return Path() }
        
        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        let angle = .pi * 2 / CGFloat(corners * 2)
        let innerRadius = min(rect.width, rect.height) / 2 * smoothness
        let outerRadius = min(rect.width, rect.height) / 2
        
        var path = Path()
        
        for i in 0..<corners * 2 {
            let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
            let x = center.x + radius * cos(angle * CGFloat(i) - .pi / 2)
            let y = center.y + radius * sin(angle * CGFloat(i) - .pi / 2)
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview {
    FirstDreamCelebrationView(isPresented: .constant(true), wakeTime: "07:00")
        .background(Color.black)
}