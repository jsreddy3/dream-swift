#!/bin/bash

echo "Fixing Xcode project..."

# Clean derived data
echo "1. Cleaning derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Remove xcuserdata
echo "2. Removing xcuserdata..."
find . -name "xcuserdata" -type d -exec rm -rf {} + 2>/dev/null || true

# Remove Package.resolved if exists
echo "3. Removing Package.resolved..."
find . -name "Package.resolved" -type f -delete 2>/dev/null || true

# Clean SPM cache
echo "4. Cleaning SPM cache..."
rm -rf ~/.swiftpm/
rm -rf .swiftpm/ 2>/dev/null || true
rm -rf .build/ 2>/dev/null || true

# Remove workspace user data
echo "5. Cleaning workspace data..."
rm -rf dreamfinder.xcworkspace/xcuserdata/ 2>/dev/null || true
rm -rf dream/dream.xcodeproj/xcuserdata/ 2>/dev/null || true

echo "Done! Now try opening the workspace in Xcode again."
echo ""
echo "If the issue persists, try:"
echo "1. Open dream.xcodeproj directly (not the workspace)"
echo "2. In Xcode: File > Packages > Reset Package Caches"
echo "3. Clean build folder: Cmd+Shift+K"
echo "4. Then open the workspace again"