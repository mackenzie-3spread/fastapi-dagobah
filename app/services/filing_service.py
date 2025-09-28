from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List, Optional

from ..models.filing import Filing
from ..schemas.filing import FilingCreate, FilingUpdate


class FilingService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_filing_by_id(self, filing_id: str) -> Optional[Filing]:
        """Get filing by filing_id"""
        stmt = select(Filing).where(Filing.filing_id == filing_id)
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_filings(self, skip: int = 0, limit: int = 100) -> List[Filing]:
        """Get list of filings with pagination"""
        stmt = select(Filing).offset(skip).limit(limit)
        result = await self.db.execute(stmt)
        return result.scalars().all()

    async def create_filing(self, filing_data: FilingCreate) -> Filing:
        """Create new filing"""
        filing = Filing(**filing_data.dict())
        self.db.add(filing)
        await self.db.commit()
        await self.db.refresh(filing)
        return filing

    async def update_filing(self, filing_id: str, filing_data: FilingUpdate) -> Optional[Filing]:
        """Update existing filing"""
        filing = await self.get_filing_by_id(filing_id)
        if not filing:
            return None

        update_data = filing_data.dict(exclude_unset=True)
        for field, value in update_data.items():
            setattr(filing, field, value)

        await self.db.commit()
        await self.db.refresh(filing)
        return filing

    async def delete_filing(self, filing_id: str) -> bool:
        """Delete filing"""
        filing = await self.get_filing_by_id(filing_id)
        if not filing:
            return False

        await self.db.delete(filing)
        await self.db.commit()
        return True