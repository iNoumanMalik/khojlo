"""Firebase Cloud Messaging client (SRS OE-10, CO-11), against a fake HTTP session."""
import json

import pytest
import requests

from app.core.config import settings
from app.services import push
from app.services.push import FcmSender, NullSender, PushMessage

# Captured before the autouse `pushes` fixture swaps it for a recorder.
real_get_sender = push.get_sender


class FakeCredentials:
    valid = True
    token = "ya29.test-access-token"
    project_id = "khojlo-test"


class FakeResponse:
    def __init__(self, status_code, body=None):
        self.status_code = status_code
        self._body = body

    def json(self):
        if self._body is None:
            raise ValueError("no JSON")
        return self._body


class FakeSession:
    """Answers each post from `replies` (keyed by device token); records the requests."""

    def __init__(self, replies):
        self.replies = replies
        self.requests = []

    def post(self, url, headers, data, timeout):
        body = json.loads(data)
        self.requests.append((url, headers, body))
        reply = self.replies[body["message"]["token"]]
        if isinstance(reply, Exception):
            raise reply
        return reply


def fcm_error(status_code, status, message, code=None):
    details = [{"@type": "type.googleapis.com/google.firebase.fcm.v1.FcmError",
                "errorCode": code}] if code else []
    return FakeResponse(status_code, {"error": {"code": status_code, "status": status,
                                                "message": message, "details": details}})


MESSAGE = PushMessage(title="Ali R.", body="Do you deliver to G-9?",
                      data={"route": "/conversations/7", "kind": "message"},
                      tag="conversation-7")


def test_sends_one_request_per_device_with_the_expected_payload():
    session = FakeSession({"a": FakeResponse(200, {"name": "projects/x/messages/1"})})
    result = FcmSender(FakeCredentials(), "khojlo-test", session).send(["a"], MESSAGE)
    assert (result.sent, result.invalid) == (1, [])

    [(url, headers, body)] = session.requests
    assert url == "https://fcm.googleapis.com/v1/projects/khojlo-test/messages:send"
    assert headers["Authorization"] == "Bearer ya29.test-access-token"
    message = body["message"]
    assert message["token"] == "a"
    assert message["notification"] == {"title": "Ali R.", "body": "Do you deliver to G-9?"}
    assert message["data"] == {"route": "/conversations/7", "kind": "message"}
    assert message["android"] == {"priority": "HIGH",
                                  "notification": {"color": "#1D6D5A", "tag": "conversation-7"}}
    assert "validate_only" not in body


def test_validate_only_checks_credentials_without_delivering():
    session = FakeSession({"a": FakeResponse(200, {})})
    FcmSender(FakeCredentials(), "p", session).send(["a"], MESSAGE, validate_only=True)
    assert session.requests[0][2]["validate_only"] is True


def test_reports_tokens_fcm_no_longer_accepts():
    session = FakeSession({
        "ok": FakeResponse(200, {}),
        "uninstalled": fcm_error(404, "NOT_FOUND", "Requested entity was not found.", "UNREGISTERED"),
        "garbled": fcm_error(400, "INVALID_ARGUMENT",
                             "The registration token is not a valid FCM registration token",
                             "INVALID_ARGUMENT"),
        "other-project": fcm_error(403, "PERMISSION_DENIED", "SenderId mismatch",
                                   "SENDER_ID_MISMATCH"),
        # Our payload's fault, not the token's: keep the token.
        "bad-payload": fcm_error(400, "INVALID_ARGUMENT", "Invalid value at 'message.data'",
                                 "INVALID_ARGUMENT"),
        "server-down": FakeResponse(503),
        "offline": requests.ConnectionError("no network"),
    })
    result = FcmSender(FakeCredentials(), "p", session).send(list(session.replies), MESSAGE)
    assert result.sent == 1
    assert result.invalid == ["uninstalled", "garbled", "other-project"]


def test_no_devices_means_no_requests():
    session = FakeSession({})
    assert FcmSender(FakeCredentials(), "p", session).send([], MESSAGE).sent == 0
    assert session.requests == []


def test_credentials_that_cant_authorise_send_nothing():
    class Expired(FakeCredentials):
        valid = False

        def refresh(self, request):
            raise RuntimeError("invalid_grant")

    session = FakeSession({"a": FakeResponse(200, {})})
    assert FcmSender(Expired(), "p", session).send(["a"], MESSAGE).sent == 0
    assert session.requests == []


@pytest.fixture
def no_firebase(monkeypatch):
    for name in ("GOOGLE_APPLICATION_CREDENTIALS", "FIREBASE_PROJECT_ID",
                 "FIREBASE_CLIENT_EMAIL", "FIREBASE_PRIVATE_KEY"):
        monkeypatch.setattr(settings, name, None)
    real_get_sender.cache_clear()
    yield
    real_get_sender.cache_clear()


def test_without_firebase_credentials_push_is_off(no_firebase):
    sender = real_get_sender()
    assert isinstance(sender, NullSender)
    assert sender.send(["a"], MESSAGE).sent == 0


def test_a_wrong_key_file_path_turns_push_off_instead_of_crashing(no_firebase, monkeypatch):
    monkeypatch.setattr(settings, "GOOGLE_APPLICATION_CREDENTIALS", "/nowhere/key.json")
    assert isinstance(real_get_sender(), NullSender)
