from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import auth, businesses, categories, compare, feed, media, search, users
from app.core.config import settings
from app.core.database import engine
from app.db.schema_check import warn_if_outdated


@asynccontextmanager
async def lifespan(_: FastAPI):
    if settings.SCHEMA_CHECK_ON_STARTUP:
        warn_if_outdated(engine)
    yield


app = FastAPI(
    title=settings.PROJECT_NAME,
    version="0.1.0",
    description="Khojlo — discover new & hidden local businesses (30% evaluation build).",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_origin_regex=r"http://localhost:\d+",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

for module in (auth, users, businesses, categories, feed, search, compare, media):
    app.include_router(module.router, prefix=settings.API_V1_PREFIX)


@app.get("/health", tags=["meta"])
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/", tags=["meta"])
def root() -> dict[str, str]:
    return {"name": settings.PROJECT_NAME, "docs": "/docs"}
