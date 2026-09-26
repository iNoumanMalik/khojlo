from fastapi import APIRouter, Depends
from sqlalchemy import and_, func, select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.business import BusinessProfile, Category
from app.schemas.business import CategoryOut

router = APIRouter(prefix="/categories", tags=["categories"])


def categories_with_counts(db: Session) -> list[CategoryOut]:
    """Every category in display order, with how many published businesses it has.

    Categories are rows, not code (SRS SCA-1): adding one needs no app release.
    """
    rows = db.execute(
        select(Category, func.count(BusinessProfile.id))
        .outerjoin(
            BusinessProfile,
            and_(BusinessProfile.category_id == Category.id,
                 BusinessProfile.is_published.is_(True)),
        )
        .group_by(Category.id)
        .order_by(Category.sort_order, Category.name)
    ).all()
    out = []
    for category, count in rows:
        item = CategoryOut.model_validate(category)
        item.business_count = count
        out.append(item)
    return out


@router.get("", response_model=list[CategoryOut])
def list_categories(db: Session = Depends(get_db)) -> list[CategoryOut]:
    return categories_with_counts(db)
