"""Module 9 — conversations, unread counts and message presentation."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.models.business import BusinessProfile
from app.models.chat import Conversation, Message
from app.models.user import User
from app.schemas.chat import (
    ChatBusiness,
    ChatBusinessBrief,
    ChatPerson,
    ConversationDetail,
    ConversationSummary,
    MessageOut,
    Side,
)
from app.services import promotion_service as ps
from app.services.business_service import photo_out
from app.services.hours import is_open_now, today_hours_label
from app.services.review_service import display_name


def side_of(conversation: Conversation, user: User) -> Side | None:
    """Which participant `user` is, or None if they aren't one (BR-15)."""
    if conversation.customer_id == user.id:
        return "customer"
    if conversation.business.owner_id == user.id:
        return "business"
    return None


def participant_id(conversation: Conversation, side: Side) -> int:
    """The user on `side`: the customer, or the business's owner."""
    return conversation.customer_id if side == "customer" else conversation.business.owner_id


def other_user_id(conversation: Conversation, side: Side) -> int:
    """The participant opposite `side`."""
    return participant_id(conversation, "business" if side == "customer" else "customer")


def conversations_of(user_id: int):
    """Conversations the user takes part in: as the customer, or as a business's owner."""
    owned = select(BusinessProfile.id).where(BusinessProfile.owner_id == user_id)
    return select(Conversation).where(
        or_(Conversation.customer_id == user_id, Conversation.business_id.in_(owned))
    )


def unread_by_conversation(db: Session, user_id: int) -> dict[int, int]:
    """Messages from the other side newer than what the user has read, per conversation."""
    as_customer = (
        select(Message.conversation_id, func.count(Message.id))
        .join(Conversation, Conversation.id == Message.conversation_id)
        .where(
            Conversation.customer_id == user_id,
            Message.from_business.is_(True),
            Message.id > func.coalesce(Conversation.customer_last_read_id, 0),
        )
        .group_by(Message.conversation_id)
    )
    as_business = (
        select(Message.conversation_id, func.count(Message.id))
        .join(Conversation, Conversation.id == Message.conversation_id)
        .join(BusinessProfile, BusinessProfile.id == Conversation.business_id)
        .where(
            BusinessProfile.owner_id == user_id,
            Message.from_business.is_(False),
            Message.id > func.coalesce(Conversation.business_last_read_id, 0),
        )
        .group_by(Message.conversation_id)
    )
    counts: dict[int, int] = {}
    for query in (as_customer, as_business):
        for conversation_id, n in db.execute(query):
            counts[conversation_id] = counts.get(conversation_id, 0) + n
    return counts


def unread_total(db: Session, user_id: int) -> int:
    return sum(unread_by_conversation(db, user_id).values())


def last_messages(db: Session, conversation_ids: list[int]) -> dict[int, Message]:
    if not conversation_ids:
        return {}
    newest = (
        select(func.max(Message.id))
        .where(Message.conversation_id.in_(conversation_ids))
        .group_by(Message.conversation_id)
    )
    return {m.conversation_id: m for m in db.scalars(select(Message).where(Message.id.in_(newest)))}


def last_message_id(db: Session, conversation_id: int) -> int | None:
    return db.scalar(select(func.max(Message.id)).where(Message.conversation_id == conversation_id))


def message_out(message: Message, side: Side) -> MessageOut:
    return MessageOut(
        id=message.id,
        conversation_id=message.conversation_id,
        body=message.body,
        photo=photo_out(message.photo),
        from_business=message.from_business,
        is_mine=message.from_business == (side == "business"),
        created_at=message.created_at,
        client_id=message.client_id,
    )


def person_out(user: User) -> ChatPerson:
    return ChatPerson(
        id=user.id,
        name=display_name(user.full_name),
        initials=user.initials,
        tone=user.avatar_tone,
        avatar=photo_out(user.avatar),
    )


def business_brief(b: BusinessProfile) -> ChatBusinessBrief:
    return ChatBusinessBrief(
        id=b.id, name=b.name, tone=b.tone, cover=photo_out(b.cover),
        category_label=b.category_label,
    )


def business_header(b: BusinessProfile) -> ChatBusiness:
    today = ps.local_today()
    return ChatBusiness(
        **business_brief(b).model_dump(),
        is_verified=b.is_verified,
        is_open_now=is_open_now(b.hours),
        today_hours=today_hours_label(b.hours),
        phone=b.phone,
        latitude=b.latitude,
        longitude=b.longitude,
        offers=[ps.offer_out(o, today) for o in ps.live_offers(b.offers, today)],
    )


def summary_out(conversation: Conversation, side: Side, last: Message | None, unread: int
                ) -> ConversationSummary:
    return ConversationSummary(
        id=conversation.id,
        my_side=side,
        business=business_brief(conversation.business),
        customer=person_out(conversation.customer),
        last_message=message_out(last, side) if last else None,
        last_message_at=conversation.last_message_at,
        unread_count=unread,
    )


def detail_out(db: Session, conversation: Conversation, side: Side) -> ConversationDetail:
    last = last_messages(db, [conversation.id]).get(conversation.id)
    unread = unread_by_conversation(db, participant_id(conversation, side)).get(conversation.id, 0)
    mine, theirs = (
        (conversation.customer_last_read_id, conversation.business_last_read_id)
        if side == "customer"
        else (conversation.business_last_read_id, conversation.customer_last_read_id)
    )
    summary = summary_out(conversation, side, last, unread)
    return ConversationDetail(
        **summary.model_dump(exclude={"business"}),
        business=business_header(conversation.business),
        other_last_read_id=theirs,
        my_last_read_id=mine,
    )


def business_message_counts(db: Session, business_id: int, now: datetime | None = None
                            ) -> tuple[int, int]:
    """(customer messages received in the last 7 days, still unread) for the dashboard."""
    now = now or datetime.now(timezone.utc)
    week = db.scalar(
        select(func.count(Message.id))
        .join(Conversation, Conversation.id == Message.conversation_id)
        .where(
            Conversation.business_id == business_id,
            Message.from_business.is_(False),
            Message.created_at >= now - timedelta(days=7),
        )
    ) or 0
    unread = db.scalar(
        select(func.count(Message.id))
        .join(Conversation, Conversation.id == Message.conversation_id)
        .where(
            Conversation.business_id == business_id,
            Message.from_business.is_(False),
            Message.id > func.coalesce(Conversation.business_last_read_id, 0),
        )
    ) or 0
    return week, unread
