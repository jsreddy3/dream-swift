import SwiftUI

// Comprehensive font validation view for testing Iowan Old Style implementation
public struct FontValidationView: View {
    @State private var showComparison = false
    @State private var testText = "Dreams hold latent magic"
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 10) {
                    Text("Font Migration Test")
                        .font(DesignSystem.Typography.largeTitle())
                        .foregroundColor(DesignSystem.Colors.ember)
                    
                    Text("Iowan Old Style BT Implementation")
                        .font(DesignSystem.Typography.subheadline())
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(.top, 40)
                
                // Font availability check
                fontAvailabilitySection
                
                // Typography showcase
                typographyShowcase
                
                // Side-by-side comparison toggle
                Toggle("Show Avenir Comparison", isOn: $showComparison)
                    .padding(.horizontal)
                
                if showComparison {
                    comparisonSection
                }
                
                // Test input
                testInputSection
                
                // Real component examples
                componentExamples
            }
            .padding(.bottom, 50)
        }
        .background(DesignSystem.Colors.backgroundPrimary)
    }
    
    // MARK: - Font Availability Section
    private var fontAvailabilitySection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Font Registration Status")
                .font(DesignSystem.Typography.headline())
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            VStack(spacing: 10) {
                fontStatusRow("IowanOldStyleBT-Roman", DesignSystem.Typography.fontFamilyBook)
                fontStatusRow("IowanOldStyleBT-Bold", DesignSystem.Typography.fontFamilyMedium)
                fontStatusRow("IowanOldStyleBT-Black", DesignSystem.Typography.fontFamilyHeavy)
            }
            .padding()
            .glassCard()
        }
        .padding(.horizontal)
    }
    
    private func fontStatusRow(_ displayName: String, _ fontName: String) -> some View {
        HStack {
            Text(displayName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            Spacer()
            
            if UIFont(name: fontName, size: 16) != nil {
                Label("Loaded", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                Label("Not Found", systemImage: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - Typography Showcase
    private var typographyShowcase: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Typography Hierarchy")
                .font(DesignSystem.Typography.headline())
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            VStack(alignment: .leading, spacing: 15) {
                typographyRow("Large Title", DesignSystem.Typography.largeTitle())
                typographyRow("Title 1", DesignSystem.Typography.title1())
                typographyRow("Title 2", DesignSystem.Typography.title2())
                typographyRow("Title 3", DesignSystem.Typography.title3())
                typographyRow("Headline", DesignSystem.Typography.headline())
                typographyRow("Subheadline", DesignSystem.Typography.subheadline())
                typographyRow("Body", DesignSystem.Typography.body())
                typographyRow("Body Medium", DesignSystem.Typography.bodyMedium())
                typographyRow("Body Small", DesignSystem.Typography.bodySmall())
                typographyRow("Caption", DesignSystem.Typography.caption())
                typographyRow("Caption Medium", DesignSystem.Typography.captionMedium())
            }
            .padding()
            .glassCard()
        }
        .padding(.horizontal)
    }
    
    private func typographyRow(_ label: String, _ font: Font) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DesignSystem.Colors.ember)
            
            Text("The quick brown fox jumps over the lazy dog")
                .font(font)
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
    }
    
    // MARK: - Comparison Section
    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Font Comparison")
                .font(DesignSystem.Typography.headline())
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            VStack(spacing: 20) {
                comparisonRow("Title", 
                    old: Font.custom("Avenir-Heavy", size: 32),
                    new: DesignSystem.Typography.title1())
                
                comparisonRow("Body", 
                    old: Font.custom("Avenir-Book", size: 18),
                    new: DesignSystem.Typography.body())
                
                comparisonRow("Caption", 
                    old: Font.custom("Avenir-Book", size: 14),
                    new: DesignSystem.Typography.caption())
            }
            .padding()
            .glassCard()
        }
        .padding(.horizontal)
    }
    
    private func comparisonRow(_ label: String, old: Font, new: Font) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(DesignSystem.Colors.ember)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Avenir")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                    Text(testText)
                        .font(old)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading) {
                    Text("Iowan Old Style")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                    Text(testText)
                        .font(new)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    // MARK: - Test Input Section
    private var testInputSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Custom Text Test")
                .font(DesignSystem.Typography.headline())
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            TextField("Enter test text", text: $testText)
                .font(DesignSystem.Typography.body())
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .padding()
                .glassCard()
        }
        .padding(.horizontal)
    }
    
    // MARK: - Component Examples
    private var componentExamples: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Component Examples")
                .font(DesignSystem.Typography.headline())
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            // Dream card example
            VStack(alignment: .leading, spacing: 10) {
                Text("Flying Through Starlit Clouds")
                    .font(DesignSystem.Typography.subheadline())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text("Last night I dreamed I was soaring through clouds made of stardust...")
                    .font(DesignSystem.Typography.caption())
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .lineLimit(2)
                
                HStack {
                    Text("December 15, 2024")
                        .font(.caption2)
                        .foregroundColor(DesignSystem.Colors.ember)
                    
                    Spacer()
                    
                    Image(systemName: "sparkles")
                        .foregroundStyle(DesignSystem.Colors.ember)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .dreamCardStyle()
            
            // Button example
            Button(action: {}) {
                Text("Start Recording Dream")
                    .font(DesignSystem.Typography.subheadline())
                    .foregroundColor(.white)
            }
            .dreamButtonStyle()
            .padding(.horizontal)
            
            // Profile stat example
            HStack(spacing: 30) {
                VStack {
                    Text("15")
                        .font(DesignSystem.Typography.title2())
                        .foregroundColor(DesignSystem.Colors.ember)
                    Text("Dreams")
                        .font(DesignSystem.Typography.caption())
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                
                VStack {
                    Text("7")
                        .font(DesignSystem.Typography.title2())
                        .foregroundColor(DesignSystem.Colors.ember)
                    Text("Themes")
                        .font(DesignSystem.Typography.caption())
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                
                VStack {
                    Text("92%")
                        .font(DesignSystem.Typography.title2())
                        .foregroundColor(DesignSystem.Colors.ember)
                    Text("Clarity")
                        .font(DesignSystem.Typography.caption())
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
            }
            .padding()
            .glassCard()
            .padding(.horizontal)
        }
    }
}