# FastAPI Dagobah

FastAPI backend for 3spread regulatory filings API, designed to integrate with APISIX gateway.

## Project Structure

```
app/
├── main.py                 # FastAPI app initialization
├── core/
│   ├── config.py          # Settings (Pydantic BaseSettings)
│   ├── database.py        # DB connection & session
│   └── deps.py            # Common dependencies
├── api/
│   └── v1/
│       ├── router.py      # Main API router
│       ├── health.py      # Health checks
│       └── filings.py     # Filing endpoints
├── services/
│   └── filing_service.py  # Business logic
├── models/
│   └── filing.py          # SQLAlchemy models
├── schemas/
│   ├── filing.py          # Pydantic models
│   └── response.py        # Common response schemas
└── exceptions.py          # Custom exceptions
```

## Quick Start

1. **Copy environment variables:**
   ```bash
   cp .env.example .env
   ```

2. **Start with Docker Compose:**
   ```bash
   docker-compose up --build
   ```

3. **API Documentation:**
   - Swagger UI: http://localhost:8000/api/v1/docs
   - ReDoc: http://localhost:8000/api/v1/redoc

## Health Checks

- Basic health: `GET /api/v1/health`
- Readiness check: `GET /api/v1/health/ready`

## APISIX Integration

The application is designed to work behind APISIX and trusts these headers:
- `X-Consumer-Username`: Consumer identification
- `X-User-ID`: User identification

## Development

The project uses modern FastAPI patterns:
- Async/await throughout
- Dependency injection
- Clean architecture with service layer
- Proper error handling
- Type hints with Pydantic