# Dream App Design System

This design system has been carefully audited to match all existing values in the app exactly. Using these tokens ensures consistency and prevents visual breakage.

## Usage

Import the design system in your SwiftUI files:
```swift
import Features // Contains DesignSystem
```

## Color System

### Primary Colors
- `DesignSystem.Colors.ember` - The signature orange (#FF9100)
- `DesignSystem.Colors.campfireBg` - Dark campfire background
- `DesignSystem.Colors.campfireCard` - Card background color

### Text Colors
- `DesignSystem.Colors.textPrimary` - White
- `DesignSystem.Colors.textSecondary` - White 80% opacity
- `DesignSystem.Colors.textTertiary` - White 70% opacity  
- `DesignSystem.Colors.textQuaternary` - White 60% opacity

### UI Colors
- `DesignSystem.Colors.cardBackground` - White 10% opacity
- `DesignSystem.Colors.cardBorder` - White 20% opacity
- `DesignSystem.Colors.overlayDim` - Black 40% opacity
- `DesignSystem.Colors.overlayMedium` - Black 50% opacity

## Typography System

### Title Styles
- `DesignSystem.Typography.largeTitle()` - Avenir-Heavy 42pt (app title)
- `DesignSystem.Typography.title1()` - Avenir-Heavy 32pt
- `DesignSystem.Typography.title2()` - Avenir-Heavy 28pt
- `DesignSystem.Typography.title3()` - Avenir-Medium 24pt

### Body Styles
- `DesignSystem.Typography.headline()` - Avenir-Heavy 20pt
- `DesignSystem.Typography.subheadline()` - Avenir-Medium 18pt
- `DesignSystem.Typography.body()` - Avenir-Book 18pt
- `DesignSystem.Typography.bodyMedium()` - Avenir-Medium 16pt
- `DesignSystem.Typography.bodySmall()` - Avenir-Book 16pt

### Caption Styles
- `DesignSystem.Typography.caption()` - Avenir-Book 14pt
- `DesignSystem.Typography.captionMedium()` - Avenir-Medium 14pt

### Special Styles
- `DesignSystem.Typography.displayLarge()` - Avenir-Medium 30pt
- `DesignSystem.Typography.systemIcon()` - System 48pt
- `DesignSystem.Typography.systemIconLarge()` - System 64pt

## Spacing System

### Base Spacing
- `xxxSmall: 4`
- `xxSmall: 8`
- `xSmall: 10`
- `small: 12`
- `medium: 16`
- `large: 20`
- `xLarge: 24`
- `xxLarge: 30`
- `xxxLarge: 32`

### Common Padding
- `cardPadding: 24` - Standard card internal padding
- `screenHorizontalPadding: 32` - Screen edge padding
- `buttonHorizontalPadding: 32` - Button internal horizontal padding
- `buttonVerticalPadding: 12` - Button internal vertical padding

## Component Sizes

### Buttons
- `buttonHeight: 54` - Standard button height
- `largeButtonHeight: 88` - Large button height

### Components
- `smallComponentSize: 120` - Small component (e.g., loading spinner)
- `mediumComponentSize: 240` - Medium component
- `largeComponentSize: 300` - Large component (e.g., main record button)

## Example Migration

Before:
```swift
Text("Dreams hold latent magic")
    .font(.custom("Avenir-Heavy", size: 32))
    .foregroundColor(.white)
    .padding(.horizontal, 32)
```

After:
```swift
Text("Dreams hold latent magic")
    .font(DesignSystem.Typography.title1())
    .foregroundColor(DesignSystem.Colors.textPrimary)
    .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
```

## Convenience Modifiers

The design system includes helper modifiers:

```swift
// Card styling
VStack { ... }
    .dreamCardStyle()

// Button styling  
Button("Start") { ... }
    .dreamButtonStyle()
```

## Important Notes

1. **No Visual Changes**: All values in this design system match the existing app exactly
2. **Gradual Migration**: Update files as you work on them, no need for a big refactor
3. **New Features**: Always use the design system for new features
4. **Custom Values**: If you need a value not in the system, add it rather than hardcoding