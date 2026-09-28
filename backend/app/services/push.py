"""Sending push notifications through Firebase Cloud Messaging (SRS OE-10, CO-11).

`PushSender` hides the provider, as `MapService` does for maps. `FcmSender` calls the FCM
HTTP v1 API with the project's service account. It uses `google-auth` and `requests`
(already dependencies) rather than the `firebase-admin` SDK, whose gRPC wheels lag behind
new Python releases. Without Firebase credentials `NullSender` is used, so the rest of the
app works unchanged, as Maps does without its key.
"""
from __future__ import annotations

import json
import logging
from dataclasses import dataclass, field
from functools import lru_cache
from typing import Protocol

import requests

from app.core.config import settings

log = logging.getLogger("uvicorn.error")

FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
FCM_URL = "https://fcm.googleapis.com/v1/projects/{project}/messages:send"
# Android notification accent (Khojlo emerald).
ACCENT = "#1D6D5A"


@dataclass(frozen=True)
class PushMessage:
    title: str
    body: str
    # Delivered to the app; `route` is the screen to open when the notification is tapped.
    data: dict[str, str] = field(default_factory=dict)
    # Notifications with the same tag replace each other (e.g. one per conversation).
    tag: str | None = None


@dataclass
class SendResult:
    sent: int = 0
    # Tokens FCM says are no longer valid; the caller deletes them.
    invalid: list[str] = field(default_factory=list)


class PushSender(Protocol):
    def send(self, tokens: list[str], message: PushMessage) -> SendResult: ...


class NullSender:
    """Used when Firebase isn't configured: nothing is sent."""

    _warned = False

    def send(self, tokens: list[str], message: PushMessage) -> SendResult:
        if not NullSender._warned:
            log.info("Push notifications are off: Firebase credentials are not configured.")
            NullSender._warned = True
        return SendResult()


def _is_invalid_token(status: int, error: dict) -> bool:
    """FCM's answers that mean "stop sending to this token"."""
    codes = {d.get("errorCode") for d in error.get("details", []) if isinstance(d, dict)}
    if status == 404 or "UNREGISTERED" in codes:
        return True
    if status == 403 and "SENDER_ID_MISMATCH" in codes:  # a token from another project
        return True
    # A malformed token. Other INVALID_ARGUMENT errors are about our payload, not the token.
    return status == 400 and "registration token" in str(error.get("message", "")).lower()


class FcmSender:
    def __init__(self, credentials, project_id: str, session: requests.Session | None = None):
        self._credentials = credentials
        self._project_id = project_id
        self._session = session or requests.Session()

    @classmethod
    def from_settings(cls) -> FcmSender | None:
        from google.oauth2 import service_account

        if settings.GOOGLE_APPLICATION_CREDENTIALS:
            credentials = service_account.Credentials.from_service_account_file(
                settings.GOOGLE_APPLICATION_CREDENTIALS, scopes=[FCM_SCOPE]
            )
        elif settings.FIREBASE_PROJECT_ID and settings.FIREBASE_CLIENT_EMAIL and settings.FIREBASE_PRIVATE_KEY:
            credentials = service_account.Credentials.from_service_account_info(
                {
                    "type": "service_account",
                    "project_id": settings.FIREBASE_PROJECT_ID,
                    "client_email": settings.FIREBASE_CLIENT_EMAIL,
                    # .env files keep the key on one line with literal \n escapes.
                    "private_key": settings.FIREBASE_PRIVATE_KEY.replace("\\n", "\n"),
                    "token_uri": "https://oauth2.googleapis.com/token",
                },
                scopes=[FCM_SCOPE],
            )
        else:
            return None
        project_id = settings.FIREBASE_PROJECT_ID or credentials.project_id
        return cls(credentials, project_id)

    def _access_token(self) -> str:
        if not self._credentials.valid:
            from google.auth.transport.requests import Request

            self._credentials.refresh(Request())
        return self._credentials.token

    @staticmethod
    def payload(token: str, message: PushMessage, *, validate_only: bool = False) -> dict:
        android_notification: dict = {"color": ACCENT}
        if message.tag:
            android_notification["tag"] = message.tag
        body: dict = {
            "message": {
                "token": token,
                "notification": {"title": message.title, "body": message.body},
                "data": message.data,
                "android": {"priority": "HIGH", "notification": android_notification},
                # Taps on web are handled by web/firebase-messaging-sw.js, which reads
                # `data.route` (FCM's own `fcm_options.link` must be HTTPS, and local
                # development runs on http://localhost).
                "webpush": {"headers": {"Urgency": "high"}},
            }
        }
        if validate_only:
            body["validate_only"] = True
        return body

    def send(self, tokens: list[str], message: PushMessage, *, validate_only: bool = False
             ) -> SendResult:
        result = SendResult()
        if not tokens:
            return result
        try:
            headers = {"Authorization": f"Bearer {self._access_token()}",
                       "Content-Type": "application/json; UTF-8"}
        except Exception as exc:  # bad credentials or no network: nothing can be sent
            log.warning("Could not authorise with Firebase: %s", exc.__class__.__name__)
            return result
        url = FCM_URL.format(project=self._project_id)
        for token in tokens:
            try:
                response = self._session.post(
                    url, headers=headers, timeout=10,
                    data=json.dumps(self.payload(token, message, validate_only=validate_only)),
                )
            except requests.RequestException as exc:
                log.warning("Push to a device failed: %s", exc.__class__.__name__)
                continue
            if response.status_code == 200:
                result.sent += 1
                continue
            try:
                error = response.json().get("error", {})
            except ValueError:
                error = {}
            if _is_invalid_token(response.status_code, error):
                result.invalid.append(token)
            else:
                log.warning("FCM rejected a push (%s): %s", response.status_code,
                            error.get("message", "no details"))
        return result


@lru_cache
def get_sender() -> PushSender:
    if settings.firebase_enabled:
        try:
            sender = FcmSender.from_settings()
        except Exception as exc:  # e.g. the key file path is wrong
            log.warning("Push notifications are off: couldn't load Firebase credentials (%s).",
                        exc.__class__.__name__)
            sender = None
        if sender is not None:
            return sender
    return NullSender()
