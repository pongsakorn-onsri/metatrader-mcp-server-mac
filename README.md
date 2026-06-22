<div align="center">
  <h1>MetaTrader MCP Server — Linux Edition</h1>
  <p><strong>Use AI assistants (Claude Code, Ollama) to trade on MetaTrader 5 — on Linux</strong></p>
</div>

<br />

<div align="center">

[![Python 3.10+](https://img.shields.io/badge/python-3.10+-blue.svg)](https://www.python.org/downloads/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: Linux](https://img.shields.io/badge/platform-Linux-lightgrey.svg)]()

</div>

<br />

---

## Why This Exists

**Claude Desktop** — the simplest way to connect MCP servers on Windows and Mac — **is not available on Linux**.

This repo makes MetaTrader MCP work on Linux by bridging the Windows-only `MetaTrader5` Python package through Wine using `mt5linux`. Once set up, you can use:

- **Claude Code** (Anthropic's CLI) — fully confirmed working
- **Ollama local LLMs** (qwen2.5:7b-instruct, qwen3-8b-instruct, etc.) — fully confirmed working
- Any other MCP-compatible client

---

## Credits

This project is built on the shoulders of two open source projects:

- **[ariadng/metatrader-mcp-server](https://github.com/ariadng/metatrader-mcp-server)** by [@ariadng](https://github.com/ariadng) — the original MCP server implementation. All the core trading logic, MCP tools, and server architecture come from his work. Go star his repo.

- **[lucas-campagna/mt5linux](https://github.com/lucas-campagna/mt5linux)** by [@lucas-campagna](https://github.com/lucas-campagna) — the RPyC bridge that makes it possible to run the `MetaTrader5` Python package on Linux via Wine. Without this, none of this would work on Linux.

**What we added:** the Linux compatibility patches, the `mt5linux` shim, the `start.sh` wrapper, and this documentation.

---

## ⚠️ Important Disclaimer

Trading financial instruments involves significant risk of loss. This software is provided as-is, and the developers accept **no liability** for any trading losses, gains, or consequences of using this software. This is not financial advice. Always trade responsibly.

---

## How It Works

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

## Quick Start

See the full step-by-step guide: **[LINUX_SETUP.md](LINUX_SETUP.md)**

It covers everything from installing Windows Python inside Wine to registering the MCP server with Claude Code or Ollama — including all the gotchas we ran into.

**The short version:**

```bash
# 1. Install Windows Python 3.10 inside your MT5 Wine prefix
WINEPREFIX=~/.mt5 wine python-3.10.11-amd64.exe /quiet InstallAllUsers=0 PrependPath=1

# 2. Install MetaTrader5 + mt5linux inside Wine Python
WINEPREFIX=~/.mt5 wine python -m pip install MetaTrader5 mt5linux "numpy<2.0"

# 3. Install mt5linux on native Linux Python
pip install mt5linux

# 4. Clone and install this repo
git clone https://github.com/ESSIEM1/metatrader-mcp-server-linux.git
cd metatrader-mcp-server-linux
pip install -e .

# 5. Edit start.sh with your credentials, then register with Claude Code
claude mcp add --transport stdio metatrader -- /home/$USER/metatrader-mcp-server-linux/start.sh
```

---

## Features

Everything from the original [ariadng/metatrader-mcp-server](https://github.com/ariadng/metatrader-mcp-server), plus Linux support:

- **25 MCP tools** — account info, market data, order execution, position management, trading history
- **Natural language trading** — "Buy 0.01 lots of EURUSD" or "Close all losing positions"
- **Claude Code** — works via stdio MCP transport
- **Ollama local LLMs** — confirmed working with Gemma4, gpt-oss, qwen3.5:9b, llama3.1:8b
- **SSE/HTTP transport** — for remote or Ollama connections
- **WebSocket quote server** — real-time tick streaming

---

## Available Tools

### Account
- `get_account_info` — balance, equity, margin, leverage

### Market Data
- `get_symbols`, `get_symbol_price`, `get_symbol_info`
- `get_candles_latest`, `get_candles_by_date`

### Orders
- `place_market_order`, `place_pending_order`
- `modify_position`, `modify_pending_order`

### Positions
- `get_all_positions`, `close_position`, `close_all_positions`
- `close_all_profitable_positions`, `close_all_losing_positions`

### Pending Orders
- `get_all_pending_orders`, `cancel_pending_order`, `cancel_all_pending_orders`

### History
- `get_deals`, `get_orders`

---

## Ollama Support

Confirmed working models:

| Model | Tool use | Notes |
|-------|----------|-------|
| `qwen2.5:7b-instruct` | ✅ confirmed | Recommended — fast, reliable tool use |
| `qcwind/qwen3-8b-instruct-Q4-K-M` | ✅ confirmed | Good for trading logic — more agentic behavior |
| `qwen3.5:9b` | ⚠️ | Fast, lightweight |
| `llama3.1:8b` | ⚠️ | Decent tool support — sometimes forgets tools |
| `deepseek-r1:14b` | ⚠️ | Reasoning model — tool support varies |

See [LINUX_SETUP.md](LINUX_SETUP.md) for Ollama setup instructions.

---

## IMPOTANT RUNNING INFORMATION

1) Make sure you run `claude code` or `ollama launch claude` inside the folder:

`~/metatrader-mcp-server-linux`

(or `~/metatrader-mcp-server` if you have modified the original MCP from *[Aria Dhanang](https://github.com/ariadng)* and manually added our `LINUX_SETUP.md` patches.)

Failing to do so will result in the MCP server and tools being unavailable to Claude or local LLMs.

2) Many small llms are not able to find the mcp tools.
   Make sure you use an "Instruct" model such as "qwen2.5:7b-instruct" or "qcwind/qwen3-8b-instruct-Q4-K-M", both tested and confirmed working and available at https://ollama.com/

3) Running `ollama launch claude` should automatically run the script, opening and connecting to MT5. If your model is not communicating with MT5, make sure MT5 is open or run the script manually:
   `~/metatrader-mcp-server/start.sh` in a different terminal tab.

---

## Launching

a) Using Claude CLI

cd ~/metatrader-mcp-server-linux
claude

Then inside the CLI:

Using the metatrader-mcp-server tools, give me the account balance.
    
B) Using Ollama

cd ~/metatrader-mcp-server-linux
ollama launch claude

Then:

Select model: qwen2.5:7b-instruct
Enter prompt:
Using the metatrader-mcp-server tools, give me the account balance.

---

## Tested Environment

| Component | Version |
|-----------|---------|
| OS | Debian 13 Trixie |
| Kernel | Linux 6.12.88+deb13-amd64 |
| Wine | 10.0 |
| MT5 build | 5833 |
| Windows Python (Wine) | 3.10.11 |
| Linux Python | 3.11.9 |
| MetaTrader5 package | 5.0.5735 |
| Claude Code | v2.1.153 |
| Ollama + qwen2.5:7b-instruct and qwen3-8b-instruct-Q4-K-M | confirmed working |
| CPU: AMD EPYC 7551P 32-Core (64) |
| GPU: NVIDIA RTX 3060 12GB |
| MEMORY: 256GB 2667 ECC |

---

## License

MIT — same as the original project. See [LICENSE](LICENSE).

---

<div align="center">

**Linux patches by [ESSIEM1](https://github.com/ESSIEM1)**

Original MCP server by **[Aria Dhanang](https://github.com/ariadng)** • mt5linux bridge by **[Lucas Campagna](https://github.com/lucas-campagna)**

⭐ If this helped you, star the original repos too!

</div>
