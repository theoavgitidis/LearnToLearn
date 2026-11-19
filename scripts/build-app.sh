#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$TASK_ROOT"
TASK_CONFIG="${1:-release}"
if [[ "$TASK_CONFIG" != "release" && "$TASK_CONFIG" != "debug" ]]; then
    echo "Aufruf: ./scripts/build-app.sh [release|debug]" >&2
    exit 1
fi
swift build -c "$TASK_CONFIG" --product LearnToLearn
TASK_BIN="$(swift build -c "$TASK_CONFIG" --show-bin-path)"
TASK_APP="$TASK_ROOT/dist/Learn to Learn.app"
mkdir -p "$TASK_APP/Contents/MacOS" "$TASK_APP/Contents/Resources"
cp "$TASK_BIN/LearnToLearn" "$TASK_APP/Contents/MacOS/LearnToLearn"
cp Resources/Info.plist "$TASK_APP/Contents/Info.plist"
if [[ ! -f Resources/AppIcon.icns ]]; then
    swift scripts/make-icon.swift "$TASK_ROOT/Resources"
fi
cp Resources/AppIcon.icns "$TASK_APP/Contents/Resources/AppIcon.icns"
cp Examples/Alle-Fragetypen.json "$TASK_APP/Contents/Resources/Alle-Fragetypen.json"
cp IMPORTFORMAT.md "$TASK_APP/Contents/Resources/IMPORTFORMAT.md"
/usr/bin/codesign --force --deep --sign - "$TASK_APP"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$TASK_APP" "$TASK_ROOT/dist/LearnToLearn-macOS.zip"
echo "Fertig: $TASK_APP"
