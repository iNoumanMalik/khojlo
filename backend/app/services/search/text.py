"""Text helpers for keyword search.

Matching is case- and accent-insensitive, so "cafe" finds "Cafés". SQL can't fold
accents portably (tests run on SQLite, production on Postgres), so the SQL side uses a
deliberately loose LIKE pattern and Python then confirms matches on folded text.
"""
from __future__ import annotations

import re
import unicodedata

# Words that carry no meaning in a local-business search ("gym near me").
STOPWORDS = frozenset(
    {"a", "an", "and", "around", "at", "for", "in", "me", "near", "nearby", "of", "or", "the",
     "to", "with"}
)

# Keeps "f-7" (Islamabad sectors) and "don't" as single tokens.
_TOKEN = re.compile(r"\w+(?:[-'’]\w+)*")
_VOWELS = frozenset("aeiouy")
_LIKE_ESCAPE = "\\"


def fold(text: str | None) -> str:
    """Lowercase and strip accents: "Cafés" → "cafes"."""
    decomposed = unicodedata.normalize("NFKD", text or "")
    return "".join(ch for ch in decomposed if not unicodedata.combining(ch)).casefold()


def normalize_query(text: str | None) -> str:
    """Case-folded, whitespace-collapsed query, accents kept (used to group history)."""
    return " ".join((text or "").casefold().split())


def tokenize(query: str | None) -> list[str]:
    """Split a query into folded search tokens.

    Drops stopwords and one-letter tokens unless nothing else would remain, and removes
    duplicates while keeping order.
    """
    raw = _TOKEN.findall(fold(query))
    meaningful = [t for t in raw if len(t) > 1 and t not in STOPWORDS]
    if not meaningful:
        meaningful = [t for t in raw if len(t) > 1] or raw
    return list(dict.fromkeys(meaningful))


def like_pattern(token: str) -> str:
    """A LIKE pattern that over-matches accents: vowels become the `_` wildcard.

    "cafe" → "%c_f_%", which also matches "café". Python re-checks every candidate with
    `fold()`, so over-matching here only costs a few extra rows.
    """
    out = []
    for ch in token:
        if ch in _VOWELS:
            out.append("_")
        elif ch in ("%", "_", _LIKE_ESCAPE):
            out.append(_LIKE_ESCAPE + ch)
        else:
            out.append(ch)
    return f"%{''.join(out)}%"


LIKE_ESCAPE = _LIKE_ESCAPE


def word_starts_with(folded_text: str, token: str) -> bool:
    """True if any word in the (already folded) text starts with the token."""
    return any(word.startswith(token) for word in _TOKEN.findall(folded_text))
