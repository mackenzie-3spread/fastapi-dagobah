from pydantic import BaseModel
from typing import Generic, TypeVar, Optional, List, Any

T = TypeVar('T')


class BaseResponse(BaseModel, Generic[T]):
    success: bool = True
    message: Optional[str] = None
    data: Optional[T] = None


class ErrorResponse(BaseModel):
    success: bool = False
    error: str
    detail: Optional[str] = None


class ListResponse(BaseModel, Generic[T]):
    items: List[T]
    total: int
    page: int = 1
    per_page: int = 100


class HealthResponse(BaseModel):
    status: str
    service: str
    version: str
    database: Optional[str] = None
    error: Optional[str] = None