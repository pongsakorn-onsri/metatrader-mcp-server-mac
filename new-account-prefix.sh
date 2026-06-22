#!/bin/bash
# Clone the working MT5 Wine prefix into a NEW prefix so a second (third, …)
# account can run fully isolated — its own terminal, its own login, its own
# bridge port. On Apple-Silicon Wine, copying the known-good prefix is far more
# reliable than building a fresh one, because the app's bundled Wine config and
# the installed terminal come along intact.
#
# The shared Windows Python (in ~/.mt5) is NOT part of this prefix and is reached
# via Wine's Z: mapping, so it does not need copying.
#
# Usage:
#   ./new-account-prefix.sh <target-prefix-dir>
#   ./new-account-prefix.sh "$HOME/.mt5-accountB"
#
# Env:
#   MT5_SRC_PREFIX   prefix to clone from   (default: the MetaTrader 5.app prefix)
#   KEEP_CACHE=1     copy everything incl. price-history/logs caches (bigger, slower)
#   FORCE=1          overwrite a non-empty target
set -euo pipefail

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
    echo "usage: $0 <target-prefix-dir>   e.g. $0 \"\$HOME/.mt5-accountB\"" >&2
    exit 2
fi

SRC="${MT5_SRC_PREFIX:-$HOME/Library/Application Support/net.metaquotes.wine.metatrader5}"

# --- validation -----------------------------------------------------------
if [ ! -f "$SRC/drive_c/Program Files/MetaTrader 5/terminal64.exe" ]; then
    echo "ERROR: source prefix has no MT5 terminal: $SRC" >&2
    echo "       set MT5_SRC_PREFIX to a working prefix." >&2
    exit 1
fi
# Normalise (strip trailing slash) and refuse self/overlap copies.
TARGET="${TARGET%/}"
SRC="${SRC%/}"
if [ "$TARGET" = "$SRC" ]; then
    echo "ERROR: target equals source prefix." >&2
    exit 1
fi
case "$TARGET/" in
    "$SRC"/*) echo "ERROR: target is inside the source prefix." >&2; exit 1 ;;
esac
if [ -e "$TARGET" ] && [ -n "$(ls -A "$TARGET" 2>/dev/null)" ] && [ "${FORCE:-0}" != "1" ]; then
    echo "ERROR: target exists and is not empty: $TARGET" >&2
    echo "       remove it or re-run with FORCE=1 to overwrite." >&2
    exit 1
fi

# --- disk-space heads-up --------------------------------------------------
echo "Source prefix : $SRC ($(du -sh "$SRC" 2>/dev/null | cut -f1))"
echo "Target prefix : $TARGET"
echo "Free on \$HOME : $(df -h "$HOME" | awk 'NR==2{print $4}')"
echo

# --- copy -----------------------------------------------------------------
EXCLUDES=()
if [ "${KEEP_CACHE:-0}" != "1" ]; then
    # Regenerable caches — re-downloaded/rebuilt by the terminal on first use.
    EXCLUDES=(
        --exclude 'Bases/'   --exclude 'bases/'
        --exclude 'Tester/'  --exclude 'tester/'
        --exclude 'Logs/'    --exclude 'logs/'
        --exclude 'temp/'    --exclude 'Temp/'
    )
    echo "Skipping price-history/log caches (set KEEP_CACHE=1 to include them)."
fi

mkdir -p "$TARGET"
echo "Cloning prefix (this can take a few minutes)…"
rsync -a --info=progress2 "${EXCLUDES[@]}" "$SRC/" "$TARGET/"

echo
echo "Done. New prefix: $TARGET ($(du -sh "$TARGET" 2>/dev/null | cut -f1))"
cat <<EOF

Next steps for this account:

  1. (recommended once) launch its terminal and log into the account:
       MT5_WINEPREFIX="$TARGET" ./launch-terminal.sh
     Log in to the target trading account, tick "save", then quit.

  2. start its bridge on a free port (use a different port per account):
       MT5LINUX_PORT=18813 MT5_WINEPREFIX="$TARGET" ./bridge.sh

  3. run a server against it (manual), pointing the shim at that port:
       export MT5LINUX_PORT=18813
       .venv/bin/metatrader-http-server --login <L> --password '<P>' --server <S> \\
           --path 'C:\\Program Files\\MetaTrader 5\\terminal64.exe' --port 8001
     …or register start.sh as a second MCP server in Claude Code with
     MT5LINUX_PORT=18813 and MT5_WINEPREFIX="$TARGET" (see examples/).
EOF
