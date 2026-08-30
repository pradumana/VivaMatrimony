"""Main API v1 router — aggregates all endpoint modules."""
from fastapi import APIRouter

from .endpoints import auth, profile, search, social, verification, biodata, admin

api_router = APIRouter(prefix="/api/v1")

api_router.include_router(auth.router)
api_router.include_router(profile.router)
api_router.include_router(profile.prefs_router)
api_router.include_router(search.router)
api_router.include_router(social.router)
api_router.include_router(verification.router)
api_router.include_router(biodata.router)
api_router.include_router(admin.router)
