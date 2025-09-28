from fastapi import Depends, Header, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional

from .database import get_db_session
from .config import settings


async def get_db() -> AsyncSession:
    async for session in get_db_session():
        yield session


async def get_consumer_info(
    consumer: Optional[str] = Header(None, alias=settings.apisix_consumer_header),
    user_id: Optional[str] = Header(None, alias=settings.apisix_user_id_header)
):
    """Extract consumer information from APISIX headers"""
    return {
        "consumer": consumer,
        "user_id": user_id
    }