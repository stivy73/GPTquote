#!/bin/sh

set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
app_dir="$project_dir/dist/GPTquote.app"
contents_dir="$app_dir/Contents"
build_dir="$project_dir/.build/manual-release"
module_cache="$project_dir/.build/clang-cache"
iconset_dir="$project_dir/.build/AppIcon.iconset"
default_sdk=$(xcrun --sdk macosx --show-sdk-path)
compatibility_sdk="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"

if [ -d "$compatibility_sdk" ]; then
    sdk_path="$compatibility_sdk"
else
    sdk_path="$default_sdk"
fi

architecture=$(uname -m)

cd "$project_dir"
mkdir -p "$build_dir" "$module_cache"

swiftc \
    -parse-as-library \
    -O \
    -gnone \
    -target "$architecture-apple-macosx13.0" \
    -sdk "$sdk_path" \
    -module-cache-path "$module_cache" \
    "$project_dir/Sources/GPTUsageMenu/UsageModels.swift" \
    "$project_dir/Sources/GPTUsageMenu/CodexAppServerClient.swift" \
    "$project_dir/Sources/GPTUsageMenu/UsageStore.swift" \
    "$project_dir/Sources/GPTUsageMenu/GPTUsageMenuApp.swift" \
    -o "$build_dir/GPTUsageMenu"

mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
cp "$build_dir/GPTUsageMenu" "$contents_dir/MacOS/GPTUsageMenu"
cp "$project_dir/AppResources/Info.plist" "$contents_dir/Info.plist"
cp "$project_dir/AppResources/MenuBarChatGPT.png" "$contents_dir/Resources/MenuBarChatGPT.png"
cp "$project_dir/AppResources/ArchetipiDigitaliLogo.png" "$contents_dir/Resources/ArchetipiDigitaliLogo.png"

mkdir -p "$iconset_dir"
sips -z 16 16 "$project_dir/AppResources/AppIcon.png" --out "$iconset_dir/icon_16x16.png" >/dev/null
sips -z 32 32 "$project_dir/AppResources/AppIcon.png" --out "$iconset_dir/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$project_dir/AppResources/AppIcon.png" --out "$iconset_dir/icon_32x32.png" >/dev/null
sips -z 64 64 "$project_dir/AppResources/AppIcon.png" --out "$iconset_dir/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$project_dir/AppResources/AppIcon.png" --out "$iconset_dir/icon_128x128.png" >/dev/null
sips -z 256 256 "$project_dir/AppResources/AppIcon.png" --out "$iconset_dir/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$project_dir/AppResources/AppIcon.png" --out "$iconset_dir/icon_256x256.png" >/dev/null
sips -z 512 512 "$project_dir/AppResources/AppIcon.png" --out "$iconset_dir/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$project_dir/AppResources/AppIcon.png" --out "$iconset_dir/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$project_dir/AppResources/AppIcon.png" --out "$iconset_dir/icon_512x512@2x.png" >/dev/null
swiftc \
    -O \
    -gnone \
    -target "$architecture-apple-macosx13.0" \
    -sdk "$sdk_path" \
    -module-cache-path "$module_cache" \
    "$project_dir/scripts/make-icns.swift" \
    -o "$build_dir/make-icns"
"$build_dir/make-icns" "$iconset_dir" "$contents_dir/Resources/AppIcon.icns"

codesign --force --deep --sign - "$app_dir"

echo "$app_dir"
