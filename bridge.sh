#!/bin/bash
# Start ONE mt5linux RPyC bridge (idempotent) for a single MT5 terminal/account.
#
# Generic Homebrew Wine cannot run the MT5 terminal on Apple Silicon (Rosetta
# translation faults). The official "MetaTrader 5.app" ships its own patched
# Wine 11.x that CAN, so we run the bridge with the APP's Wine, inside an MT5
# Wine prefix, where terminal64.exe actually works.
#
# Multi-account: run this once per account with a distinct PORT *and* a distinct
# WINEPREFIX (so each bridge drives its own terminal = its own login):
#
#     MT5LINUX_PORT=18812 MT5_WINEPREFIX="$HOME/.mt5-accountA" ./bridge.sh
#     MT5LINUX_PORT=18813 MT5_WINEPREFIX="$HOME/.mt5-accountB" ./bridge.sh
#
# Env knobs (all optional, sensible single-account defaults):
#   MT5LINUX_PORT    TCP port the bridge listens on            (default 18812)
#   MT5LINUX_HOST    bind address                              (default 127.0.0.1)
#   MT5_WINEPREFIX   Wine prefix the bridge/terminal runs in   (default the app prefix)
#   MT5_WINE         path to the wine binary                   (default the app's bundled wine)
#   MT5_WIN_PYTHON   UNIX path to the Windows python.exe       (default the ~/.mt5 Python 3.10)
set -euo pipefail

PORT="${MT5LINUX_PORT:-18812}"
HOST="${MT5LINUX_HOST:-127.0.0.1}"

WINE_APP="${MT5_WINE:-/Applications/MetaTrader 5.app/Contents/SharedSupport/wine/bin/wine}"
WINEPREFIX_DIR="${MT5_WINEPREFIX:-$HOME/Library/Application Support/net.metaquotes.wine.metatrader5}"

# Windows Python (under Wine the whole FS is mounted as Z:). The MetaTrader5
# package must be installed in THIS python's site-packages inside the prefix.
PY_UNIX="${MT5_WIN_PYTHON:-$HOME/.mt5/drive_c/users/$USER/AppData/Local/Programs/Python/Python310/python.exe}"
PY_WIN="Z:$(printf '%s' "$PY_UNIX" | sed 's#/#\\#g')"

# Already up? Nothing to do (lets start.sh / manual runs be re-invoked safely).
if nc -z "$HOST" "$PORT" 2>/dev/null; then
    echo "bridge: already listening on $HOST:$PORT" >&2
    exit 0
fi

LOGFILE="/tmp/mt5linux-${PORT}.log"
echo "bridge: starting on $HOST:$PORT (prefix: $WINEPREFIX_DIR, log: $LOGFILE)" >&2
WINEPREFIX="$WINEPREFIX_DIR" WINEDEBUG=-all \
    "$WINE_APP" "$PY_WIN" -m mt5linux --host "$HOST" -p "$PORT" > "$LOGFILE" 2>&1 &

# Wait up to ~20s for the port to come up.
for _ in $(seq 1 20); do
    nc -z "$HOST" "$PORT" 2>/dev/null && { echo "bridge: ready on $HOST:$PORT" >&2; exit 0; }
    sleep 1
done

echo "bridge: FAILED to come up on $HOST:$PORT — see $LOGFILE" >&2
exit 1
