#!/bin/sh

set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
build_dir="$project_dir/.build/parser-check"
module_cache="$project_dir/.build/clang-cache"
default_sdk=$(xcrun --sdk macosx --show-sdk-path)
compatibility_sdk="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"

if [ -d "$compatibility_sdk" ]; then
    sdk_path="$compatibility_sdk"
else
    sdk_path="$default_sdk"
fi

architecture=$(uname -m)
mkdir -p "$build_dir" "$module_cache"

swiftc \
    -target "$architecture-apple-macosx13.0" \
    -sdk "$sdk_path" \
    -module-cache-path "$module_cache" \
    "$project_dir/Sources/GPTUsageMenu/UsageModels.swift" \
    "$project_dir/Tests/ParserCheck/main.swift" \
    -o "$build_dir/ParserCheck"

"$build_dir/ParserCheck"
