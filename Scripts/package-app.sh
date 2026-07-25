#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
build_dir="$project_dir/.build"
dist_dir="$project_dir/dist"
app_path="$dist_dir/TZC.app"
contents_path="$app_path/Contents"
iconset_path="$build_dir/AppIcon.iconset"
icon_source="$project_dir/Packaging/AppIcon-1024.png"

swift build \
  --package-path "$project_dir" \
  -c release \
  --arch arm64

rm -rf "$app_path" "$iconset_path"
mkdir -p \
  "$contents_path/MacOS" \
  "$contents_path/Resources" \
  "$iconset_path"

cp "$build_dir/arm64-apple-macosx/release/TimeZoneNative" "$contents_path/MacOS/TZC"
cp "$project_dir/Packaging/Info.plist" "$contents_path/Info.plist"

sips -z 16 16 "$icon_source" --out "$iconset_path/icon_16x16.png" >/dev/null
sips -z 32 32 "$icon_source" --out "$iconset_path/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$icon_source" --out "$iconset_path/icon_32x32.png" >/dev/null
sips -z 64 64 "$icon_source" --out "$iconset_path/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$icon_source" --out "$iconset_path/icon_128x128.png" >/dev/null
sips -z 256 256 "$icon_source" --out "$iconset_path/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$icon_source" --out "$iconset_path/icon_256x256.png" >/dev/null
sips -z 512 512 "$icon_source" --out "$iconset_path/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$icon_source" --out "$iconset_path/icon_512x512.png" >/dev/null
cp "$icon_source" "$iconset_path/icon_512x512@2x.png"
iconutil -c icns "$iconset_path" -o "$contents_path/Resources/AppIcon.icns"

codesign \
  --force \
  --deep \
  --sign - \
  --timestamp=none \
  "$app_path"

zip_path="$dist_dir/TZC-arm64.zip"
rm -f "$zip_path"
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$zip_path"

echo "$app_path"
echo "$zip_path"
