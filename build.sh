#!/bin/zsh
# Compila ClipPrint e crea ClipPrint.app (firma ad-hoc).
# Uso: ./build.sh            -> crea build/ClipPrint.app
#      ./build.sh install    -> copia anche in /Applications e la avvia
set -e
cd "$(dirname "$0")"
swift build -c release
APP=build/ClipPrint.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/ClipPrint "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
codesign --force --sign - "$APP"
echo "Creata $APP"
if [[ "$1" == "install" ]]; then
    pkill -x ClipPrint 2>/dev/null || true
    rm -rf /Applications/ClipPrint.app
    cp -R "$APP" /Applications/
    open /Applications/ClipPrint.app
    echo "Installata in /Applications e avviata"
fi
