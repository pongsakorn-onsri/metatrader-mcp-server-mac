#!/bin/bash
# macOS (Apple Silicon) launcher for metatrader-mcp-server
#
# Why this is set up the way it is:
#   Generic Homebrew Wine cannot run the MT5 terminal on Apple Silicon (Rosetta
#   translation faults). The official "MetaTrader 5.app" ships its own patched
#   Wine 11.x that CAN. So we run the mt5linux RPyC bridge with the APP's Wine,
#   inside the APP's prefix, where terminal64.exe actually works.
#
# Flow: Claude Code --stdio--> metatrader-mcp-server (native venv Python)
#       --RPyC :18812--> mt5linux (app Wine 11.x, app prefix)
#       --IPC--> terminal64.exe (app Wine)
set -euo pipefail

REPO_DIR="$HOME/metatrader-mcp-server-linux"
VENV_BIN="$REPO_DIR/.venv/bin"

# --- Wine that can run the MT5 terminal (bundled with the macOS app) ---
WINE_APP="/Applications/MetaTrader 5.app/Contents/SharedSupport/wine/bin/wine"
APP_PREFIX="$HOME/Library/Application Support/net.metaquotes.wine.metatrader5"

# Windows Python 3.10 lives in the ~/.mt5 prefix; Wine sees the whole FS as Z:.
# We run it WITH the app Wine and INSIDE the app prefix so the MetaTrader5
# package shares IPC with the terminal launched in that same prefix.
PY_UNIX="$HOME/.mt5/drive_c/users/$USER/AppData/Local/Programs/Python/Python310/python.exe"
PY_WIN="Z:$(printf '%s' "$PY_UNIX" | sed 's#/#\\#g')"

# Start the mt5linux RPyC bridge only if it isn't already up
if ! nc -z 127.0.0.1 18812 2>/dev/null; then
    WINEPREFIX="$APP_PREFIX" WINEDEBUG=-all \
        "$WINE_APP" "$PY_WIN" -m mt5linux > /tmp/mt5linux.log 2>&1 &
    for _ in $(seq 1 20); do
        nc -z 127.0.0.1 18812 2>/dev/null && break
        sleep 1
    done
fi

# Credentials come from the ENVIRONMENT (set them outside this file — e.g. systemd
# EnvironmentFile, `export` in the launching shell, or the "env" block in
# backend/mcp-server.json; run_live passes its whole env down to this process).
# ลบ fallback บัญชีเก่าออกแล้ว — creds (login/password/server) มาจาก env เท่านั้น
# (set ใน backend/.env, mcp-server.json "env", หรือ export ก่อน spawn).
# ถ้า env ไม่ตั้ง = ไม่ส่ง --login/--password/--server → MCP attach กับ MT5 terminal ที่เปิด/login
# อยู่แล้ว (เช่น บัญชี cent ที่ login ค้างใน terminal) — กัน start.sh error ตอน spawn ที่ env ว่าง.
MT5_PATH="${MT5_PATH:-C:\Program Files\MetaTrader 5\terminal64.exe}"

ARGS=(--transport stdio --path "$MT5_PATH")
[ -n "${MT5_LOGIN:-}" ]    && ARGS+=(--login "$MT5_LOGIN")
[ -n "${MT5_PASSWORD:-}" ] && ARGS+=(--password "$MT5_PASSWORD")
[ -n "${MT5_SERVER:-}" ]   && ARGS+=(--server "$MT5_SERVER")
exec "$VENV_BIN/metatrader-mcp-server" "${ARGS[@]}"
