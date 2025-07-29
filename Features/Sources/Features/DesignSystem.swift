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
    }
    
    // MARK: - Typography
    public enum Typography {
        // Font families
        public static let fontFamilyBase = "Avenir"
        public static let fontFamilyHeavy = "Avenir-Heavy"
        public static let fontFamilyMedium = "Avenir-Medium"
        public static let fontFamilyBook = "Avenir-Book"
        
        // Font styles with exact sizes from audit
        public static func largeTitle() -> Font {
            .custom(fontFamilyHeavy, size: 42)
        }
        
        public static func title1() -> Font {
            .custom(fontFamilyHeavy, size: 32)
        }
        
        public static func title2() -> Font {
            .custom(fontFamilyHeavy, size: 28)
        }
        
        public static func title3() -> Font {
            .custom(fontFamilyMedium, size: 24)
        }
        
        public static func headline() -> Font {
            .custom(fontFamilyHeavy, size: 20)
        }
        
        public static func subheadline() -> Font {
            .custom(fontFamilyMedium, size: 18)
        }
        
        public static func body() -> Font {
            .custom(fontFamilyBook, size: 18)
        }
        
        public static func bodyMedium() -> Font {
            .custom(fontFamilyMedium, size: 16)
        }
        
        public static func bodySmall() -> Font {
            .custom(fontFamilyBook, size: 16)
        }
        
        public static func caption() -> Font {
            .custom(fontFamilyBook, size: 14)
        }
        
        public static func captionMedium() -> Font {
            .custom(fontFamilyMedium, size: 14)
        }
        
        // Special sizes
        public static func displayLarge() -> Font {
            .custom(fontFamilyMedium, size: 30)
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
            .custom(fontFamilyBase, size: 17)
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
}