import click
import os
from dotenv import load_dotenv
from metatrader_mcp.server import mcp
from metatrader_mcp.utils import resolve_transport_config, run_mcp

@click.command()
@click.option("--login", default=None, type=int, help="MT5 login ID (optional; omit to attach to the terminal's current login)")
@click.option("--password", default=None, help="MT5 password (optional; required only when --login is given)")
@click.option("--server", default=None, help="MT5 server name (optional; required only when --login is given)")
@click.option("--path", default=None, help="Path to MT5 terminal executable (optional, auto-detected if not provided)")
@click.option("--transport", default=None, type=click.Choice(["sse", "stdio", "streamable-http"], case_sensitive=False), help="MCP transport type (default: sse, env: MCP_TRANSPORT)")
@click.option("--host", default=None, help="Host to bind for SSE/HTTP transport (default: 0.0.0.0, env: MCP_HOST)")
@click.option("--port", default=None, type=int, help="Port to bind for SSE/HTTP transport (default: 8080, env: MCP_PORT)")
def main(login, password, server, path, transport, host, port):
    """Launch the MetaTrader MCP server."""
    load_dotenv()
    # Override env vars only when provided via CLI. When omitted, the server
    # attaches to whatever account the MT5 terminal is already logged into
    # (see metatrader_client.connection._login). This is what makes an empty
    # `env: {}` MCP config work against a terminal with a saved login.
    if login is not None:
        os.environ["login"] = str(login)
    if password is not None:
        os.environ["password"] = password
    if server is not None:
        os.environ["server"] = server
    if path:
        os.environ["MT5_PATH"] = path

    transport, host, port = resolve_transport_config(transport, host, port)
    run_mcp(mcp, transport, host, port)

if __name__ == "__main__":
    # pylint: disable=no-value-for-parameter
    main()
