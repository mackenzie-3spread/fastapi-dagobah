from fastapi import APIRouter, Depends
from typing import Dict, Any

from ...core.deps import get_consumer_info

router = APIRouter()


@router.get("/filings")
async def list_filings(
    consumer_info: Dict[str, Any] = Depends(get_consumer_info)
):
    """List regulatory filings"""
    return {
        "filings": [],
        "consumer": consumer_info.get("consumer"),
        "user_id": consumer_info.get("user_id"),
        "message": "Filings endpoint - ready for implementation"
    }


@router.get("/filings/{filing_id}")
async def get_filing(
    filing_id: str,
    consumer_info: Dict[str, Any] = Depends(get_consumer_info)
):
    """Get specific regulatory filing"""
    return {
        "filing_id": filing_id,
        "consumer": consumer_info.get("consumer"),
        "user_id": consumer_info.get("user_id"),
        "message": "Filing detail endpoint - ready for implementation"
    }