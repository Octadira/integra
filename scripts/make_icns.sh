#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "Usage: ./make_icns.sh <path_to_source_image>"
    exit 1
fi

SRC_IMG="$1"
WORK_DIR="$(dirname "$SRC_IMG")/AppIcon.iconset"
OUT_ICNS="$(dirname "$SRC_IMG")/AppIcon.icns"

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

echo "--> Generating icon resolutions using sips..."
sips -s format png -z 16 16     "$SRC_IMG" --out "$WORK_DIR/icon_16x16.png" > /dev/null
sips -s format png -z 32 32     "$SRC_IMG" --out "$WORK_DIR/icon_16x16@2x.png" > /dev/null
sips -s format png -z 32 32     "$SRC_IMG" --out "$WORK_DIR/icon_32x32.png" > /dev/null
sips -s format png -z 64 64     "$SRC_IMG" --out "$WORK_DIR/icon_32x32@2x.png" > /dev/null
sips -s format png -z 128 128   "$SRC_IMG" --out "$WORK_DIR/icon_128x128.png" > /dev/null
sips -s format png -z 256 256   "$SRC_IMG" --out "$WORK_DIR/icon_128x128@2x.png" > /dev/null
sips -s format png -z 256 256   "$SRC_IMG" --out "$WORK_DIR/icon_256x256.png" > /dev/null
sips -s format png -z 512 512   "$SRC_IMG" --out "$WORK_DIR/icon_256x256@2x.png" > /dev/null
sips -s format png -z 512 512   "$SRC_IMG" --out "$WORK_DIR/icon_512x512.png" > /dev/null
sips -s format png -z 1024 1024 "$SRC_IMG" --out "$WORK_DIR/icon_512x512@2x.png" > /dev/null

echo "--> Compiling AppIcon.icns with iconutil..."
iconutil -c icns "$WORK_DIR" -o "$OUT_ICNS"
rm -rf "$WORK_DIR"

echo "Successfully generated $OUT_ICNS"
