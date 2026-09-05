"""A tiny HTTP client, so the health endpoints are tested over a real socket.

Calling the routing method would prove the routing table; the failure this service exists to make
visible is "the process is up and answers nothing", which only a request over the wire disproves.
"""

from __future__ import annotations

import asyncio
import json
from typing import Any


async def request(port: int, target: str, method: str = "GET") -> tuple[int, dict[str, Any] | None]:
    """Send one HTTP request to a health server and read the answer.

    Args:
        port: Port the server listens on.
        target: Request target, e.g. ``"/readyz"``.
        method: HTTP method.

    Returns:
        The status code, and the decoded JSON body (``None`` when the response carries no body).
    """
    reader, writer = await asyncio.open_connection("127.0.0.1", port)
    head = f"{method} {target} HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
    writer.write(head.encode("latin-1"))
    await writer.drain()
    raw = await asyncio.wait_for(reader.read(), timeout=5)
    writer.close()
    await writer.wait_closed()

    status_line, _, body = raw.partition(b"\r\n\r\n")
    status = int(status_line.split(b" ")[1])
    return status, json.loads(body) if body else None


async def raw_head(port: int, target: str, method: str = "GET") -> str:
    """Send one request and return the response head verbatim.

    Args:
        port: Port the server listens on.
        target: Request target.
        method: HTTP method.

    Returns:
        The status line and headers, as sent on the wire.
    """
    reader, writer = await asyncio.open_connection("127.0.0.1", port)
    writer.write(f"{method} {target} HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n".encode("latin-1"))
    await writer.drain()
    raw = await asyncio.wait_for(reader.read(), timeout=5)
    writer.close()
    await writer.wait_closed()

    return raw.partition(b"\r\n\r\n")[0].decode("latin-1")
