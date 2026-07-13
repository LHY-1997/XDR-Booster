#!/bin/zsh
set -euo pipefail

root="${0:A:h}"
scratch="${TMPDIR:-/tmp}/xdrlift-build"
swift build --disable-sandbox --scratch-path "$scratch"

bundle="$root/XDRLift.app"
mkdir -p "$bundle/Contents/MacOS"
mkdir -p "$bundle/Contents/Resources"
cp "$root/AppBundle/Info.plist" "$bundle/Contents/Info.plist"
cp "$scratch/arm64-apple-macosx/debug/XDRLift" "$bundle/Contents/MacOS/XDRLift"
ditto "$scratch/arm64-apple-macosx/debug/XDRLift_XDRLift.bundle" "$bundle/Contents/Resources/XDRLift_XDRLift.bundle"
codesign --force --sign - "$bundle"
echo "Built $bundle"
