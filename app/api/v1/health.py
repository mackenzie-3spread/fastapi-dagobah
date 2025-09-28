from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text

from ...core.deps import get_db
from ...core.config import settings

router = APIRouter()


@router.get("/health")
async def health_check():
    """Basic health check endpoint"""
    return {
        "status": "healthy",
        "service": settings.app_name,
        "version": settings.version
    }


@router.get("/health/ready")
async def readiness_check(db: AsyncSession = Depends(get_db)):
    """Readiness check with database connectivity"""
    try:
        # Test database connection
        await db.execute(text("SELECT 1"))
        return {
            "status": "ready",
            "service": settings.app_name,
            "version": settings.version,
            "database": "connected"
        }
    except Exception as e:
        return {
            "status": "not ready",
            "service": settings.app_name,
            "version": settings.version,
            "database": "disconnected",
            "error": str(e)
        }