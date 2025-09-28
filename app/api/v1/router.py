from fastapi import APIRouter

from .health import router as health_router
from .filings import router as filings_router

router = APIRouter()

# Include sub-routers
router.include_router(health_router, tags=["health"])
router.include_router(filings_router, prefix="/filings", tags=["filings"])