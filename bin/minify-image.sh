#!/bin/sh

TARGET="$1"
DIMENSIONS="4000x800"

if [ ! -f "$TARGET" ]; then
    echo "File not found"
    exit 1
fi

if [ -n "$2" ]; then
    DIMENSIONS="$2"
fi

FILENAME=$(basename "$TARGET")
SIZE_BEFORE=$(wc -c "$TARGET" | cut -d' ' -f1)

process_jpg() {
    convert "$1" \
        -resize "$DIMENSIONS"'>' \
        -sampling-factor 4:2:0 -strip -quality 85 -interlace JPEG -colorspace sRGB \
        "$1".mod
}

process_png() {
    convert "$1" -resize "$DIMENSIONS"'>' "$1".resized &&
        pngquant --output "$1".mod --strip --force -- "$1".resized
    rm "$1".resized
}

if echo "$TARGET" | grep -E ".jpe?g$"; then
    process_jpg "$TARGET"
else
    process_png "$TARGET"
fi

SIZE=$(wc -c "$TARGET".mod | cut -d' ' -f1)
if [ $SIZE -lt $SIZE_BEFORE ]; then
    echo "$FILENAME reduced to $SIZE (from $SIZE_BEFORE)"
    mv "$TARGET".mod "$TARGET"
else
    echo "$FILENAME was already optimized"
    rm "$TARGET".mod
fi
