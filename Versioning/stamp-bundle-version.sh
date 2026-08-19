#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
VERSION_FILE="$SCRIPT_DIR/Version.generated.env"

if [ ! -f "$VERSION_FILE" ]; then
    echo "error: Version.generated.env does not exist."
    exit 1
fi

. "$VERSION_FILE"

PLIST_PATH="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"

if [ ! -f "$PLIST_PATH" ]; then
    echo "error: Built Info.plist not found at $PLIST_PATH"
    exit 1
fi

/usr/libexec/PlistBuddy \
    -c "Set :CFBundleShortVersionString $LOOTRACK_VERSION" \
    "$PLIST_PATH"

/usr/libexec/PlistBuddy \
    -c "Set :CFBundleVersion $LOOTRACK_BUILD_NUMBER" \
    "$PLIST_PATH"

echo "Stamped Lootrack v$LOOTRACK_VERSION ($LOOTRACK_BUILD_NUMBER)"
