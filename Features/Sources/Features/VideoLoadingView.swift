import SwiftUI

// MARK: - Video Loading View

struct VideoLoadingView: View {
    let message: String
    
    init(message: String = "Loading your dream profile...") {
        self.message = message
    }
    
    var body: some View {
        ZStack {
            // Video background
            LoopingVideoView(named: "clouds_loading", muted: true)
                .ignoresSafeArea()
                .overlay(
                    // Dark overlay to ensure text readability
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                )
            
            // Content overlay
            VStack(spacing: 24) {
                // Animated progress indicator
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 3)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            AngularGradient(
                                colors: [Color.white, Color.white.opacity(0.5)],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: UUID())
                        .onAppear {
                            // Trigger animation
                        }
                }
                
                // Loading message
                Text(message)
                    .font(DesignSystem.Typography.body())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            }
        }
    }
}

// MARK: - Enhanced Profile Loading View

struct ProfileVideoLoadingView: View {
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        ZStack {
            // Video background
            LoopingVideoView(named: "clouds_loading", muted: true)
                .ignoresSafeArea()
                .overlay(
                    // Gradient overlay for better text contrast
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.6),
                            Color.black.opacity(0.3),
                            Color.black.opacity(0.6)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
            
            // Content
            VStack(spacing: 32) {
                // Dream icon with glow effect
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    DesignSystem.Colors.ember.opacity(0.4),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 30,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .scaleEffect(1.0 + sin(rotationAngle * 0.02) * 0.1)
                    
                    // Main circle
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: [
                                    DesignSystem.Colors.ember,
                                    DesignSystem.Colors.ember.opacity(0.7),
                                    Color.white.opacity(0.8),
                                    DesignSystem.Colors.ember.opacity(0.7),
                                    DesignSystem.Colors.ember
                                ],
                                center: .center
                            )
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(rotationAngle))
                        .overlay(
                            // Dream symbol
                            Text("🌙")
                                .font(.system(size: 50))
                        )
                        .shadow(color: DesignSystem.Colors.ember.opacity(0.6), radius: 20)
                }
                
                // Loading text with fade animation
                VStack(spacing: 12) {
                    Text("Loading your dream profile...")
                        .font(DesignSystem.Typography.title3())
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    
                    Text("Analyzing your dreams and weaving your story...")
                        .font(DesignSystem.Typography.body())
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                        .padding(.horizontal, 40)
                }
                .opacity(0.8 + sin(rotationAngle * 0.03) * 0.2)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }
}

// MARK: - Onboarding Video Loading View

struct OnboardingVideoLoadingView: View {
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Video background
            LoopingVideoView(named: "clouds_loading", muted: true)
                .ignoresSafeArea()
                .overlay(
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                )
            
            // Loading content
            VStack(spacing: 28) {
                // Pulsing ember circle
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    DesignSystem.Colors.ember,
                                    DesignSystem.Colors.ember.opacity(0.3)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 60
                            )
                        )
                        .frame(width: 100, height: 100)
                        .scaleEffect(pulseScale)
                        .opacity(2 - pulseScale)
                    
                    Text("🔥")
                        .font(.system(size: 48))
                        .shadow(color: DesignSystem.Colors.ember.opacity(0.6), radius: 30)
                }
                
                Text("Loading…")
                    .font(DesignSystem.Typography.title3())
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseScale = 1.5
            }
        }
    }
}

#Preview("Video Loading") {
    VideoLoadingView()
}

#Preview("Profile Loading") {
    ProfileVideoLoadingView()
}

#Preview("Onboarding Loading") {
    OnboardingVideoLoadingView()
}