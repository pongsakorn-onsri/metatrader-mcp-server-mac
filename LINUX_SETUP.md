# MetaTrader MCP Server — Linux Setup Guide

> **Running MetaTrader 5 on Linux (Wine) with Claude Code, Ollama local LLMs, or any MCP-compatible AI client**

> **Why this guide exists:** Claude Desktop — the easiest way to connect MCP servers on Windows and Mac — is not available on Linux. This guide provides a working alternative using Claude Code (the CLI) and/or Ollama local LLMs, both of which support MCP on Linux.

This guide documents how to connect `metatrader-mcp-server` to a MetaTrader 5 terminal running under Wine on Linux (Debian/Ubuntu). The official `MetaTrader5` Python package is Windows-only, so we use a bridge called `mt5linux` to proxy calls from native Linux Python into the Wine environment.

Once set up, the MCP server works with **any MCP-compatible client** — including Claude Code and local LLMs running via Ollama (confirmed working with Gemma4 and other tool-capable models).

---

## Architecture

```
Claude Code  ──────────────────────┐
                                   │  stdio
Ollama (Gemma4, gpt-oss, etc.)  ───┤
                                   ↓
              metatrader-mcp-server  (native Linux Python)
                                   ↓  RPyC over TCP :18812
              mt5linux bridge  (Windows Python inside Wine)
                                   ↓  Windows IPC
              MetaTrader 5 terminal  (Wine)
```

---

## Prerequisites

- Debian/Ubuntu Linux (tested on Debian 13, Wine 10.0)
- MetaTrader 5 installed via the [official Metaquotes Linux installer](https://www.metatrader5.com/en/terminal/help/start_advanced/install_linux)
- Python 3.10+ (native Linux) — tested with 3.11.9 via pyenv
- Claude Code installed (`npm install -g @anthropic-ai/claude-code`)
- An MT5 trading account (demo or live): login, password, server name

---

## Step 1 — Find your Wine prefix

The official Metaquotes installer creates a Wine prefix (usually `~/.mt5`). Confirm the location:

```bash
find ~/ -name "terminal64.exe" 2>/dev/null
```

Expected output:
```
/home/<user>/.mt5/drive_c/Program Files/MetaTrader 5/terminal64.exe
```

All subsequent Wine commands use `WINEPREFIX=~/.mt5`.

---

## Step 2 — Install Windows Python 3.10 inside Wine

The `MetaTrader5` Python package requires a Windows Python running inside the same Wine prefix as MT5.

```bash
cd /tmp
wget https://www.python.org/ftp/python/3.10.11/python-3.10.11-amd64.exe
WINEPREFIX=~/.mt5 wine /tmp/python-3.10.11-amd64.exe /quiet InstallAllUsers=0 PrependPath=1
```

Verify:
```bash
WINEPREFIX=~/.mt5 wine python --version
# Python 3.10.11
```

> **Note:** The installer may print some harmless Wine `windowscodecs.dll` errors — ignore them.

---

## Step 3 — Install MetaTrader5 and mt5linux inside Wine Python

```bash
WINEPREFIX=~/.mt5 wine python -m pip install MetaTrader5
WINEPREFIX=~/.mt5 wine python -m pip install mt5linux
```

Then downgrade numpy to avoid a `ucrtbase.dll crealf` crash on Wine:

```bash
WINEPREFIX=~/.mt5 wine python -m pip install "numpy<2.0"
```

> **Why numpy<2.0?** numpy 2.x requires `crealf` from `ucrtbase.dll` which Wine 10.0 does not fully implement yet.

---

## Step 4 — Install mt5linux on native Linux Python

```bash
pip install mt5linux
```

---

## Step 5 — Test the bridge

Make sure MT5 terminal is open and logged in, then start the RPyC bridge:

```bash
WINEPREFIX=~/.mt5 wine python -m mt5linux &
```

Wait for:
```
INFO SLAVE/18812[MainThread]: server started on [127.0.0.1]:18812
```

> The `ntlm_auth` warnings are harmless — ignore them.

Now test from native Linux Python:

```bash
python3 -c "
from mt5linux import MetaTrader5
mt5 = MetaTrader5()
print(mt5.initialize())
print(mt5.terminal_info())
mt5.shutdown()
"
```

Expected output: `True` followed by a `TerminalInfo(...)` object showing `connected=True`.

---

## Step 6 — Clone and install the MCP server

```bash
cd ~
git clone https://github.com/ESSIEM1/metatrader-mcp-server.git
cd metatrader-mcp-server
```

The `MetaTrader5` package is not available on Linux PyPI, so we need two patches:

### Patch 1 — Create a shim that redirects imports to mt5linux

```bash
cat > ~/metatrader-mcp-server/src/MetaTrader5.py << 'EOF'
# Shim to redirect MetaTrader5 imports to mt5linux on Linux
from mt5linux import MetaTrader5
import sys

mt5 = MetaTrader5()
sys.modules[__name__] = mt5
EOF
```

### Patch 2 — Remove the MetaTrader5 pip dependency

```bash
sed -i 's/.*MetaTrader5.*//' ~/metatrader-mcp-server/pyproject.toml
```

### Install

```bash
pip install -e .
```

Verify the CLI is available:
```bash
which metatrader-mcp-server
```

---

## Step 7 — Create the startup script

Claude Code launches the MCP server via stdio. We need a wrapper that starts the mt5linux bridge first (if not already running), then launches the MCP server:

```bash
cat > ~/metatrader-mcp-server/start.sh << 'EOF'
#!/bin/bash

# Start mt5linux bridge only if not already running
if ! nc -z 127.0.0.1 18812 2>/dev/null; then
    WINEPREFIX=~/.mt5 wine python -m mt5linux &
    sleep 3
fi

# Start the MCP server
metatrader-mcp-server \
    --login YOUR_LOGIN \
    --password 'YOUR_PASSWORD' \
    --server YOUR_SERVER \
    --transport stdio \
    --path 'C:\Program Files\MetaTrader 5\terminal64.exe'
EOF
chmod +x ~/metatrader-mcp-server/start.sh
```

Replace `YOUR_LOGIN`, `YOUR_PASSWORD`, and `YOUR_SERVER` with your actual credentials.
The server name is visible in MT5 under **File → Login to Trade Account** (e.g. `MetaQuotes-Demo`, `YourBroker-Demo`).

> **Passwords with special characters** (e.g. `$`): wrap in single quotes in the shell — they are treated as literals inside single quotes.

Test the script manually first:
```bash
bash ~/metatrader-mcp-server/start.sh
```

Expected output:
```
INFO  Successfully connected to MetaTrader 5 terminal
```

---

## Step 8 — Register with Claude Code

```bash
claude mcp add --transport stdio metatrader -- /home/$USER/metatrader-mcp-server/start.sh
```

Verify:
```bash
claude mcp list
```

---

## Step 9 — Connect and verify

Launch Claude Code from the project directory:
```bash
claude
```

Type `/mcp` — you should see:
```
metatrader · ✔ connected · 25 tools
```

You're connected! Try:
- *"What's my account balance?"*
- *"Show me the current price of XAUUSD"*
- *"List my open positions"*

---

## Using with Ollama (Local LLMs)

The MCP server works with local LLMs via Ollama — confirmed working with **Gemma4** and any other model that supports tool use.

### Install Ollama

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

Pull a tool-capable model:

```bash
ollama pull gemma4        # recommended, confirmed working
ollama pull gpt-oss       # also works
ollama pull qwen3.5:9b    # good balance of speed and capability
```

### Connect Ollama to the MCP server

The MCP server exposes an SSE/HTTP transport in addition to stdio. Start it in HTTP mode:

```bash
metatrader-mcp-server \
    --login YOUR_LOGIN \
    --password 'YOUR_PASSWORD' \
    --server YOUR_SERVER \
    --transport sse \
    --path 'C:\Program Files\MetaTrader 5\terminal64.exe'
```

This starts an SSE server on `http://0.0.0.0:8080` by default.

Then point your Ollama-compatible MCP host (e.g. [mcphost](https://github.com/mark3labs/mcphost), [ollama-mcp](https://github.com/rawwerks/ollama-mcp), or any OpenAI-compatible wrapper with MCP support) at it.

### Using with Claude Code + Ollama via `ollama` CLI

If your MCP host supports it, you can also run `ollama` with the same stdio `start.sh` script — Claude Code detected the 25 MT5 tools when launched via Ollama in our tests.

### Which models support tool use?

| Model | Tool use | Notes |
|-------|----------|-------|
| `gemma4` | ✅ confirmed | Recommended |
| `gpt-oss` | ✅ confirmed | Good for trading logic |
| `qwen3.5:9b` | ✅ | Fast, lightweight |
| `llama3.1:8b` | ✅ | Decent tool support |
| `deepseek-r1:14b` | ⚠️ | Reasoning model, tool support varies |

> Models must support function/tool calling to use MCP tools. Check the model's Ollama page if unsure.

---

## Troubleshooting

**`No module named mt5linux`** when starting the bridge
→ Install mt5linux inside Wine Python: `WINEPREFIX=~/.mt5 wine python -m pip install mt5linux`

**`ucrtbase.dll crealf` crash / numpy error**
→ Downgrade numpy: `WINEPREFIX=~/.mt5 wine python -m pip install "numpy<2.0"`

**`OSError: [WinError 10048]` when starting bridge**
→ Bridge is already running on port 18812. This is fine — the `start.sh` script handles this with the `nc` check.

**`Invalid "path" argument (Error code: -2)`**
→ Make sure `--path 'C:\Program Files\MetaTrader 5\terminal64.exe'` is passed to the MCP server.

**`EOFError: connection closed by peer`**
→ The bridge crashed, usually due to a numpy version issue. See numpy fix above.

**MCP shows `✘ failed` in Claude Code**
→ Run `bash ~/metatrader-mcp-server/start.sh` directly to see the actual error.

---

## Making the bridge persistent (optional)

To avoid manually starting the bridge before Claude Code, add it to your shell profile or create a systemd user service:

```bash
# Add to ~/.bashrc or ~/.zshrc
if ! nc -z 127.0.0.1 18812 2>/dev/null; then
    WINEPREFIX=~/.mt5 wine python -m mt5linux > /tmp/mt5linux.log 2>&1 &
fi
```

---

## Credits

This project is a fork of [ariadng/metatrader-mcp-server](https://github.com/ariadng/metatrader-mcp-server) — all credit for the original MCP server implementation goes to [@ariadng](https://github.com/ariadng). This fork adds Linux compatibility via the Wine + mt5linux bridge approach documented in this guide.

The [mt5linux](https://github.com/lucas-campagna/mt5linux) library by [@lucas-campagna](https://github.com/lucas-campagna) is what makes the whole thing possible on Linux — it provides the RPyC bridge between native Linux Python and the Windows `MetaTrader5` package running inside Wine.

---

## Tested environment

| Component | Version |
|-----------|---------|
| OS | Debian 13 |
| Wine | 10.0 (Debian 10.0~repack-6) |
| MT5 build | 5833 |
| Windows Python (Wine) | 3.10.11 |
| Linux Python | 3.11.9 (pyenv) |
| MetaTrader5 package | 5.0.5735 |
| numpy (Wine) | 1.26.4 |
| mt5linux | latest |
| Claude Code | v2.1.153 |
| Ollama | latest |
| Gemma4 | confirmed working with MCP tools |
