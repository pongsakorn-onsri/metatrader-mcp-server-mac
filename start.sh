#!/bin/bash
# macOS (Apple Silicon) launcher for metatrader-mcp-server.
#
# Flow: Claude Code --stdio--> metatrader-mcp-server (native venv Python)
#       --RPyC :$MT5LINUX_PORT--> mt5linux bridge (app Wine 11.x, MT5 prefix)
#       --IPC--> terminal64.exe (app Wine)  -> ONE trading account
#
# This launches (idempotently) the bridge for the chosen port/prefix, then execs
# the MCP server pointed at that bridge. For MULTIPLE accounts, run one MCP
# server per account, each with its own MT5LINUX_PORT + MT5_WINEPREFIX + creds —
# register each as a separate MCP server in Claude Code. See examples/ and
# LINUX_SETUP.md ("Running multiple accounts").
#
# Env knobs (all optional):
#   MT5LINUX_PORT    bridge port for THIS account         (default 18812)
#   MT5_WINEPREFIX   Wine prefix for THIS account          (default the app prefix)
#   MT5_LOGIN        MT5 login                             (from environment)
#   MT5_PASSWORD     MT5 password                          (from environment)
#   MT5_SERVER       MT5 server name                       (from environment)
#   MT5_PATH         terminal64.exe path (Windows-style)   (default standard install)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_BIN="$REPO_DIR/.venv/bin"

# Port the MCP server's MetaTrader5 shim connects to. Exported so the shim
# (src/MetaTrader5.py) talks to the right bridge for this account.
export MT5LINUX_PORT="${MT5LINUX_PORT:-18812}"
export MT5LINUX_HOST="${MT5LINUX_HOST:-127.0.0.1}"

# Ensure the bridge for this port/prefix is up (idempotent).
MT5LINUX_PORT="$MT5LINUX_PORT" MT5LINUX_HOST="$MT5LINUX_HOST" \
    "$REPO_DIR/bridge.sh"

# Credentials come from the ENVIRONMENT (set them outside this file — e.g. an
# EnvironmentFile, `export` in the launching shell, or the "env" block in the
# MCP server config). If unset, no --login/--password/--server is passed and the
# server attaches to whatever account the terminal is already logged into.
MT5_PATH="${MT5_PATH:-C:\Program Files\MetaTrader 5\terminal64.exe}"

ARGS=(--transport stdio --path "$MT5_PATH")
[ -n "${MT5_LOGIN:-}" ]    && ARGS+=(--login "$MT5_LOGIN")
[ -n "${MT5_PASSWORD:-}" ] && ARGS+=(--password "$MT5_PASSWORD")
[ -n "${MT5_SERVER:-}" ]   && ARGS+=(--server "$MT5_SERVER")
exec "$VENV_BIN/metatrader-mcp-server" "${ARGS[@]}"
