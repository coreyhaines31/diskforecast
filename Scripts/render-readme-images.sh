#!/bin/bash
# Captures the README images from the real app running on made-up demo data, in light and dark.
#
#   Scripts/render-readme-images.sh
#
# Needs ImageMagick (brew install imagemagick) to frame the images.
#
# Builds a debug copy (demo mode only exists in debug builds) and opens the menu, the Forecast
# window, and the Cleanup window one at a time. The app draws each of its own windows to a PNG,
# so no Screen Recording permission is needed. Quits an installed Disk Forecast while it runs and
# reopens it after.
set -euo pipefail

cd "$(dirname "$0")/.."
case "${DEVELOPER_DIR:-}" in
  ""|*CommandLineTools*) export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ;;
esac
OUT=.github/images
mkdir -p "$OUT"
rm -f "$OUT"/menu-*.png "$OUT"/forecast-*.png "$OUT"/cleanup-*.png

echo "▶ Building a debug copy"
xcodegen generate -q
xcodebuild -project DiskForecast.xcodeproj -scheme DiskForecast -derivedDataPath build/DerivedData \
  DEVELOPMENT_TEAM="" CODE_SIGN_IDENTITY="-" build -quiet
APP="build/DerivedData/Build/Products/Debug/Disk Forecast.app"

was_running=false
if pgrep -f "/Applications/Disk Forecast.app/Contents/MacOS/Disk Forecast" >/dev/null; then
  was_running=true
  pkill -f "/Applications/Disk Forecast.app/Contents/MacOS/Disk Forecast" || true
  sleep 4  # let the menu bar settle before the first capture
fi

# Rounds the corners and adds a soft shadow, so captures look like macOS windows on any page.
frame() { # file, corner radius in pixels
  local file=$1 radius=$2 width height
  width=$(magick identify -format %w "$file")
  height=$(magick identify -format %h "$file")
  magick "$file" \( -size "${width}x${height}" xc:none -fill white \
    -draw "roundrectangle 0,0,$((width - 1)),$((height - 1)),$radius,$radius" \) \
    -compose DstIn -composite "$file.rounded.png"
  magick "$file.rounded.png" \( +clone -background black -shadow 35x22+0+14 \) +swap \
    -background none -layers merge +repage "$file"
  rm "$file.rounded.png"
}

capture() { # view, file name, modes
  local view=$1 name=$2 modes=$3
  for mode in $modes; do
    local flags=(--demo --show "$view" --capture "$PWD/$OUT/$name-$mode.png")
    [ "$mode" = dark ] && flags+=(--dark)
    # The app draws its own window to the file and quits. The menu sometimes opens late, so
    # try twice.
    for _ in 1 2 3; do
      "$APP/Contents/MacOS/Disk Forecast" "${flags[@]}" >/dev/null 2>&1 &
      local pid=$! waited=0
      while kill -0 "$pid" 2>/dev/null && [ $waited -lt 20 ]; do sleep 1; waited=$((waited + 1)); done
      kill "$pid" 2>/dev/null || true
      [ -f "$OUT/$name-$mode.png" ] && break
    done
    if [ -f "$OUT/$name-$mode.png" ]; then
      frame "$OUT/$name-$mode.png" 24
      echo "  $OUT/$name-$mode.png"
    else
      echo "  $name-$mode failed" >&2
    fi
  done
}

echo "▶ Capturing"
# Menus draw their dark background as live translucency, which an app can't draw to an image,
# so the menu is captured in light mode only.
capture menu menu light
capture forecast forecast "light dark"
capture cleanup cleanup "light dark"

# Keep LaunchServices from opening this debug copy instead of the installed app.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -u "$PWD/$APP" 2>/dev/null || true
$was_running && open -a "/Applications/Disk Forecast.app"
echo "✓ Done"
