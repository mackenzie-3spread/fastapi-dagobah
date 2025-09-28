from fastapi import HTTPException
from typing import Any, Dict, Optional


class FilingNotFound(HTTPException):
    def __init__(self, filing_id: str):
        super().__init__(
            status_code=404,
            detail=f"Filing with id '{filing_id}' not found"
        )


class FilingAlreadyExists(HTTPException):
    def __init__(self, filing_id: str):
        super().__init__(
            status_code=409,
            detail=f"Filing with id '{filing_id}' already exists"
        )


class DatabaseError(HTTPException):
    def __init__(self, detail: str = "Database operation failed"):
        super().__init__(
            status_code=500,
            detail=detail
        )


class ValidationError(HTTPException):
    def __init__(self, detail: str = "Validation failed"):
        super().__init__(
            status_code=422,
            detail=detail
        )