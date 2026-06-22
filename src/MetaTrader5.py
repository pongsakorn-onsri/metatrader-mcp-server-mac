# Shim to redirect MetaTrader5 imports to mt5linux on Linux
from mt5linux import MetaTrader5
import sys

# Re-export everything so "import MetaTrader5" and "from MetaTrader5 import X" both work
mt5 = MetaTrader5()
sys.modules[__name__] = mt5
