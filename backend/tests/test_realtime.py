"""Module 9 — live delivery over the WebSocket (SRS FR-24 "in real time", PER-6)."""
import pytest
from starlette.websockets import WebSocketDisconnect

from app.services.realtime import manager
from tests.test_chat import business, ali, make_user, open_chat, owner, send, token_of  # noqa: F401

P = "/api/v1"
WS = f"{P}/ws"


def connect(client, headers):
    """Open an authenticated socket (use as a context manager)."""
    socket = client.websocket_connect(WS)
    ws = socket.__enter__()
    ws.send_json({"type": "auth", "token": token_of(headers)})
    assert ws.receive_json() == {"type": "ready"}
    return socket, ws


@pytest.mark.parametrize("first", [
    {"type": "auth", "token": "not-a-token"},
    {"type": "auth"},
    {"type": "ping"},
])
def test_sockets_must_authenticate_first(client, first):
    with client.websocket_connect(WS) as ws:
        ws.send_json(first)
        with pytest.raises(WebSocketDisconnect) as closed:
            ws.receive_json()
    assert closed.value.code == 4401


def test_a_refresh_token_is_not_enough(client, ali):
    refresh = client.post(f"{P}/auth/login", json={"email": "ali@khojlo.app",
                                                   "password": "password123"}).json()["refresh_token"]
    with client.websocket_connect(WS) as ws:
        ws.send_json({"type": "auth", "token": refresh})
        with pytest.raises(WebSocketDisconnect) as closed:
            ws.receive_json()
    assert closed.value.code == 4401


def test_ping_pong_and_presence(client, ali):
    socket, ws = connect(client, ali)
    try:
        ws.send_json({"type": "ping"})
        assert ws.receive_json() == {"type": "pong"}
        assert len(manager._sockets) == 1
    finally:
        socket.__exit__(None, None, None)
    assert manager._sockets == {}  # gone once the app disconnects


def test_owner_receives_a_new_message_live_and_gets_no_push(client, business, ali, owner, pushes):
    client.put(f"{P}/notifications/devices", headers=owner,
               json={"token": "owner-phone-token-1", "platform": "android"})
    chat = open_chat(client, ali, business)
    socket, ws = connect(client, owner)
    try:
        sent = send(client, ali, chat["id"], "Do you deliver to G-9?").json()
        event = ws.receive_json()
    finally:
        socket.__exit__(None, None, None)
    assert event["type"] == "message.new"
    assert event["conversation_id"] == chat["id"]
    assert event["message"]["id"] == sent["id"] and not event["message"]["is_mine"]
    assert event["conversation"]["my_side"] == "business"
    assert event["conversation"]["unread_count"] == 1 and event["unread_total"] == 1
    assert pushes.sent == []  # the owner is looking at the app


def test_the_senders_other_devices_get_their_own_message(client, business, ali):
    chat = open_chat(client, ali, business)
    socket, ws = connect(client, ali)
    try:
        send(client, ali, chat["id"], "Hello", client_id="abc-123")
        event = ws.receive_json()
    finally:
        socket.__exit__(None, None, None)
    assert event["message"]["is_mine"] and event["message"]["client_id"] == "abc-123"
    assert event["unread_total"] == 0


def test_seen_receipt_reaches_the_customer(client, business, ali, owner):
    chat = open_chat(client, ali, business)
    sent = send(client, ali, chat["id"]).json()
    socket, ws = connect(client, ali)
    try:
        client.post(f"{P}/conversations/{chat['id']}/read", headers=owner)
        event = ws.receive_json()
    finally:
        socket.__exit__(None, None, None)
    assert event == {"type": "conversation.read", "conversation_id": chat["id"],
                     "side": "business", "last_read_id": sent["id"]}


def test_typing_is_forwarded_only_between_participants(client, business, ali, owner):
    chat = open_chat(client, ali, business)
    bob = make_user(client, "bob@khojlo.app")
    owner_socket, owner_ws = connect(client, owner)
    ali_socket, ali_ws = connect(client, ali)
    bob_socket, bob_ws = connect(client, bob)
    try:
        bob_ws.send_json({"type": "typing", "conversation_id": chat["id"]})  # not his: ignored
        bob_ws.send_json({"type": "ping"})
        assert bob_ws.receive_json() == {"type": "pong"}  # bob's typing was handled first

        ali_ws.send_json({"type": "typing", "conversation_id": chat["id"]})
        assert owner_ws.receive_json() == {"type": "typing", "conversation_id": chat["id"],
                                           "side": "customer"}
        owner_ws.send_json({"type": "ping"})
        assert owner_ws.receive_json() == {"type": "pong"}  # nothing from bob in between
    finally:
        for socket in (bob_socket, ali_socket, owner_socket):
            socket.__exit__(None, None, None)
