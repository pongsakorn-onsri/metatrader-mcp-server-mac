#!/bin/bash
# Launch the MT5 terminal GUI inside a given Wine prefix — for the one-time
# interactive login of a cloned account prefix (see new-account-prefix.sh).
#
# Usage:
#   MT5_WINEPREFIX="$HOME/.mt5-accountB" ./launch-terminal.sh
#
# Env:
#   MT5_WINEPREFIX     Wine prefix to launch in            (required)
#   MT5_WINE           wine binary                          (default: the app bundled wine)
#   MT5_TERMINAL_EXE   UNIX path to terminal64.exe          (default: inside the prefix)
set -euo pipefail

PREFIX="${MT5_WINEPREFIX:?set MT5_WINEPREFIX to the account Wine prefix}"
WINE_APP="${MT5_WINE:-/Applications/MetaTrader 5.app/Contents/SharedSupport/wine/bin/wine}"
TERM_EXE="${MT5_TERMINAL_EXE:-$PREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe}"

if [ ! -f "$TERM_EXE" ]; then
    echo "ERROR: terminal not found: $TERM_EXE" >&2
    echo "       did you clone the prefix first? (./new-account-prefix.sh)" >&2
    exit 1
fi

echo "Launching MT5 terminal in prefix: $PREFIX" >&2
export WINEPREFIX="$PREFIX" WINEDEBUG=-all
exec "$WINE_APP" "$TERM_EXE"
