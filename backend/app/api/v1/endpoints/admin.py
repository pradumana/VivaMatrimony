"""
Admin Panel endpoints.
All require admin JWT with appropriate role.
"""
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text

from app.database import get_db, get_supabase
from app.middleware import get_current_admin, AdminUser, limiter
from app.utils import hash_password, verify_password, create_admin_access_token, log_action
from app.config import get_settings
from fastapi import Request

settings = get_settings()
router = APIRouter(prefix="/admin", tags=["Admin"])


# ---------------------------------------------------------------------------
# Admin login
# ---------------------------------------------------------------------------

class AdminLoginRequest(BaseModel):
    email: str
    password: str


@router.post("/login")
@limiter.limit("10/hour")
async def admin_login(request: Request, body: AdminLoginRequest, db: AsyncSession = Depends(get_db)):
    """Admin login — returns admin JWT."""
    result = await db.execute(
        text("""
            SELECT id, password_hash, role, full_name, is_active
            FROM admin_users WHERE email = :email
        """),
        {"email": body.email.lower().strip()},
    )
    admin = result.fetchone()
    if not admin or not admin.is_active:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    if not verify_password(body.password, admin.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    token = create_admin_access_token(admin.id)

    await db.execute(
        text("UPDATE admin_users SET last_login_at = NOW() WHERE id = :id"),
        {"id": admin.id},
    )
    await db.commit()

    await log_action(db, "admin", admin.id, "admin_login", details={"email": body.email})

    return {
        "access_token": token,
        "token_type": "Bearer",
        "role": admin.role,
        "full_name": admin.full_name,
    }


# ---------------------------------------------------------------------------
# Dashboard stats
# ---------------------------------------------------------------------------

@router.get("/dashboard")
async def get_dashboard(
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Dashboard overview stats."""
    admin.require("view_users")

    result = await db.execute(text("""
        SELECT
          (SELECT COUNT(*) FROM users WHERE deleted_at IS NULL) as total_users,
          (SELECT COUNT(*) FROM users WHERE deleted_at IS NULL AND created_at > NOW() - INTERVAL '7 days') as new_users_week,
          (SELECT COUNT(*) FROM users WHERE last_active_at > NOW() - INTERVAL '24 hours' AND deleted_at IS NULL) as active_today,
          (SELECT COUNT(*) FROM users WHERE account_status = 'pending_verification') as pending_verification,
          (SELECT COUNT(*) FROM verification_documents WHERE status = 'pending' AND deleted_at IS NULL) as pending_certificates,
          (SELECT COUNT(*) FROM reports WHERE status = 'open') as open_reports,
          (SELECT COUNT(*) FROM interests WHERE created_at > NOW() - INTERVAL '7 days') as interests_week,
          (SELECT COUNT(*) FROM users WHERE verification_status = 'verified') as verified_users
    """))
    row = result.fetchone()
    return row._asdict()


# ---------------------------------------------------------------------------
# User management
# ---------------------------------------------------------------------------

@router.get("/users")
async def list_users(
    search: Optional[str] = Query(None),
    account_status: Optional[str] = Query(None),
    verification_status: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    admin.require("view_users")

    conditions = ["u.deleted_at IS NULL"]
    params: dict = {"limit": page_size, "offset": (page - 1) * page_size}

    if search:
        conditions.append("(u.phone_normalized ILIKE :search OR p.full_name ILIKE :search)")
        params["search"] = f"%{search}%"
    if account_status:
        conditions.append("u.account_status = :account_status")
        params["account_status"] = account_status
    if verification_status:
        conditions.append("u.verification_status = :verification_status")
        params["verification_status"] = verification_status

    where = " AND ".join(conditions)

    count_result = await db.execute(
        text(f"SELECT COUNT(*) as total FROM users u LEFT JOIN profiles p ON p.user_id = u.id WHERE {where}"),
        params,
    )
    total = count_result.fetchone().total

    result = await db.execute(
        text(f"""
            SELECT u.id, u.phone_normalized, u.account_status, u.verification_status,
                   u.onboarding_completed, u.created_at, u.last_active_at,
                   p.full_name, p.gender, p.date_of_birth, p.completion_percentage
            FROM users u
            LEFT JOIN profiles p ON p.user_id = u.id
            WHERE {where}
            ORDER BY u.created_at DESC
            LIMIT :limit OFFSET :offset
        """),
        params,
    )
    rows = result.fetchall()

    return {
        "users": [
            {
                "user_id": str(r.id),
                "phone": r.phone_normalized,
                "full_name": r.full_name,
                "account_status": r.account_status,
                "verification_status": r.verification_status,
                "completion_percentage": r.completion_percentage,
                "created_at": r.created_at,
                "last_active_at": r.last_active_at,
            }
            for r in rows
        ],
        "total": total,
        "page": page,
        "page_size": page_size,
    }


@router.get("/users/{user_id}")
async def get_user_detail(
    user_id: UUID,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    admin.require("view_users")

    result = await db.execute(
        text("""
            SELECT u.*, p.full_name, p.gender, p.date_of_birth, p.completion_percentage,
                   vr.method as verification_method, vr.status as verification_request_status,
                   vd.status as cert_status
            FROM users u
            LEFT JOIN profiles p ON p.user_id = u.id
            LEFT JOIN verification_requests vr ON vr.user_id = u.id
            LEFT JOIN verification_documents vd ON vd.id = vr.document_id
            WHERE u.id = :uid
        """),
        {"uid": user_id},
    )
    row = result.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="User not found")
    return row._asdict()


class SuspendBanRequest(BaseModel):
    reason: str
    confirm: bool = False


@router.post("/users/{user_id}/suspend")
async def suspend_user(
    user_id: UUID,
    body: SuspendBanRequest,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    admin.require("ban")
    if not body.confirm:
        raise HTTPException(status_code=400, detail="Please confirm this action by setting confirm=true")

    await db.execute(
        text("""
            UPDATE users SET account_status = 'suspended', suspended_at = NOW(), suspended_reason = :reason
            WHERE id = :uid AND deleted_at IS NULL
        """),
        {"uid": user_id, "reason": body.reason},
    )
    await db.commit()
    await log_action(db, "admin", admin.admin_id, "suspend_user", "user", user_id, {"reason": body.reason})
    return {"success": True, "action": "suspended", "user_id": str(user_id)}


@router.post("/users/{user_id}/ban")
async def ban_user(
    user_id: UUID,
    body: SuspendBanRequest,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    admin.require("ban")
    if not body.confirm:
        raise HTTPException(status_code=400, detail="Please confirm this action by setting confirm=true")

    await db.execute(
        text("""
            UPDATE users SET account_status = 'banned', banned_at = NOW(), banned_reason = :reason
            WHERE id = :uid AND deleted_at IS NULL
        """),
        {"uid": user_id, "reason": body.reason},
    )
    await db.commit()
    await log_action(db, "admin", admin.admin_id, "ban_user", "user", user_id, {"reason": body.reason})
    return {"success": True, "action": "banned", "user_id": str(user_id)}


@router.post("/users/{user_id}/restore")
async def restore_user(
    user_id: UUID,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    admin.require("ban")
    await db.execute(
        text("""
            UPDATE users SET account_status = 'active',
              suspended_at = NULL, suspended_reason = NULL,
              banned_at = NULL, banned_reason = NULL
            WHERE id = :uid
        """),
        {"uid": user_id},
    )
    await db.commit()
    await log_action(db, "admin", admin.admin_id, "restore_user", "user", user_id)
    return {"success": True, "action": "restored"}


# ---------------------------------------------------------------------------
# Certificate verification
# ---------------------------------------------------------------------------

@router.get("/certificates")
async def list_pending_certificates(
    status_filter: Optional[str] = Query("pending"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=50),
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    admin.require("verify")

    result = await db.execute(
        text("""
            SELECT vd.id, vd.user_id, vd.status, vd.created_at, vd.file_name, vd.mime_type,
                   p.full_name
            FROM verification_documents vd
            JOIN profiles p ON p.user_id = vd.user_id
            WHERE vd.status = :status AND vd.deleted_at IS NULL
            ORDER BY vd.created_at ASC
            LIMIT :limit OFFSET :offset
        """),
        {"status": status_filter, "limit": page_size, "offset": (page - 1) * page_size},
    )
    rows = result.fetchall()
    return {
        "certificates": [
            {
                "document_id": str(r.id),
                "user_id": str(r.user_id),
                "full_name": r.full_name,
                "status": r.status,
                "file_name": r.file_name,
                "created_at": r.created_at,
            }
            for r in rows
        ]
    }


@router.get("/certificates/{doc_id}/view")
async def view_certificate(
    doc_id: UUID,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Get a signed URL for viewing a certificate.
    Uses Supabase service role — NEVER exposes public URL.
    URL is short-lived (5 minutes).
    """
    admin.require("verify")

    result = await db.execute(
        text("""
            SELECT storage_path, storage_bucket FROM verification_documents
            WHERE id = :doc_id AND deleted_at IS NULL
        """),
        {"doc_id": doc_id},
    )
    row = result.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Document not found")

    supabase = get_supabase()
    try:
        signed = supabase.storage.from_(row.storage_bucket).create_signed_url(
            row.storage_path,
            expires_in=300,  # 5 minutes
        )
        signed_url = signed.get("signedURL") or signed.get("signedUrl")
    except Exception as exc:
        raise HTTPException(status_code=500, detail="Could not generate document access URL")

    await log_action(
        db, "admin", admin.admin_id, "view_certificate",
        "verification_document", doc_id,
    )

    return {"signed_url": signed_url, "expires_in_seconds": 300}


class CertificateDecisionRequest(BaseModel):
    rejection_reason: Optional[str] = None


@router.post("/certificates/{doc_id}/approve")
async def approve_certificate(
    doc_id: UUID,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    admin.require("verify")

    result = await db.execute(
        text("SELECT user_id FROM verification_documents WHERE id = :doc_id AND deleted_at IS NULL"),
        {"doc_id": doc_id},
    )
    row = result.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Document not found")

    user_id = row.user_id

    await db.execute(
        text("""
            UPDATE verification_documents SET
              status = 'approved', is_locked = TRUE, locked_at = NOW(),
              locked_by = :admin_id, reviewed_by = :admin_id, reviewed_at = NOW()
            WHERE id = :doc_id
        """),
        {"doc_id": doc_id, "admin_id": admin.admin_id},
    )

    await db.execute(
        text("""
            UPDATE verification_requests SET status = 'approved', reviewed_by = :admin_id, reviewed_at = NOW()
            WHERE user_id = :uid
        """),
        {"uid": user_id, "admin_id": admin.admin_id},
    )

    await db.execute(
        text("UPDATE users SET verification_status = 'verified', account_status = 'active' WHERE id = :uid"),
        {"uid": user_id},
    )

    # Notify user
    await db.execute(
        text("""
            INSERT INTO notifications (user_id, type, title, body)
            VALUES (:uid, 'certificate_approved', 'Profile Verified!', 
                    'Your caste certificate has been approved. Your profile is now verified.')
        """),
        {"uid": user_id},
    )

    await db.commit()
    await log_action(db, "admin", admin.admin_id, "approve_certificate", "verification_document", doc_id)

    return {"success": True, "action": "approved"}


@router.post("/certificates/{doc_id}/reject")
async def reject_certificate(
    doc_id: UUID,
    body: CertificateDecisionRequest,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    admin.require("verify")

    if not body.rejection_reason:
        raise HTTPException(status_code=400, detail="Rejection reason is required")

    result = await db.execute(
        text("SELECT user_id FROM verification_documents WHERE id = :doc_id AND deleted_at IS NULL"),
        {"doc_id": doc_id},
    )
    row = result.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Document not found")

    user_id = row.user_id

    await db.execute(
        text("""
            UPDATE verification_documents SET
              status = 'rejected', rejection_reason = :reason,
              reviewed_by = :admin_id, reviewed_at = NOW()
            WHERE id = :doc_id
        """),
        {"doc_id": doc_id, "reason": body.rejection_reason, "admin_id": admin.admin_id},
    )

    # Notify user
    await db.execute(
        text("""
            INSERT INTO notifications (user_id, type, title, body)
            VALUES (:uid, 'certificate_rejected', 'Document Rejected', 
                    :body_text)
        """),
        {
            "uid": user_id,
            "body_text": f"Your certificate was rejected: {body.rejection_reason}. Please upload a new document."
        },
    )

    await db.commit()
    await log_action(db, "admin", admin.admin_id, "reject_certificate", "verification_document", doc_id,
                     {"reason": body.rejection_reason})

    return {"success": True, "action": "rejected"}


# ---------------------------------------------------------------------------
# Reports management
# ---------------------------------------------------------------------------

@router.get("/reports")
async def list_reports(
    report_status: Optional[str] = Query("open"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20),
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    admin.require("moderate")

    result = await db.execute(
        text("""
            SELECT r.id, r.reporter_id, r.reported_id, r.reason, r.description,
                   r.status, r.created_at,
                   rep.full_name as reporter_name, ted.full_name as reported_name
            FROM reports r
            LEFT JOIN profiles rep ON rep.user_id = r.reporter_id
            LEFT JOIN profiles ted ON ted.user_id = r.reported_id
            WHERE r.status = :status
            ORDER BY r.created_at DESC
            LIMIT :limit OFFSET :offset
        """),
        {"status": report_status, "limit": page_size, "offset": (page - 1) * page_size},
    )
    rows = result.fetchall()
    return {"reports": [r._asdict() for r in rows]}


class ReportResolutionRequest(BaseModel):
    resolution_note: str


@router.post("/reports/{report_id}/resolve")
async def resolve_report(
    report_id: UUID,
    body: ReportResolutionRequest,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    admin.require("moderate")
    await db.execute(
        text("""
            UPDATE reports SET status = 'resolved', reviewed_by = :admin_id,
              reviewed_at = NOW(), resolution_note = :note
            WHERE id = :rid
        """),
        {"rid": report_id, "admin_id": admin.admin_id, "note": body.resolution_note},
    )
    await db.commit()
    await log_action(db, "admin", admin.admin_id, "resolve_report", "report", report_id)
    return {"success": True}


# ---------------------------------------------------------------------------
# Audit logs
# ---------------------------------------------------------------------------

@router.get("/audit-logs")
async def get_audit_logs(
    actor_id: Optional[UUID] = Query(None),
    action: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=200),
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    admin.require("audit")

    conditions = []
    params: dict = {"limit": limit}
    if actor_id:
        conditions.append("actor_id = :actor_id")
        params["actor_id"] = actor_id
    if action:
        conditions.append("action ILIKE :action")
        params["action"] = f"%{action}%"

    where = ("WHERE " + " AND ".join(conditions)) if conditions else ""
    result = await db.execute(
        text(f"""
            SELECT id, actor_type, actor_id, action, target_type, target_id, details, ip_address, created_at
            FROM audit_logs {where}
            ORDER BY created_at DESC LIMIT :limit
        """),
        params,
    )
    rows = result.fetchall()
    return {"logs": [r._asdict() for r in rows]}


# ---------------------------------------------------------------------------
# References management
# ---------------------------------------------------------------------------

@router.get("/references")
async def list_references(
    status: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """List member reference requests with optional status filter."""
    admin.require("verify")

    conditions = []
    params: dict = {"limit": page_size, "offset": (page - 1) * page_size}

    if status:
        conditions.append("rm.status = :status")
        params["status"] = status

    where = ("WHERE " + " AND ".join(conditions)) if conditions else ""

    result = await db.execute(
        text(f"""
            SELECT
                rm.id,
                rm.user_id,
                rm.reference_user_id,
                rm.status,
                rm.created_at,
                rm.confirmed_at,
                rm.rejected_at,
                pu.full_name  AS user_name,
                pr.full_name  AS reference_name
            FROM reference_members rm
            LEFT JOIN profiles pu ON pu.user_id = rm.user_id
            LEFT JOIN profiles pr ON pr.user_id = rm.reference_user_id
            {where}
            ORDER BY rm.created_at DESC
            LIMIT :limit OFFSET :offset
        """),
        params,
    )
    rows = result.fetchall()

    return {
        "references": [
            {
                "id": str(r.id),
                "user_id": str(r.user_id),
                "reference_user_id": str(r.reference_user_id),
                "status": r.status,
                "created_at": r.created_at,
                "confirmed_at": r.confirmed_at,
                "rejected_at": r.rejected_at,
                "user_name": r.user_name,
                "reference_name": r.reference_name,
            }
            for r in rows
        ]
    }


# ---------------------------------------------------------------------------
# Reports — dismiss action (resolve already exists above)
# ---------------------------------------------------------------------------

class DismissReportRequest(BaseModel):
    resolution_note: str


@router.post("/reports/{report_id}/dismiss")
async def dismiss_report(
    report_id: UUID,
    body: DismissReportRequest,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    admin.require("moderate")

    result = await db.execute(
        text("SELECT id, status FROM reports WHERE id = :rid"),
        {"rid": report_id},
    )
    row = result.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Report not found")
    if row.status in ("resolved", "dismissed"):
        raise HTTPException(status_code=409, detail="Report has already been processed")

    await db.execute(
        text("""
            UPDATE reports
            SET status = 'dismissed',
                reviewed_by = :admin_id,
                reviewed_at = NOW(),
                resolution_note = :note
            WHERE id = :rid
        """),
        {"rid": report_id, "admin_id": admin.admin_id, "note": body.resolution_note},
    )
    await db.commit()
    await log_action(db, "admin", admin.admin_id, "dismiss_report", "report", report_id)
    return {"success": True}


# ---------------------------------------------------------------------------
# Admin user management  (super_admin only)
# ---------------------------------------------------------------------------

class CreateAdminRequest(BaseModel):
    full_name: str
    email: str
    role: str
    password: str


class PatchAdminRequest(BaseModel):
    is_active: bool


@router.get("/admins")
async def list_admins(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """List all admin accounts. Super Admin only."""
    admin.require("*")  # Only super_admin has '*'

    result = await db.execute(
        text("""
            SELECT id, email, full_name, role, is_active, created_at, last_login_at
            FROM admin_users
            ORDER BY created_at DESC
            LIMIT :limit OFFSET :offset
        """),
        {"limit": page_size, "offset": (page - 1) * page_size},
    )
    rows = result.fetchall()

    count_result = await db.execute(text("SELECT COUNT(*) AS total FROM admin_users"))
    total = count_result.fetchone().total

    return {
        "admins": [
            {
                "id": str(r.id),
                "email": r.email,
                "full_name": r.full_name,
                "role": r.role,
                "is_active": r.is_active,
                "created_at": r.created_at,
                "last_login_at": r.last_login_at,
            }
            for r in rows
        ],
        "total": total,
    }


@router.post("/admins", status_code=status.HTTP_201_CREATED)
async def create_admin(
    body: CreateAdminRequest,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Create a new admin account. Super Admin only."""
    admin.require("*")

    valid_roles = {"super_admin", "admin", "moderator", "support"}
    if body.role not in valid_roles:
        raise HTTPException(status_code=422, detail=f"Role must be one of: {valid_roles}")

    # Check email uniqueness
    existing = await db.execute(
        text("SELECT id FROM admin_users WHERE email = :email"),
        {"email": body.email.lower().strip()},
    )
    if existing.fetchone():
        raise HTTPException(status_code=409, detail="An admin with this email already exists")

    if len(body.password) < 8:
        raise HTTPException(status_code=422, detail="Password must be at least 8 characters")

    pw_hash = hash_password(body.password)

    result = await db.execute(
        text("""
            INSERT INTO admin_users (email, password_hash, full_name, role, is_active)
            VALUES (:email, :pw_hash, :full_name, :role, TRUE)
            RETURNING id
        """),
        {
            "email": body.email.lower().strip(),
            "pw_hash": pw_hash,
            "full_name": body.full_name.strip(),
            "role": body.role,
        },
    )
    new_id = result.fetchone().id
    await db.commit()

    await log_action(
        db, "admin", admin.admin_id, "create_admin", "admin_user", new_id,
        {"email": body.email, "role": body.role},
    )

    return {"id": str(new_id), "email": body.email, "role": body.role}


@router.patch("/admins/{target_id}")
async def update_admin_status(
    target_id: UUID,
    body: PatchAdminRequest,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Enable or disable an admin account. Super Admin only."""
    admin.require("*")

    # Prevent self-disablement
    if str(target_id) == str(admin.admin_id):
        raise HTTPException(status_code=400, detail="You cannot disable your own account")

    result = await db.execute(
        text("SELECT id, full_name FROM admin_users WHERE id = :tid"),
        {"tid": target_id},
    )
    row = result.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Admin not found")

    await db.execute(
        text("UPDATE admin_users SET is_active = :active, updated_at = NOW() WHERE id = :tid"),
        {"active": body.is_active, "tid": target_id},
    )
    await db.commit()

    action = "enable_admin" if body.is_active else "disable_admin"
    await log_action(db, "admin", admin.admin_id, action, "admin_user", target_id)

    return {"success": True, "is_active": body.is_active}


# ---------------------------------------------------------------------------
# Settings  (super_admin only)
# ---------------------------------------------------------------------------

# ponytail: settings are stored as key/value rows in a simple table.
# The frontend renders whatever the backend returns — no hardcoded keys.
# Add rows to the app_settings table to expose new configuration.
# Upgrade path: switch to a typed Pydantic config model if settings grow complex.

@router.get("/settings")
async def get_settings_endpoint(
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Return platform settings. Super Admin only."""
    admin.require("*")

    result = await db.execute(
        text("SELECT key, value, description FROM app_settings ORDER BY key")
    )
    rows = result.fetchall()
    # Return as flat dict so the React panel can render it generically
    return {r.key: r.value for r in rows}


@router.put("/settings")
async def update_settings_endpoint(
    body: dict,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Update platform settings. Super Admin only."""
    admin.require("*")

    if not body:
        raise HTTPException(status_code=422, detail="No settings provided")

    for key, value in body.items():
        await db.execute(
            text("""
                INSERT INTO app_settings (key, value, updated_by, updated_at)
                VALUES (:key, :value, :admin_id, NOW())
                ON CONFLICT (key) DO UPDATE
                    SET value = EXCLUDED.value,
                        updated_by = EXCLUDED.updated_by,
                        updated_at = NOW()
            """),
            {"key": key, "value": str(value), "admin_id": admin.admin_id},
        )

    await db.commit()
    await log_action(db, "admin", admin.admin_id, "update_settings", details={"keys": list(body.keys())})
    return {"success": True, "updated": list(body.keys())}
