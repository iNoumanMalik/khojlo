from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import auth, businesses, categories, feed, users
from app.core.config import settings

app = FastAPI(
    title=settings.PROJECT_NAME,
    version="0.1.0",
    description="Khojlo — discover new & hidden local businesses (30% evaluation build).",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_origin_regex=r"http://localhost:\d+",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

for module in (auth, users, businesses, categories, feed):
    app.include_router(module.router, prefix=settings.API_V1_PREFIX)


@app.get("/health", tags=["meta"])
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/", tags=["meta"])
def root() -> dict[str, str]:
    return {"name": settings.PROJECT_NAME, "docs": "/docs"}
