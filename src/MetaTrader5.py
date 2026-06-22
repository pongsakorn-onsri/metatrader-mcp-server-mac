# Shim to redirect `import MetaTrader5` to the mt5linux RPyC bridge.
#
# The bridge runs inside Wine and listens on a TCP port. Which bridge this
# process talks to is chosen by environment variables, so several MCP/HTTP
# server processes can each connect to a different bridge (= a different MT5
# terminal = a different trading account) on the same machine:
#
#     MT5LINUX_HOST   bridge host   (default 127.0.0.1)
#     MT5LINUX_PORT   bridge port   (default 18812)
#
# Account A -> MT5LINUX_PORT=18812 -> bridge/terminal A
# Account B -> MT5LINUX_PORT=18813 -> bridge/terminal B
import os
import sys
from mt5linux import MetaTrader5

# Re-export everything so "import MetaTrader5" and "from MetaTrader5 import X" both work
mt5 = MetaTrader5(
    host=os.getenv("MT5LINUX_HOST", "127.0.0.1"),
    port=int(os.getenv("MT5LINUX_PORT", "18812")),
)
sys.modules[__name__] = mt5
