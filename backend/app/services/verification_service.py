"""
Verification Service.
Handles reference member verification and caste certificate upload.
"""
import io
import os
import structlog
from uuid import UUID
from typing import Optional

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text

from app.config import get_settings
from app.database import get_supabase
from app.utils import normalize_phone, PhoneValidationError, log_action, safe_filename

settings = get_settings()
logger = structlog.get_logger()

ALLOWED_DOC_MIMES = {"application/pdf", "image/jpeg", "image/png"}
ALLOWED_DOC_EXTENSIONS = {".pdf", ".jpg", ".jpeg", ".png"}


class VerificationError(Exception):
    def __init__(self, message: str, code: str = "verification_error"):
        super().__init__(message)
        self.code = code


# ---------------------------------------------------------------------------
# Reference Member
# ---------------------------------------------------------------------------

async def add_reference_member(
    db: AsyncSession,
    user_id: UUID,
    reference_phone: str,
) -> dict:
    """
    Validate and add a reference member.
    """
    # Normalize phone
    try:
        ref_phone_normalized = normalize_phone(reference_phone)
    except PhoneValidationError as exc:
        raise VerificationError(str(exc), code="invalid_phone")

    # Cannot reference yourself
    self_result = await db.execute(
        text("SELECT id FROM users WHERE phone_normalized = :phone AND deleted_at IS NULL"),
        {"phone": ref_phone_normalized},
    )
    ref_user = self_result.fetchone()

    # Get current user's phone
    self_phone_result = await db.execute(
        text("SELECT phone_normalized FROM users WHERE id = :uid"),
        {"uid": user_id},
    )
    self_phone_row = self_phone_result.fetchone()

    if self_phone_row and self_phone_row.phone_normalized == ref_phone_normalized:
        raise VerificationError("You cannot use yourself as a reference.", code="self_reference")

    if ref_user is None:
        raise VerificationError(
            "This number is not registered on Viva. Please ask your reference to join first.",
            code="member_not_found",
        )

    ref_user_id = ref_user.id

    # Check reference member status
    ref_status_result = await db.execute(
        text("SELECT account_status FROM users WHERE id = :uid"),
        {"uid": ref_user_id},
    )
    ref_status_row = ref_status_result.fetchone()
    if ref_status_row and ref_status_row.account_status in ("banned", "suspended"):
        raise VerificationError(
            "This member cannot be used as a reference. Please choose another member.",
            code="invalid_reference_member",
        )

    # Check for duplicate
    dup_result = await db.execute(
        text("""
            SELECT id FROM reference_members
            WHERE user_id = :uid AND reference_user_id = :ref_uid
        """),
        {"uid": user_id, "ref_uid": ref_user_id},
    )
    if dup_result.fetchone():
        raise VerificationError("This member is already added as a reference.", code="duplicate_reference")

    # Insert reference
    insert_result = await db.execute(
        text("""
            INSERT INTO reference_members (user_id, reference_user_id, status)
            VALUES (:uid, :ref_uid, 'pending')
            RETURNING id
        """),
        {"uid": user_id, "ref_uid": ref_user_id},
    )
    ref_id = insert_result.fetchone().id

    # Create/update verification request
    await _ensure_verification_request(db, user_id, "reference", reference_id=ref_id)

    await db.commit()

    # Get reference user's profile for display
    profile_result = await db.execute(
        text("SELECT full_name FROM profiles WHERE user_id = :uid"),
        {"uid": ref_user_id},
    )
    profile_row = profile_result.fetchone()

    logger.info("reference_added", user_id=str(user_id), ref_user_id=str(ref_user_id))

    return {
        "reference_id": str(ref_id),
        "reference_user_id": str(ref_user_id),
        "reference_name": profile_row.full_name if profile_row else "Member",
        "status": "pending",
        "message": "Reference added. Pending review.",
    }


# ---------------------------------------------------------------------------
# Caste Certificate
# ---------------------------------------------------------------------------

async def upload_certificate(
    db: AsyncSession,
    user_id: UUID,
    file_bytes: bytes,
    filename: str,
    mime_type: str,
) -> dict:
    """
    Upload caste certificate to PRIVATE Supabase Storage bucket.
    """
    # Validate MIME
    if mime_type not in ALLOWED_DOC_MIMES:
        raise VerificationError(
            f"Unsupported file type. Allowed: PDF, JPEG, PNG",
            code="invalid_file_type",
        )

    ext = os.path.splitext(filename)[1].lower()
    if ext not in ALLOWED_DOC_EXTENSIONS:
        raise VerificationError(f"Unsupported extension: {ext}", code="invalid_extension")

    # Size check
    if len(file_bytes) > settings.max_document_size_bytes:
        raise VerificationError(
            f"File too large. Maximum {settings.max_document_size_mb}MB allowed",
            code="file_too_large",
        )

    # Basic integrity check for images
    if mime_type in ("image/jpeg", "image/png"):
        try:
            from PIL import Image
            img = Image.open(io.BytesIO(file_bytes))
            img.verify()
            w, h = img.size
            if w < 100 or h < 100:
                raise VerificationError("Document image too small. Please upload a clear scan.", code="low_quality")
        except VerificationError:
            raise
        except Exception:
            raise VerificationError("Invalid or corrupt image file.", code="corrupt_file")

    # PDF basic check
    if mime_type == "application/pdf":
        if not file_bytes.startswith(b"%PDF"):
            raise VerificationError("Invalid PDF file.", code="invalid_pdf")
        # Check for password protection (basic)
        if b"/Encrypt" in file_bytes:
            raise VerificationError(
                "Password-protected PDFs are not accepted. Please upload an unprotected version.",
                code="encrypted_pdf",
            )

    # Check if user already has an APPROVED certificate (cannot re-upload without admin unlock)
    existing_result = await db.execute(
        text("""
            SELECT id, status, is_locked FROM verification_documents
            WHERE user_id = :uid AND document_type = 'caste_certificate' AND deleted_at IS NULL
            ORDER BY created_at DESC LIMIT 1
        """),
        {"uid": user_id},
    )
    existing = existing_result.fetchone()

    if existing and existing.status == "approved" and existing.is_locked:
        raise VerificationError(
            "Your certificate has already been approved. Contact admin to request re-verification.",
            code="certificate_locked",
        )

    # Upload to PRIVATE storage bucket
    supabase = get_supabase()
    safe_path = f"{user_id}/{safe_filename(filename)}"

    try:
        supabase.storage.from_(settings.storage_bucket_verification_docs).upload(
            path=safe_path,
            file=file_bytes,
            file_options={"content-type": mime_type},
        )
    except Exception as exc:
        logger.error("cert_upload_failed", error=str(exc), user_id=str(user_id))
        raise VerificationError("Failed to upload document. Please try again.", code="upload_failed")

    # Save metadata
    insert_result = await db.execute(
        text("""
            INSERT INTO verification_documents (
              user_id, storage_path, storage_bucket, file_name,
              file_size_bytes, mime_type, document_type, status
            ) VALUES (
              :uid, :path, :bucket, :filename, :size, :mime, 'caste_certificate', 'pending'
            ) RETURNING id
        """),
        {
            "uid": user_id,
            "path": safe_path,
            "bucket": settings.storage_bucket_verification_docs,
            "filename": filename,
            "size": len(file_bytes),
            "mime": mime_type,
        },
    )
    doc_id = insert_result.fetchone().id

    await _ensure_verification_request(db, user_id, "certificate", document_id=doc_id)

    await db.commit()

    logger.info("certificate_uploaded", user_id=str(user_id), doc_id=str(doc_id))

    return {
        "document_id": str(doc_id),
        "status": "pending",
        "message": "Certificate uploaded successfully. Pending admin review.",
    }


async def get_verification_status(db: AsyncSession, user_id: UUID) -> dict:
    """Get current verification status for a user."""
    result = await db.execute(
        text("""
            SELECT vr.method, vr.status, vr.admin_notes,
                   vd.status as cert_status, vd.rejection_reason,
                   rm.status as ref_status
            FROM verification_requests vr
            LEFT JOIN verification_documents vd ON vd.id = vr.document_id
            LEFT JOIN reference_members rm ON rm.id = vr.reference_id
            WHERE vr.user_id = :uid
        """),
        {"uid": user_id},
    )
    row = result.fetchone()

    user_status_result = await db.execute(
        text("SELECT verification_status FROM users WHERE id = :uid"),
        {"uid": user_id},
    )
    user_row = user_status_result.fetchone()

    return {
        "verification_status": user_row.verification_status if user_row else "unverified",
        "method": row.method if row else None,
        "request_status": row.status if row else None,
        "certificate_status": row.cert_status if row else None,
        "certificate_rejection_reason": row.rejection_reason if row else None,
        "reference_status": row.ref_status if row else None,
        "admin_notes": row.admin_notes if row else None,
    }


async def _ensure_verification_request(
    db: AsyncSession,
    user_id: UUID,
    method: str,
    document_id: Optional[UUID] = None,
    reference_id: Optional[UUID] = None,
) -> None:
    """Create or update the verification request record."""
    existing = await db.execute(
        text("SELECT id FROM verification_requests WHERE user_id = :uid"),
        {"uid": user_id},
    )
    if existing.fetchone():
        await db.execute(
            text("""
                UPDATE verification_requests SET
                  method = :method,
                  document_id = COALESCE(:doc_id, document_id),
                  reference_id = COALESCE(:ref_id, reference_id),
                  status = 'pending',
                  updated_at = NOW()
                WHERE user_id = :uid
            """),
            {"uid": user_id, "method": method, "doc_id": document_id, "ref_id": reference_id},
        )
    else:
        await db.execute(
            text("""
                INSERT INTO verification_requests (user_id, method, status, document_id, reference_id)
                VALUES (:uid, :method, 'pending', :doc_id, :ref_id)
            """),
            {"uid": user_id, "method": method, "doc_id": document_id, "ref_id": reference_id},
        )

