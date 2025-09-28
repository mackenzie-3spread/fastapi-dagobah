from pydantic import BaseModel
from datetime import datetime
from typing import Optional


class FilingBase(BaseModel):
    filing_id: str
    company_name: str
    form_type: str
    filing_date: datetime
    content: Optional[str] = None


class FilingCreate(FilingBase):
    pass


class FilingUpdate(BaseModel):
    company_name: Optional[str] = None
    form_type: Optional[str] = None
    filing_date: Optional[datetime] = None
    content: Optional[str] = None


class Filing(FilingBase):
    id: int
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True