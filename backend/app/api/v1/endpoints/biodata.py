"""
Biodata endpoints.
GET  /biodata          — biodata status
POST /biodata/generate — generate fresh PDF
GET  /biodata/pdf      — download PDF
"""
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import Response
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text

from app.database import get_db, get_supabase
from app.middleware import get_current_user, AuthenticatedUser
from app.services.biodata_service import generate_biodata_pdf
from app.config import get_settings

settings = get_settings()
router = APIRouter(prefix="/biodata", tags=["Biodata"])


@router.get("")
async def get_biodata_status(
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Check biodata generation status and staleness."""
    result = await db.execute(
        text("""
            SELECT id, status, is_stale, generated_at, error_message, storage_path
            FROM biodata_exports
            WHERE user_id = :uid
            ORDER BY created_at DESC LIMIT 1
        """),
        {"uid": current_user.user_id},
    )
    row = result.fetchone()
    if not row:
        return {"status": "not_generated", "is_stale": True}

    return {
        "status": row.status,
        "is_stale": row.is_stale,
        "generated_at": row.generated_at,
        "has_pdf": row.storage_path is not None,
    }


@router.post("/generate")
async def generate_biodata(
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Generate or regenerate biodata PDF."""
    try:
        pdf_bytes = await generate_biodata_pdf(db, current_user.user_id)
        return {
            "success": True,
            "message": "Biodata generated successfully.",
            "size_bytes": len(pdf_bytes),
        }
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=500, detail="We couldn't generate your biodata. Please try again.")


@router.get("/pdf")
async def download_biodata(
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Download biodata as PDF. Generates fresh if stale."""
    # Check if fresh PDF exists
    result = await db.execute(
        text("""
            SELECT storage_path, is_stale, status
            FROM biodata_exports WHERE user_id = :uid
            ORDER BY created_at DESC LIMIT 1
        """),
        {"uid": current_user.user_id},
    )
    row = result.fetchone()

    if not row or row.is_stale or row.status != "ready" or not row.storage_path:
        # Generate fresh PDF
        pdf_bytes = await generate_biodata_pdf(db, current_user.user_id)
    else:
        # Download from storage
        supabase = get_supabase()
        try:
            pdf_bytes = supabase.storage.from_(settings.storage_bucket_biodata).download(row.storage_path)
        except Exception:
            pdf_bytes = await generate_biodata_pdf(db, current_user.user_id)

    from sqlalchemy import text as sqltext
    name_result = await db.execute(
        sqltext("SELECT full_name FROM profiles WHERE user_id = :uid"),
        {"uid": current_user.user_id},
    )
    name_row = name_result.fetchone()
    display_name = name_row.full_name.replace(" ", "_") if name_row else "biodata"

    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'attachment; filename="{display_name}_biodata.pdf"',
            "Content-Length": str(len(pdf_bytes)),
        },
    )
