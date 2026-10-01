"""Module 9 — chat and messaging API (SRS FR-23–FR-25, UC-13, UC-14; SDD Algorithm 8).

Customers start conversations from a business's page; the business's owner replies
(BR-16). Only the two participants can see a conversation (BR-15, SEC-5): anyone else gets
404. Messages are sent over REST and delivered live over the `/ws` WebSocket; a recipient
without an open socket gets a push notification instead (PER-6, REL-5).
"""
from __future__ import annotations

import asyncio
from datetime import datetime, timezone

from fastapi import (
    APIRouter,
    BackgroundTasks,
    Depends,
    HTTPException,
    Query,
    Response,
    WebSocket,
    WebSocketDisconnect,
    status,
)
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from starlette.concurrency import run_in_threadpool

from app.api.deps import get_current_user
from app.core.database import get_db, session_scope
from app.core.security import ACCESS_TOKEN, decode_token
from app.models.business import BusinessProfile
from app.models.chat import Conversation, ConversationReport, Message
from app.models.notification import NotificationKind
from app.models.user import User
from app.schemas.chat import (
    ConversationCreate,
    ConversationDetail,
    ConversationReportIn,
    ConversationSummary,
    MessageIn,
    MessageOut,
    MessagePage,
    ReadOut,
    Side,
    UnreadOut,
)
from app.services import chat_service as cs
from app.services import moderation_rules as rules
from app.services import notification_service as ns
from app.services.moderation_service import account_block
from app.services.media_service import UnknownPhotos, resolve_keys
from app.services.realtime import manager
from app.services.review_service import display_name

router = APIRouter(tags=["chat"])

UNPROCESSABLE = 422
# A new socket must authenticate within this many seconds.
AUTH_TIMEOUT = 10
# WebSocket close code for a missing or invalid access token (the app refreshes and retries).
CLOSE_UNAUTHORIZED = 4401


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _participant(db: Session, conversation_id: int, user: User) -> tuple[Conversation, Side]:
    conversation = db.get(Conversation, conversation_id)
    side = cs.side_of(conversation, user) if conversation is not None else None
    if side is None:  # BR-15: others can't tell whether it exists
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND,
                            detail="Conversation not found")
    return conversation, side


# ─────────────── conversations ───────────────
@router.post("/conversations", response_model=ConversationDetail,
             summary="Open a conversation with a business (UC-13)")
def open_conversation(
    payload: ConversationCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ConversationDetail:
    """Returns the customer's existing conversation with the business, or starts one.
    It's listed once the first message is sent."""
    business = db.get(BusinessProfile, payload.business_id)
    if business is None or not business.is_published:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Business not found")
    if business.owner_id == user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This is your business. Customers' messages appear in your Chat tab.",
        )
    query = select(Conversation).where(
        Conversation.customer_id == user.id, Conversation.business_id == business.id
    )
    conversation = db.scalar(query)
    if conversation is None:
        conversation = Conversation(customer_id=user.id, business_id=business.id)
        db.add(conversation)
        try:
            db.commit()
        except IntegrityError:  # opened twice at once: use the other one
            db.rollback()
            conversation = db.scalar(query)
        db.refresh(conversation)
    return cs.detail_out(db, conversation, "customer")


@router.get("/conversations", response_model=list[ConversationSummary],
            summary="My conversations, newest first (FR-25)")
def list_conversations(
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[ConversationSummary]:
    conversations = list(db.scalars(
        cs.conversations_of(user.id)
        .where(Conversation.last_message_at.is_not(None))
        .order_by(Conversation.last_message_at.desc(), Conversation.id.desc())
        .limit(limit).offset(offset)
    ))
    last = cs.last_messages(db, [c.id for c in conversations])
    unread = cs.unread_by_conversation(db, user.id)
    return [
        cs.summary_out(c, cs.side_of(c, user), last.get(c.id), unread.get(c.id, 0))
        for c in conversations
    ]


@router.get("/conversations/unread", response_model=UnreadOut,
            summary="Unread messages across all my conversations")
def unread_count(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> UnreadOut:
    return UnreadOut(total=cs.unread_total(db, user.id))


@router.get("/conversations/{conversation_id}", response_model=ConversationDetail,
            summary="A conversation's header")
def get_conversation(
    conversation_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ConversationDetail:
    conversation, side = _participant(db, conversation_id, user)
    return cs.detail_out(db, conversation, side)


# ─────────────── messages ───────────────
@router.get("/conversations/{conversation_id}/messages", response_model=MessagePage,
            summary="Message history, oldest first")
def list_messages(
    conversation_id: int,
    before_id: int | None = Query(default=None, description="Page back: messages older than this"),
    after_id: int | None = Query(default=None, description="Catch up: messages newer than this"),
    limit: int = Query(default=30, ge=1, le=100),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MessagePage:
    conversation, side = _participant(db, conversation_id, user)
    query = select(Message).where(Message.conversation_id == conversation.id)
    if after_id is not None:
        rows = list(db.scalars(query.where(Message.id > after_id)
                               .order_by(Message.id.asc()).limit(limit)))
        return MessagePage(items=[cs.message_out(m, side) for m in rows], has_more=False)
    if before_id is not None:
        query = query.where(Message.id < before_id)
    rows = list(db.scalars(query.order_by(Message.id.desc()).limit(limit + 1)))
    has_more = len(rows) > limit
    rows = list(reversed(rows[:limit]))
    return MessagePage(items=[cs.message_out(m, side) for m in rows], has_more=has_more)


def _message_events(db: Session, conversation: Conversation, message: Message
                    ) -> dict[int, dict]:
    """`message.new` for each participant, each from their own point of view."""
    events = {}
    for side in ("customer", "business"):
        user_id = cs.participant_id(conversation, side)
        summary = cs.summary_out(conversation, side, message,
                                 cs.unread_by_conversation(db, user_id).get(conversation.id, 0))
        events[user_id] = {
            "type": "message.new",
            "conversation_id": conversation.id,
            "message": cs.message_out(message, side).model_dump(mode="json"),
            "conversation": summary.model_dump(mode="json"),
            "unread_total": cs.unread_total(db, user_id),
        }
    return events


@router.post("/conversations/{conversation_id}/messages", response_model=MessageOut,
             status_code=status.HTTP_201_CREATED, summary="Send a message (FR-23, FR-24)")
def send_message(
    conversation_id: int,
    payload: MessageIn,
    background_tasks: BackgroundTasks,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MessageOut:
    """SDD Algorithm 8: validate, store, deliver to the other side (live or by push)."""
    conversation, side = _participant(db, conversation_id, user)
    if (problem := cs.send_problem(conversation, side)) is not None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=problem)

    def existing() -> Message | None:
        return db.scalar(select(Message).where(
            Message.conversation_id == conversation.id, Message.client_id == payload.client_id))

    if payload.client_id and (message := existing()) is not None:  # a retried send
        return cs.message_out(message, side)

    body = payload.body.strip()
    photo = None
    if payload.photo:
        try:
            photo = resolve_keys(db, [payload.photo], allowed_owner=user.id)[0]
        except UnknownPhotos:
            raise HTTPException(status_code=UNPROCESSABLE,
                                detail="That photo couldn't be found. Please attach it again.") from None
    if not body and photo is None:
        raise HTTPException(status_code=UNPROCESSABLE, detail="Write a message first.")

    message = Message(conversation_id=conversation.id, sender_id=user.id,
                      from_business=side == "business", body=body,
                      media_id=photo.id if photo else None, client_id=payload.client_id,
                      created_at=_now())
    db.add(message)
    try:
        db.flush()
    except IntegrityError:  # the same client id arrived twice at once
        db.rollback()
        return cs.message_out(existing(), side)
    conversation.last_message_at = message.created_at
    # The sender has seen everything up to their own message.
    if side == "customer":
        conversation.customer_last_read_id = message.id
    else:
        conversation.business_last_read_id = message.id

    if side == "customer":  # Module 8: the same message to many businesses
        rules.check_mass_messaging(db, user)
    recipient_id = cs.other_user_id(conversation, side)
    job = None
    if not manager.is_online(recipient_id):
        sender = display_name(user.full_name) if side == "customer" else conversation.business.name
        job = ns.notify(
            db, [db.get(User, recipient_id)], NotificationKind.message,
            title=sender, body=ns.snippet(body) if body else "📷 Photo",
            route=f"/conversations/{conversation.id}", tag=f"conversation-{conversation.id}",
            store=False,
        )
    db.commit()
    db.refresh(message)
    background_tasks.add_task(manager.publish, _message_events(db, conversation, message))
    if job is not None:
        background_tasks.add_task(job)
    return cs.message_out(message, side)


@router.post("/conversations/{conversation_id}/read", response_model=ReadOut,
             summary="Mark a conversation read (\"Seen\")")
def mark_read(
    conversation_id: int,
    background_tasks: BackgroundTasks,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ReadOut:
    conversation, side = _participant(db, conversation_id, user)
    latest = cs.last_message_id(db, conversation.id)
    field = "customer_last_read_id" if side == "customer" else "business_last_read_id"
    current = getattr(conversation, field)
    if latest is not None and (current or 0) < latest:
        setattr(conversation, field, latest)
        db.commit()
        event = {"type": "conversation.read", "conversation_id": conversation.id,
                 "side": side, "last_read_id": latest}
        other = cs.other_user_id(conversation, side)
        background_tasks.add_task(manager.publish, {
            other: event,
            # The reader's other devices update their badges.
            user.id: {**event, "unread_total": cs.unread_total(db, user.id)},
        })
    return ReadOut(last_read_id=getattr(conversation, field), unread_total=cs.unread_total(db, user.id))


@router.post("/conversations/{conversation_id}/report", status_code=status.HTTP_201_CREATED,
             response_class=Response, summary="Report a conversation")
def report_conversation(
    conversation_id: int,
    payload: ConversationReportIn,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Response:
    """Stored for the admin's moderation queue (Module 8, SDD Algorithm 10). Reporting
    shares the conversation with Khojlo's moderators, who can then read it (decision 8,
    the SEC-5 exception); the other participant isn't told who reported it."""
    conversation, _ = _participant(db, conversation_id, user)
    db.add(ConversationReport(conversation_id=conversation.id, reporter_id=user.id,
                              reason=payload.reason, note=payload.note.strip()))
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT,
                            detail="You've already reported this conversation. Thanks for letting us know.") from None
    return Response(status_code=status.HTTP_201_CREATED)


# ─────────────── blocking (Module 8) ───────────────
@router.post("/conversations/{conversation_id}/block", response_model=ConversationDetail,
             summary="Block the other person in this conversation")
def block_conversation(
    conversation_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ConversationDetail:
    """Nobody can send until the blocker unblocks. A customer blocking a business also
    stops its messages; an owner blocking a customer stops theirs."""
    conversation, side = _participant(db, conversation_id, user)
    if conversation.blocked_by is not None and conversation.blocked_by != side:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT,
                            detail="This conversation is already blocked.")
    if conversation.blocked_by is None:
        conversation.blocked_by, conversation.blocked_at = side, _now()
        db.commit()
    return cs.detail_out(db, conversation, side)


@router.delete("/conversations/{conversation_id}/block", response_model=ConversationDetail,
               summary="Unblock")
def unblock_conversation(
    conversation_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ConversationDetail:
    conversation, side = _participant(db, conversation_id, user)
    if conversation.blocked_by not in (None, side):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN,
                            detail="Only the person who blocked it can unblock it.")
    if conversation.blocked_by == side:
        conversation.blocked_by, conversation.blocked_at = None, None
        db.commit()
    return cs.detail_out(db, conversation, side)


# ─────────────── live events ───────────────
def _authenticate(token: object) -> int | None:
    if not isinstance(token, str):
        return None
    payload = decode_token(token)
    if payload is None or payload.get("type") != ACCESS_TOKEN or payload.get("sub") is None:
        return None
    user_id = int(payload["sub"])
    with session_scope() as db:
        user = db.get(User, user_id)
        # Module 8: suspended and banned accounts get no live connection either.
        return user_id if user is not None and account_block(user) is None else None


def _typing_target(user_id: int, conversation_id: object) -> tuple[int, Side] | None:
    """The other participant and the typer's side, if the user takes part (BR-15)."""
    if not isinstance(conversation_id, int):
        return None
    with session_scope() as db:
        conversation = db.get(Conversation, conversation_id)
        user = db.get(User, user_id)
        side = cs.side_of(conversation, user) if conversation and user else None
        if side is None or cs.send_problem(conversation, side) is not None:
            return None  # no typing indicator in a blocked or closed conversation
        return cs.other_user_id(conversation, side), side


@router.websocket("/ws")
async def realtime(socket: WebSocket) -> None:
    """One socket per signed-in app. The first message must be
    `{"type": "auth", "token": <access token>}` (kept out of the URL, which servers log).

    Server → app: `ready`, `message.new`, `conversation.read`, `typing`, `pong`.
    App → server: `ping`, `typing` `{conversation_id}`.
    """
    await socket.accept()
    try:
        first = await asyncio.wait_for(socket.receive_json(), timeout=AUTH_TIMEOUT)
        user_id = await run_in_threadpool(_authenticate, first.get("token")) \
            if isinstance(first, dict) and first.get("type") == "auth" else None
    except (asyncio.TimeoutError, WebSocketDisconnect, ValueError):
        user_id = None
    if user_id is None:
        try:
            await socket.close(code=CLOSE_UNAUTHORIZED)
        except RuntimeError:  # already closed by the client
            pass
        return

    manager.add(user_id, socket)
    try:
        await socket.send_json({"type": "ready"})
        while True:
            event = await socket.receive_json()
            if not isinstance(event, dict):
                continue
            if event.get("type") == "ping":
                await socket.send_json({"type": "pong"})
            elif event.get("type") == "typing":
                target = await run_in_threadpool(_typing_target, user_id,
                                                 event.get("conversation_id"))
                if target is not None:
                    other_id, side = target
                    await manager.send(other_id, {"type": "typing",
                                                  "conversation_id": event["conversation_id"],
                                                  "side": side})
    except (WebSocketDisconnect, ValueError):
        pass
    finally:
        manager.remove(user_id, socket)
