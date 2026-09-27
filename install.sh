#!/bin/sh
set -e
URL="https://raw.githubusercontent.com/n0xby/cfetch/main/cfetch.sh"
if [ -w /usr/local/bin ]; then
    TARGET=/usr/local/bin/cfetch
else
    mkdir -p "$HOME/.local/bin"
    TARGET="$HOME/.local/bin/cfetch"
fi
if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$URL" -o "$TARGET"
elif command -v wget >/dev/null 2>&1; then
    wget -q "$URL" -O "$TARGET"
else
    echo "need curl or wget" >&2
    exit 1
fi
chmod +x "$TARGET"
echo "installed: $TARGET"
case ":$PATH:" in
    *":$(dirname "$TARGET"):"*) ;;
    *) echo "add to PATH: export PATH=\"$(dirname "$TARGET"):\$PATH\"" ;;
esac
