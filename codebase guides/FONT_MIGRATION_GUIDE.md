# Iowan Old Style Font Migration Guide

## Overview
The Dream app has been migrated from Avenir to Iowan Old Style BT, a classic serif typeface that provides a more literary and distinctive feel to the app.

## Font Files
The following Iowan Old Style BT font files have been added to the project:
- `bitstream-iowan-old-style-bt-586c36a8d7712.ttf` - Regular/Roman
- `bitstream-iowan-old-style-italic-bt-586c3740dc396.ttf` - Italic
- `bitstream-iowan-old-style-bold-bt-586c371d8d669.ttf` - Bold
- `bitstream-iowan-old-style-bold-italic-bt-586c37701cb62.ttf` - Bold Italic
- `bitstream-iowan-old-style-black-bt-586c36e930225.ttf` - Black
- `bitstream-iowan-old-style-black-italic-bt-586c378f12ca1.ttf` - Black Italic

## Font Mapping
| Avenir Font | Iowan Old Style Replacement | PostScript Name |
|-------------|----------------------------|-----------------|
| Avenir-Heavy | Iowan Old Style Black | IowanOldStyleBT-Black |
| Avenir-Medium | Iowan Old Style Bold | IowanOldStyleBT-Bold |
| Avenir-Book | Iowan Old Style Roman | IowanOldStyleBT-Roman |

## Implementation Details

### 1. Font Registration
Fonts are registered in `Info.plist` under the `UIAppFonts` key:
```xml
<key>UIAppFonts</key>
<array>
    <string>bitstream-iowan-old-style-bt-586c36a8d7712.ttf</string>
    <string>bitstream-iowan-old-style-italic-bt-586c3740dc396.ttf</string>
    <string>bitstream-iowan-old-style-bold-bt-586c371d8d669.ttf</string>
    <string>bitstream-iowan-old-style-bold-italic-bt-586c37701cb62.ttf</string>
    <string>bitstream-iowan-old-style-black-bt-586c36e930225.ttf</string>
    <string>bitstream-iowan-old-style-black-italic-bt-586c378f12ca1.ttf</string>
</array>
```

### 2. DesignSystem Updates
The `DesignSystem.Typography` enum has been updated with:
- New font family constants pointing to Iowan Old Style
- Fallback mechanism to Avenir if fonts fail to load
- Adjusted font sizes for better serif readability

### 3. Size Adjustments
Font sizes have been slightly reduced (1-2pt) across the board to account for the larger x-height and wider character spacing of serif fonts:
- Large Title: 42pt → 40pt
- Title 1: 32pt → 30pt
- Title 2: 28pt → 26pt
- Body: 18pt → 17pt

### 4. Fallback System
A robust fallback system ensures the app remains functional if custom fonts fail to load:
```swift
private static func customFont(_ name: String, fallback: String, size: CGFloat) -> Font {
    if UIFont(name: name, size: size) != nil {
        return .custom(name, size: size)
    } else {
        print("⚠️ Font '\(name)' not found, falling back to '\(fallback)'")
        return .custom(fallback, size: size)
    }
}
```

## Testing

### Font Validation View
A comprehensive `FontValidationView.swift` has been created to:
- Verify font registration status
- Display typography hierarchy
- Compare old vs new fonts side-by-side
- Test fonts in real components

### To Test:
1. Build and run the app
2. Navigate to any view using the DesignSystem
3. Check console for any font loading warnings
4. Use FontValidationView to verify all fonts load correctly

## Xcode Project Setup

### Required Steps:
1. Add font files to the app target in Xcode
2. Ensure fonts are included in "Copy Bundle Resources" build phase
3. Clean build folder and rebuild

### File Locations:
- Font files: `/dream/dream/` directory
- Info.plist: `/dream/dream/Info.plist`
- DesignSystem: `/Features/Sources/Features/DesignSystem.swift`

## Visual Impact

### Benefits:
- More distinctive, literary aesthetic
- Better differentiation from standard iOS apps
- Enhanced readability for longer text passages
- Classic, timeless appearance

### Considerations:
- Serif fonts may appear denser on small screens
- Line spacing may need adjustment in some views
- Navigation bar fonts use smaller sizes for balance

## Future Improvements
1. Consider adding OpenType features support
2. Fine-tune letter spacing for optimal readability
3. Add dynamic type support with custom scaling
4. Consider using italic variants for emphasis

## Troubleshooting

### Font Not Loading:
1. Verify font files are in the app bundle
2. Check Info.plist UIAppFonts array
3. Ensure PostScript names match exactly
4. Clean build folder and rebuild

### Visual Issues:
1. Adjust line spacing if text appears cramped
2. Increase padding around text elements
3. Consider using lighter weights for body text
4. Test on various screen sizes

## Rollback Plan
To revert to Avenir:
1. Update `DesignSystem.Typography` font constants back to Avenir
2. Remove UIAppFonts from Info.plist (optional)
3. Delete font files from project (optional)