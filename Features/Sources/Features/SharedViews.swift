import SwiftUI

// MARK: - Shared Views for Dream App

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