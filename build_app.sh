#!/usr/bin/env bash
# Build and package MarkdownView SwiftPM macOS app
set -euo pipefail

CONFIG="${1:-release}"
INSTALL="${2:-}"

APP_NAME="MarkdownView"
BUNDLE_ID="com.bigmac.markdownview"
MACOS_MIN_VERSION="15.0"
ARCHES="$(uname -m)"
VERSION="1.0.0"
BUILD_NUMBER="1"

APP_BUNDLE="$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"
ENTITLEMENTS_FILE="$(mktemp -t markdownview.entitlements.XXXXXX)"
trap 'rm -f "$ENTITLEMENTS_FILE"' EXIT

echo "Building $APP_NAME ($CONFIG) for: $ARCHES"

# Build for each architecture
for arch in $ARCHES; do
    echo "swift build --arch $arch -c $CONFIG"
    swift build --arch "$arch" -c "$CONFIG"
done

# Clean and create bundle structure
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Find and copy binary
ARCH_ARRAY=($ARCHES)
if [[ ${#ARCH_ARRAY[@]} -eq 1 ]]; then
    BINARY_PATH=".build/${ARCH_ARRAY[0]}-apple-macosx/$CONFIG/$APP_NAME"
    cp "$BINARY_PATH" "$MACOS_DIR/$APP_NAME"
else
    LIPO_INPUTS=()
    for arch in $ARCHES; do
        LIPO_INPUTS+=(".build/${arch}-apple-macosx/$CONFIG/$APP_NAME")
    done
    echo "Creating universal binary"
    lipo -create "${LIPO_INPUTS[@]}" -output "$MACOS_DIR/$APP_NAME"
fi

echo "Binary architectures:"
lipo -info "$MACOS_DIR/$APP_NAME"

# Get git commit for build metadata
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Generate Info.plist
cat > "$CONTENTS/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>MarkdownView</string>
    <key>CFBundleDisplayName</key>
    <string>MarkdownView</string>
    <key>CFBundleIdentifier</key>
    <string>com.bigmac.markdownview</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleExecutable</key>
    <string>MarkdownView</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Markdown Document</string>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>LSHandlerRank</key>
            <string>Default</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>net.daringfireball.markdown</string>
            </array>
        </dict>
    </array>
    <key>UTExportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>net.daringfireball.markdown</string>
            <key>UTTypeDescription</key>
            <string>Markdown Document</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.plain-text</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>md</string>
                    <string>markdown</string>
                    <string>mdown</string>
                </array>
            </dict>
        </dict>
    </array>
</dict>
</plist>
EOF

# Create entitlements
cat > "$ENTITLEMENTS_FILE" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
EOF

# Clear extended attributes and sign
xattr -cr "$APP_BUNDLE"
codesign --force --deep --sign - --entitlements "$ENTITLEMENTS_FILE" "$APP_BUNDLE"

echo "Created: $APP_BUNDLE"

# Install if requested
if [[ "$INSTALL" == "--install" ]]; then
    echo "Installing to /Applications/"
    rm -rf "/Applications/$APP_BUNDLE"
    cp -R "$APP_BUNDLE" "/Applications/"
    echo "Installed to /Applications/$APP_BUNDLE"
    echo ""
    echo "To set as default Markdown app:"
    echo "  duti -s com.bigmac.markdownview net.daringfireball.markdown all"
fi

echo ""
ls -la "$APP_BUNDLE"
