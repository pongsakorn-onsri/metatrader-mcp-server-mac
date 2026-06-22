from typing import Optional, Union
from ..types import TradeRequestActions
from .send_order import send_order
from .get_positions_by_id import get_positions_by_id

def close_position(connection, id: Union[str, int], volume: Optional[Union[str, int, float]] = None,
                   comment: Optional[str] = ""):
    """
    Close a position by its ID, fully or partially.

    Args:
        connection: MetaTrader 5 connection object.
        id: The unique identifier of the position to close.
        volume: Volume in lots to close. If None, the full position volume is
            closed. If less than the position volume, a partial close is
            performed; the remainder stays open.
        comment: Comment attached to the closing deal. On a partial close the
            broker may overwrite the remaining position's comment with this
            value, so pass the owning system's tag (e.g. "ken") to keep the
            remainder attributable.

    Returns:
        A dictionary containing an error flag, a message, and the closed
        position data if successful.
    """

    try:
        position_id = int(id)
    except ValueError:
        return {
            "error": True,
            "message": f"Invalid position ID '{id}', it should be a valid integer",
            "data": None,
        }

    positions = get_positions_by_id(connection, position_id)
    if positions.index.size == 0:
        return {
            "error": True,
            "message": f"Invalid position ID '{id}'",
            "data": None,
        }
    position = positions.iloc[0]
    position_volume = float(position["volume"])

    if volume is None:
        close_volume = position_volume
    else:
        try:
            close_volume = float(volume)
        except (TypeError, ValueError):
            return {
                "error": True,
                "message": f"Invalid volume '{volume}', it should be a valid number",
                "data": None,
            }
        if close_volume <= 0:
            return {
                "error": True,
                "message": "Volume must be greater than zero",
                "data": None,
            }
        if close_volume > position_volume:
            return {
                "error": True,
                "message": f"Volume {close_volume} exceeds position volume {position_volume}",
                "data": None,
            }

    response = send_order(
        connection,
        action=TradeRequestActions.DEAL,
        position=position_id,
        order_type="SELL" if position["type"] == "BUY" else "BUY",
        symbol=position["symbol"],
        volume=close_volume,
        comment=comment or "",
    )
    if response["success"] is False:
        return { "error": True, "message": response["message"], "data": None }
    data = response["data"]
    partial = close_volume < position_volume
    action_word = "Partially close" if partial else "Close"
    return {
        "error": False,
        "message": f"{action_word} position {position_id} ({close_volume} LOT) success at price {getattr(data, 'price', None)}",
        "data": data
    }
