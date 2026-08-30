"""
Verification endpoints.
POST /verification/reference
POST /verification/certificate
GET  /verification/status
GET  /verification/document/{doc_id}/view  (signed URL — admin only)
"""
from uuid import UUID

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db, get_supabase
from app.middleware import get_current_user, AuthenticatedUser
from app.services.verification_service import (
    VerificationError,
    add_reference_member,
    upload_certificate,
    get_verification_status,
)

router = APIRouter(prefix="/verification", tags=["Verification"])


class ReferenceRequest(BaseModel):
    reference_phone: str


@router.post("/reference", status_code=status.HTTP_201_CREATED)
async def add_reference(
    body: ReferenceRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Add a registered member as a reference."""
    try:
        return await add_reference_member(db, current_user.user_id, body.reference_phone)
    except VerificationError as exc:
        code_map = {
            "invalid_phone": 422,
            "self_reference": 400,
            "member_not_found": 404,
            "invalid_reference_member": 400,
            "duplicate_reference": 409,
        }
        raise HTTPException(
            status_code=code_map.get(exc.code, 400),
            detail=str(exc),
        )


@router.post("/certificate", status_code=status.HTTP_201_CREATED)
async def upload_cert(
    certificate: UploadFile = File(...),
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Upload caste certificate. Stored in private bucket."""
    if not certificate.content_type:
        raise HTTPException(status_code=422, detail="Could not determine file type")

    file_bytes = await certificate.read()
    try:
        return await upload_certificate(
            db=db,
            user_id=current_user.user_id,
            file_bytes=file_bytes,
            filename=certificate.filename or "certificate",
            mime_type=certificate.content_type,
        )
    except VerificationError as exc:
        code_map = {
            "invalid_file_type": 422, "invalid_extension": 422,
            "file_too_large": 413, "low_quality": 422,
            "corrupt_file": 422, "invalid_pdf": 422,
            "encrypted_pdf": 422, "certificate_locked": 403,
            "upload_failed": 503,
        }
        raise HTTPException(
            status_code=code_map.get(exc.code, 400),
            detail=str(exc),
        )


@router.get("/status")
async def get_status(
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get current verification status."""
    return await get_verification_status(db, current_user.user_id)
