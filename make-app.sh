#!/bin/zsh
set -euo pipefail

root="${0:A:h}"
scratch="${TMPDIR:-/tmp}/xdrplus-build"
swift build --disable-sandbox --scratch-path "$scratch"

bundle="$root/XDR+.app"
rm -rf "$bundle"
mkdir -p "$bundle/Contents/MacOS"
mkdir -p "$bundle/Contents/Resources"
cp "$root/AppBundle/Info.plist" "$bundle/Contents/Info.plist"
cp "$scratch/arm64-apple-macosx/debug/XDRPlus" "$bundle/Contents/MacOS/XDRPlus"
ditto "$scratch/arm64-apple-macosx/debug/XDRPlus_XDRPlus.bundle" "$bundle/Contents/Resources/XDRPlus_XDRPlus.bundle"
codesign --force --sign - "$bundle"
echo "Built $bundle"
