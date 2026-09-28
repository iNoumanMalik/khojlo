"""Live events to the app over WebSockets (Module 9: new messages, "Seen", typing).

Each signed-in app keeps one socket open while it's in the foreground and closes it in the
background, so "has an open socket" doubles as "is looking at the app": messages to users
without one are pushed through Firebase instead (SRS PER-6, REL-5).

The registry lives in this process, so the API must run as a single worker. Several
workers would need a shared channel (e.g. PostgreSQL LISTEN/NOTIFY) between them.
"""
from __future__ import annotations

import logging
from collections import defaultdict
from typing import Any

from fastapi import WebSocket

log = logging.getLogger("uvicorn.error")


class ConnectionManager:
    def __init__(self) -> None:
        self._sockets: dict[int, set[WebSocket]] = defaultdict(set)

    def add(self, user_id: int, socket: WebSocket) -> None:
        self._sockets[user_id].add(socket)

    def remove(self, user_id: int, socket: WebSocket) -> None:
        sockets = self._sockets.get(user_id)
        if sockets is None:
            return
        sockets.discard(socket)
        if not sockets:
            del self._sockets[user_id]

    def is_online(self, user_id: int) -> bool:
        return bool(self._sockets.get(user_id))

    async def send(self, user_id: int, event: dict[str, Any]) -> None:
        for socket in list(self._sockets.get(user_id, ())):
            try:
                await socket.send_json(event)
            except Exception:  # closed without a clean disconnect
                self.remove(user_id, socket)

    async def publish(self, events: dict[int, dict[str, Any]]) -> None:
        """Send each user their own event (e.g. `is_mine` differs per participant)."""
        for user_id, event in events.items():
            await self.send(user_id, event)


manager = ConnectionManager()
