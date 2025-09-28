from sqlalchemy import Column, String, DateTime, Text, Integer
from sqlalchemy.sql import func

from ..core.database import Base


class Filing(Base):
    __tablename__ = "filings"

    id = Column(Integer, primary_key=True, index=True)
    filing_id = Column(String, unique=True, index=True, nullable=False)
    company_name = Column(String, nullable=False)
    form_type = Column(String, nullable=False)
    filing_date = Column(DateTime, nullable=False)
    content = Column(Text)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())