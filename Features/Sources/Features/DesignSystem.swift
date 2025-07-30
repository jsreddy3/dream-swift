import SwiftUI

// MARK: - Dream App Design System
// This file centralizes all design tokens to ensure consistency across the app.
// All values have been carefully audited to match existing designs exactly.

public enum DesignSystem {
    
    // MARK: - Colors
    public enum Colors {
        // Primary brand color
        public static let ember = Color(red: 255/255, green: 145/255, blue: 0/255) // #FF9100
        
        // Background colors
        public static let campfireBg = Color(red: 33/255, green: 24/255, blue: 21/255)
        public static let campfireCard = Color(red: 54/255, green: 37/255, blue: 32/255)
        
        // Text colors
        public static let textPrimary = Color.white
        public static let textSecondary = Color.white.opacity(0.8)
        public static let textTertiary = Color.white.opacity(0.7)
        public static let textQuaternary = Color.white.opacity(0.6)
        
        // UI element colors
        public static let cardBackground = Color.white.opacity(0.15)
        public static let cardBorder = Color.white.opacity(0.25)
        public static let overlayDim = Color.black.opacity(0.4)
        public static let overlayMedium = Color.black.opacity(0.5)
        
        // System colors used in specific contexts
        public static let systemYellow = Color.yellow
        public static let systemGreen = Color(red: 139/255, green: 195/255, blue: 74/255)
        public static let systemPurple = Color.purple
        public static let systemPink = Color.pink
        
        // Background layers
        public static let backgroundPrimary = Color.black
        public static let backgroundSecondary = Color(white: 0.15)
        public static let backgroundTertiary = campfireBg
        
        // Gradient colors for dream theme
        public static let gradientEmber = ember.opacity(0.6)
        public static let gradientPurple = systemPurple.opacity(0.3)
        public static let gradientPink = systemPink.opacity(0.2)
    }
    
    // MARK: - Typography
    public enum Typography {
        // Font families - Iowan Old Style (Bitstream)
        // Mapping: Avenir -> Iowan Old Style
        // Heavy -> Black, Medium -> Bold, Book -> Roman
        public static let fontFamilyBase = "IowanOldStyleBT-Roman"
        public static let fontFamilyHeavy = "IowanOldStyleBT-Black"
        public static let fontFamilyMedium = "IowanOldStyleBT-Bold"
        public static let fontFamilyBook = "IowanOldStyleBT-Roman"
        
        // Fallback to Avenir if custom fonts fail to load
        private static let fallbackBase = "Avenir"
        private static let fallbackHeavy = "Avenir-Heavy"
        private static let fallbackMedium = "Avenir-Medium"
        private static let fallbackBook = "Avenir-Book"
        
        // Helper to create font with fallback
        private static func customFont(_ name: String, fallback: String, size: CGFloat) -> Font {
            if UIFont(name: name, size: size) != nil {
                return .custom(name, size: size)
            } else {
                print("⚠️ Font '\(name)' not found, falling back to '\(fallback)'")
                return .custom(fallback, size: size)
            }
        }
        
        // Font styles with adjusted sizes for serif readability
        public static func largeTitle() -> Font {
            customFont(fontFamilyHeavy, fallback: fallbackHeavy, size: 40)
        }
        
        public static func title1() -> Font {
            customFont(fontFamilyHeavy, fallback: fallbackHeavy, size: 30)
        }
        
        public static func title2() -> Font {
            customFont(fontFamilyHeavy, fallback: fallbackHeavy, size: 26)
        }
        
        public static func title3() -> Font {
            customFont(fontFamilyMedium, fallback: fallbackMedium, size: 22)
        }
        
        public static func headline() -> Font {
            customFont(fontFamilyMedium, fallback: fallbackMedium, size: 19)
        }
        
        public static func subheadline() -> Font {
            customFont(fontFamilyMedium, fallback: fallbackMedium, size: 17)
        }
        
        public static func body() -> Font {
            customFont(fontFamilyBook, fallback: fallbackBook, size: 17)
        }
        
        public static func bodyMedium() -> Font {
            customFont(fontFamilyMedium, fallback: fallbackMedium, size: 15)
        }
        
        public static func bodySmall() -> Font {
            customFont(fontFamilyBook, fallback: fallbackBook, size: 15)
        }
        
        public static func caption() -> Font {
            customFont(fontFamilyBook, fallback: fallbackBook, size: 13)
        }
        
        public static func captionMedium() -> Font {
            customFont(fontFamilyMedium, fallback: fallbackMedium, size: 13)
        }
        
        // Special sizes
        public static func displayLarge() -> Font {
            customFont(fontFamilyMedium, fallback: fallbackMedium, size: 28)
        }
        
        // System fonts for icons
        public static func systemIcon() -> Font {
            .system(size: 48)
        }
        
        public static func systemIconLarge() -> Font {
            .system(size: 64)
        }
        
        public static func systemIconMedium() -> Font {
            .system(size: 24)
        }
        
        public static func systemButton() -> Font {
            .system(size: 18, weight: .medium)
        }
        
        public static func systemLabel() -> Font {
            .system(size: 14, weight: .semibold)
        }
        
        // Default app font
        public static func defaultFont() -> Font {
            customFont(fontFamilyBase, fallback: fallbackBase, size: 16)
        }
    }
    
    // MARK: - Spacing
    public enum Spacing {
        // Base spacing values
        public static let xxxSmall: CGFloat = 4
        public static let xxSmall: CGFloat = 8
        public static let xSmall: CGFloat = 10
        public static let small: CGFloat = 12
        public static let medium: CGFloat = 16
        public static let large: CGFloat = 20
        public static let xLarge: CGFloat = 24
        public static let xxLarge: CGFloat = 30
        public static let xxxLarge: CGFloat = 32
        public static let huge: CGFloat = 40
        public static let xHuge: CGFloat = 50
        public static let xxHuge: CGFloat = 60
        public static let xxxHuge: CGFloat = 100
        
        // Common padding values
        public static let cardPadding: CGFloat = 24
        public static let screenHorizontalPadding: CGFloat = 32
        public static let buttonHorizontalPadding: CGFloat = 32
        public static let buttonVerticalPadding: CGFloat = 12
        
        // Component-specific spacing
        public static let iconPadding: CGFloat = 6
        public static let segmentSpacing: CGFloat = 8
        public static let dreamCardSpacing: CGFloat = 16
    }
    
    // MARK: - Sizes
    public enum Sizes {
        // Button sizes
        public static let buttonHeight: CGFloat = 54
        public static let largeButtonHeight: CGFloat = 88
        
        // Component sizes
        public static let smallComponentSize: CGFloat = 120
        public static let mediumComponentSize: CGFloat = 240
        public static let largeComponentSize: CGFloat = 300
        
        // Dream-specific component sizes
        public static let dreamOrbSize: CGFloat = 300
        public static let dreamOrbInner: CGFloat = 240
        public static let dreamOrbIntermediate: CGFloat = 200
        public static let profileImageLarge: CGFloat = 150
        public static let profileImageMedium: CGFloat = 120
        public static let iconSmall: CGFloat = 8
        
        // Icon sizes
        public static let dotSize: CGFloat = 8
        public static let starSizeRange: ClosedRange<CGFloat> = 1...3 // Random range for stars
        public static let particleSizeRange: ClosedRange<CGFloat> = 2...6 // Random range for particles
        
        // Profile specific
        public static let archetypeAvatarSize: CGFloat = 120
        public static let archetypeCanvasSize: CGFloat = 150
        public static let emotionalLandscapeHeight: CGFloat = 200
        public static let dreamPatternChartHeight: CGFloat = 60
    }
    
    // MARK: - Corner Radii
    public enum CornerRadius {
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 16
        public static let large: CGFloat = 20
        public static let pill: CGFloat = 27
    }
    
    // MARK: - Animation
    public enum Animation {
        public static let defaultDuration: Double = 0.3
        public static let mediumDuration: Double = 0.8
        public static let longDuration: Double = 1.0
        public static let delayShort: Double = 0.2
        public static let delayMedium: Double = 0.4
        
        public static func easeInOut(_ duration: Double = defaultDuration) -> SwiftUI.Animation {
            .easeInOut(duration: duration)
        }
        
        public static func easeIn(_ duration: Double = longDuration) -> SwiftUI.Animation {
            .easeIn(duration: duration)
        }
    }
    
    // MARK: - Opacity Values
    public enum Opacity {
        public static let disabled: Double = 0.3
        public static let dimmed: Double = 0.4
        public static let medium: Double = 0.5
        public static let semiVisible: Double = 0.6
        public static let prominent: Double = 0.8
        public static let almostFull: Double = 0.9
    }
    
    // MARK: - Shadow System
    public enum Shadow {
        public struct ShadowStyle: Sendable {
            let color: Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }
        
        public static let elevation1 = ShadowStyle(
            color: Color.black.opacity(0.4),
            radius: 4,
            x: 0,
            y: 2
        )
        
        public static let elevation2 = ShadowStyle(
            color: Color.black.opacity(0.5),
            radius: 8,
            x: 0,
            y: 4
        )
        
        public static let elevation3 = ShadowStyle(
            color: Color.black.opacity(0.6),
            radius: 12,
            x: 0,
            y: 6
        )
    }
}

// MARK: - Gradient Definitions

public extension DesignSystem {
    enum Gradients {
        // The main dream gradient used across the app
        public static let dreamGradient = LinearGradient(
            colors: [
                Colors.gradientEmber,
                Colors.gradientPurple,
                Colors.gradientPink
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        // Ember-focused gradient for accents
        public static let emberGradient = LinearGradient(
            colors: [
                Colors.ember.opacity(0.25),
                Colors.ember.opacity(0.1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        
        // Radial ember glow
        public static let emberGlow = RadialGradient(
            colors: [
                Colors.ember,
                Colors.ember.opacity(0.4),
                Color.clear
            ],
            center: .center,
            startRadius: 5,
            endRadius: 80
        )
        
        // Dark overlay gradient for readability
        public static let darkOverlay = RadialGradient(
            colors: [
                Colors.backgroundPrimary.opacity(0.8),
                Colors.backgroundPrimary.opacity(0.3)
            ],
            center: .center,
            startRadius: 5,
            endRadius: 80
        )
    }
}

// MARK: - Convenience Extensions

public extension View {
    func dreamCardStyle() -> some View {
        self
            .padding(DesignSystem.Spacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .fill(DesignSystem.Colors.cardBackground)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                            .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
                    )
            )
    }
    
    func dreamButtonStyle() -> some View {
        self
            .foregroundColor(DesignSystem.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: DesignSystem.Sizes.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.pill)
                    .fill(DesignSystem.Colors.ember)
            )
    }
    
    // MARK: - New Gradient Modifiers
    
    /// Applies the main dream gradient background
    func dreamGradientBackground(ignoresSafeArea: Bool = true) -> some View {
        self.background(
            ZStack {
                DesignSystem.Colors.backgroundSecondary
                DesignSystem.Gradients.dreamGradient
            }
            .ignoresSafeArea(edges: ignoresSafeArea ? .all : [])
        )
    }
    
    /// Applies glass morphism card styling with consistent values
    func glassCard(cornerRadius: CGFloat = DesignSystem.CornerRadius.large) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DesignSystem.Colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
                    )
            )
    }
    
    /// Applies glass morphism with padding
    func glassCardWithPadding(padding: CGFloat = DesignSystem.Spacing.cardPadding) -> some View {
        self
            .padding(padding)
            .glassCard()
    }
    
    /// Applies standard shadow elevation
    func dreamShadow(_ elevation: DesignSystem.Shadow.ShadowStyle = DesignSystem.Shadow.elevation1) -> some View {
        self.shadow(
            color: elevation.color,
            radius: elevation.radius,
            x: elevation.x,
            y: elevation.y
        )
    }
}