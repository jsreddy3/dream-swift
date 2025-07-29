import SwiftUI

// MARK: - Shared Views for Dream App

// MARK: - Dream Background View
/// The standard background used throughout the app with gradient and stars
public struct DreamBackground: View {
    public init() {}
    
    public var body: some View {
        ZStack {
            DesignSystem.Colors.backgroundSecondary
                .ignoresSafeArea()
            
            DesignSystem.Gradients.dreamGradient
                .ignoresSafeArea()
            
            StarsBackgroundView()
                .ignoresSafeArea()
        }
    }
}

// MARK: - Floating Orb Background
/// Animated floating orbs for dream-like effects
public struct FloatingOrbsView: View {
    @State private var orbs: [FloatingOrb] = []
    
    public init() {}
    
    public var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSince1970
                
                for orb in orbs {
                    let y = orb.startY + sin(time * orb.speed + orb.phase) * orb.amplitude
                    let opacity = (sin(time * orb.twinkleSpeed) + 1) / 2 * 0.6 + 0.2
                    
                    // Use simpler color fill instead of complex gradient
                    let orbColor = orb.isEmber ? DesignSystem.Colors.ember : DesignSystem.Colors.backgroundPrimary.opacity(0.6)
                    
                    // Draw multiple circles to simulate gradient effect
                    let steps = 5
                    for i in 0..<steps {
                        let factor = CGFloat(i) / CGFloat(steps - 1)
                        let currentSize = orb.size * (1.0 - factor * 0.5)
                        let currentOpacity = opacity * (1.0 - factor * 0.8)
                        
                        context.fill(
                            Path(ellipseIn: CGRect(
                                x: orb.x - currentSize/2,
                                y: y - currentSize/2,
                                width: currentSize,
                                height: currentSize
                            )),
                            with: .color(orbColor.opacity(currentOpacity))
                        )
                    }
                }
            }
        }
        .onAppear {
            orbs = (0..<15).map { _ in
                FloatingOrb(
                    x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                    startY: CGFloat.random(in: 0...UIScreen.main.bounds.height),
                    size: CGFloat.random(in: 80...200),
                    speed: Double.random(in: 0.2...0.5),
                    amplitude: CGFloat.random(in: 20...60),
                    phase: Double.random(in: 0...2 * .pi),
                    twinkleSpeed: Double.random(in: 0.5...1.5),
                    isEmber: Bool.random()
                )
            }
        }
    }
}

private struct FloatingOrb {
    let x: CGFloat
    let startY: CGFloat
    let size: CGFloat
    let speed: Double
    let amplitude: CGFloat
    let phase: Double
    let twinkleSpeed: Double
    let isEmber: Bool
}

// MARK: - Stars Background
public struct StarsBackgroundView: View {
    @State private var stars: [Star] = []
    
    public init() {}
    
    public var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                for star in stars {
                    let opacity = (sin(timeline.date.timeIntervalSince1970 * star.twinkleSpeed) + 1) / 2
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: star.position.x,
                            y: star.position.y,
                            width: star.size,
                            height: star.size
                        )),
                        with: .color(.white.opacity(opacity * 0.9))
                    )
                }
            }
        }
        .onAppear {
            stars = (0..<100).map { _ in
                Star(
                    position: CGPoint(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                    ),
                    size: CGFloat.random(in: DesignSystem.Sizes.starSizeRange),
                    twinkleSpeed: Double.random(in: 0.5...2)
                )
            }
        }
    }
}

struct Star {
    let position: CGPoint
    let size: CGFloat
    let twinkleSpeed: Double
}