import SwiftUI

// MARK: - Design System Test View
// This view displays all design tokens for visual verification

public struct DesignSystemTestView: View {
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxLarge) {
                // Header
                Text("Design System Test")
                    .font(DesignSystem.Typography.largeTitle())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding(.top, DesignSystem.Spacing.xLarge)
                
                // Colors Section
                colorSection
                
                // Typography Section
                typographySection
                
                // Spacing Section
                spacingSection
                
                // Component Examples
                componentSection
                
                // Gradient Examples
                gradientSection
                
                // Glass Morphism Examples
                glassMorphismSection
            }
            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
            .padding(.bottom, DesignSystem.Spacing.xxxHuge)
        }
        .background(DreamBackground())
    }
    
    private var colorSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("Colors")
                .font(DesignSystem.Typography.headline())
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                ColorRow(name: "Ember", color: DesignSystem.Colors.ember)
                ColorRow(name: "Campfire BG", color: DesignSystem.Colors.campfireBg)
                ColorRow(name: "Campfire Card", color: DesignSystem.Colors.campfireCard)
                ColorRow(name: "Text Primary", color: DesignSystem.Colors.textPrimary)
                ColorRow(name: "Text Secondary", color: DesignSystem.Colors.textSecondary)
                ColorRow(name: "Text Tertiary", color: DesignSystem.Colors.textTertiary)
                ColorRow(name: "Text Quaternary", color: DesignSystem.Colors.textQuaternary)
            }
        }
    }
    
    private var typographySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("Typography")
                .font(DesignSystem.Typography.headline())
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                Text("Large Title - 42pt Heavy")
                    .font(DesignSystem.Typography.largeTitle())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text("Title 1 - 32pt Heavy")
                    .font(DesignSystem.Typography.title1())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text("Title 2 - 28pt Heavy")
                    .font(DesignSystem.Typography.title2())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text("Title 3 - 24pt Medium")
                    .font(DesignSystem.Typography.title3())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text("Headline - 20pt Heavy")
                    .font(DesignSystem.Typography.headline())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text("Subheadline - 18pt Medium")
                    .font(DesignSystem.Typography.subheadline())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text("Body - 18pt Book")
                    .font(DesignSystem.Typography.body())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text("Caption - 14pt Book")
                    .font(DesignSystem.Typography.caption())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
        }
    }
    
    private var spacingSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("Spacing")
                .font(DesignSystem.Typography.headline())
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxSmall) {
                SpacingRow(name: "xxxSmall", value: DesignSystem.Spacing.xxxSmall)
                SpacingRow(name: "xxSmall", value: DesignSystem.Spacing.xxSmall)
                SpacingRow(name: "xSmall", value: DesignSystem.Spacing.xSmall)
                SpacingRow(name: "small", value: DesignSystem.Spacing.small)
                SpacingRow(name: "medium", value: DesignSystem.Spacing.medium)
                SpacingRow(name: "large", value: DesignSystem.Spacing.large)
                SpacingRow(name: "xLarge", value: DesignSystem.Spacing.xLarge)
                SpacingRow(name: "xxLarge", value: DesignSystem.Spacing.xxLarge)
            }
        }
    }
    
    private var componentSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
            Text("Components")
                .font(DesignSystem.Typography.headline())
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            // Button Example
            Button("Dream Button Style") {
                // Action
            }
            .dreamButtonStyle()
            
            // Card Example
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                Text("Dream Card Style")
                    .font(DesignSystem.Typography.subheadline())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text("This is how cards look with the dream card style applied.")
                    .font(DesignSystem.Typography.body())
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .dreamCardStyle()
            
            // Glass Card Examples
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                Text("Glass Card")
                    .font(DesignSystem.Typography.subheadline())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text("With consistent glass morphism effect")
                    .font(DesignSystem.Typography.body())
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .padding(DesignSystem.Spacing.cardPadding)
            .glassCard()
            .dreamShadow()
        }
    }
    
    private var gradientSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
            Text("Gradients")
                .font(DesignSystem.Typography.headline())
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            // Dream Gradient
            VStack {
                Text("Dream Gradient")
                    .font(DesignSystem.Typography.bodyMedium())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(DesignSystem.Gradients.dreamGradient)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            
            // Ember Gradient
            VStack {
                Text("Ember Gradient")
                    .font(DesignSystem.Typography.bodyMedium())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(DesignSystem.Gradients.emberGradient)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            
            // Radial Gradients
            HStack(spacing: DesignSystem.Spacing.medium) {
                VStack {
                    Circle()
                        .fill(DesignSystem.Gradients.emberGlow)
                        .frame(width: 120, height: 120)
                    Text("Ember Glow")
                        .font(DesignSystem.Typography.caption())
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                VStack {
                    Circle()
                        .fill(DesignSystem.Gradients.darkOverlay)
                        .frame(width: 120, height: 120)
                    Text("Dark Overlay")
                        .font(DesignSystem.Typography.caption())
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
        }
    }
    
    private var glassMorphismSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
            Text("Glass Morphism & Shadows")
                .font(DesignSystem.Typography.headline())
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            // Elevation examples
            VStack(spacing: DesignSystem.Spacing.large) {
                Text("Elevation 1")
                    .font(DesignSystem.Typography.bodyMedium())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding()
                    .glassCard()
                    .dreamShadow(DesignSystem.Shadow.elevation1)
                
                Text("Elevation 2")
                    .font(DesignSystem.Typography.bodyMedium())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding()
                    .glassCard()
                    .dreamShadow(DesignSystem.Shadow.elevation2)
                
                Text("Elevation 3")
                    .font(DesignSystem.Typography.bodyMedium())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding()
                    .glassCard()
                    .dreamShadow(DesignSystem.Shadow.elevation3)
            }
        }
    }
}

// MARK: - Helper Views

private struct ColorRow: View {
    let name: String
    let color: Color
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .fill(color)
                .frame(width: 60, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
            
            Text(name)
                .font(DesignSystem.Typography.bodySmall())
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            Spacer()
        }
    }
}

private struct SpacingRow: View {
    let name: String
    let value: CGFloat
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            Text(name)
                .font(DesignSystem.Typography.bodySmall())
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .frame(width: 80, alignment: .leading)
            
            Rectangle()
                .fill(DesignSystem.Colors.ember)
                .frame(width: value, height: DesignSystem.Spacing.small)
            
            Text("\(Int(value))pt")
                .font(DesignSystem.Typography.caption())
                .foregroundColor(DesignSystem.Colors.textQuaternary)
            
            Spacer()
        }
    }
}