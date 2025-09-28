# FastAPI Backend Setup Guide

## Overview

This guide creates the FastAPI backend application within the existing apisix-dagobah repository. The FastAPI app is purpose-built to work with APISIX - handling route logic while APISIX manages authentication, rate limiting, and user management.

## Repository Setup

### 1. Navigate to Existing Repository
```bash
# Navigate to the apisix-dagobah repository
cd /3spread/apisix-dagobah

# Create FastAPI application directory
mkdir -p fastapi-backend
cd fastapi-backend
```

### 2. Project Structure
Create the following directory structure within `/3spread/apisix-dagobah/`:
```
apisix-dagobah/
├── apisix_conf/               # Existing APISIX config
├── dashboard_conf/            # Existing dashboard config
├── prometheus_conf/           # Existing monitoring config
├── grafana_conf/              # Existing Grafana config
├── scripts/                   # Existing deployment scripts
├── docs/                      # Existing documentation
├── fastapi-backend/           # NEW: FastAPI application
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py            # FastAPI application entry point
│   │   ├── database.py        # Database connection to existing PostgreSQL
│   │   ├── models/
│   │   │   ├── __init__.py
│   │   │   └── base.py        # SQLAlchemy models
│   │   ├── routers/
│   │   │   ├── __init__.py
│   │   │   ├── health.py      # Health check endpoints
│   │   │   └── api_v1.py      # Main API routes
│   │   ├── schemas/
│   │   │   ├── __init__.py
│   │   │   └── response.py    # Pydantic response models
│   │   └── core/
│   │       ├── __init__.py
│   │       ├── config.py      # Settings and configuration
│   │       └── deps.py        # Dependencies (DB sessions, etc.)
│   ├── Dockerfile
│   ├── requirements.txt
│   └── .env.example
├── docker-compose.yml         # Updated to include FastAPI service
└── .env
```

## Core Configuration Files

### 3. requirements.txt
```txt
fastapi==0.104.1
uvicorn[standard]==0.24.0
sqlalchemy==2.0.23
psycopg2-binary==2.9.9
pydantic==2.5.0
pydantic-settings==2.1.0
alembic==1.13.1
```

### 4. Dockerfile
```dockerfile
FROM python:3.12-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app/ app/

# Expose port
EXPOSE 8000

# Run the application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
```

### 5. .env.example
```env
# Database connection (connects to existing APISIX PostgreSQL)
DATABASE_URL=postgresql://postgres:your_postgres_password@postgres:5432/dagobah_db

# FastAPI settings
API_V1_STR=/api/v1
PROJECT_NAME=3spread-dagobah-api
DEBUG=True
```

### 6. .gitignore
```gitignore
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

.env
.venv
env/
venv/
ENV/
env.bak/
venv.bak/

.pytest_cache/
.coverage
htmlcov/
.tox/
.cache
nosetests.xml
coverage.xml
*.cover
.hypothesis/

.DS_Store
.vscode/
.idea/
*.swp
*.swo
*~
```

## Application Code

### 7. app/core/config.py
```python
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # Database
    database_url: str = "postgresql://postgres:password@postgres:5432/dagobah_db"

    # API
    api_v1_str: str = "/api/v1"
    project_name: str = "3spread Dagobah API"
    debug: bool = True

    # APISIX Integration
    # Note: APISIX handles auth - this API trusts requests that reach it
    trust_apisix_headers: bool = True

    class Config:
        env_file = ".env"

settings = Settings()
```

### 8. app/database.py
```python
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

from app.core.config import settings

# Connect to the same PostgreSQL database that APISIX uses
engine = create_engine(settings.database_url)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def get_db():
    """Database dependency for FastAPI routes"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

### 9. app/core/deps.py
```python
from typing import Generator
from sqlalchemy.orm import Session
from app.database import get_db

# Database dependency
def get_database() -> Generator[Session, None, None]:
    return get_db()

# APISIX consumer extraction (from headers)
def get_current_consumer(x_consumer_username: str = None) -> str:
    """
    Extract consumer info from APISIX headers.
    APISIX will set headers like X-Consumer-Username when auth succeeds.
    """
    if not x_consumer_username:
        return "anonymous"
    return x_consumer_username
```

### 10. app/routers/health.py
```python
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.core.deps import get_database

router = APIRouter(prefix="/health", tags=["health"])

@router.get("/")
async def health_check():
    """Basic health check endpoint"""
    return {
        "status": "healthy",
        "service": "3spread-dagobah-api",
        "message": "API is running"
    }

@router.get("/db")
async def database_health(db: Session = Depends(get_database)):
    """Database connectivity check"""
    try:
        # Simple query to test DB connection
        db.execute("SELECT 1")
        return {
            "status": "healthy",
            "database": "connected",
            "message": "Database connection successful"
        }
    except Exception as e:
        return {
            "status": "unhealthy",
            "database": "disconnected",
            "error": str(e)
        }
```

### 11. app/routers/api_v1.py
```python
from fastapi import APIRouter, Depends, Header
from sqlalchemy.orm import Session
from typing import Optional

from app.core.deps import get_database, get_current_consumer

router = APIRouter(prefix="/v1", tags=["api-v1"])

@router.get("/status")
async def api_status(
    consumer: str = Depends(get_current_consumer),
    db: Session = Depends(get_database)
):
    """API status endpoint - authenticated via APISIX"""
    return {
        "status": "operational",
        "consumer": consumer,
        "message": "3spread regulatory data API is operational"
    }

# Placeholder endpoints for future development
@router.get("/filings")
async def list_filings(
    consumer: str = Depends(get_current_consumer),
    db: Session = Depends(get_database)
):
    """List available regulatory filings"""
    return {
        "filings": [],
        "consumer": consumer,
        "message": "Filings endpoint - to be implemented"
    }

@router.get("/search")
async def search_filings(
    q: Optional[str] = None,
    consumer: str = Depends(get_current_consumer),
    db: Session = Depends(get_database)
):
    """Search regulatory filings"""
    return {
        "query": q,
        "results": [],
        "consumer": consumer,
        "message": "Search endpoint - to be implemented"
    }
```

### 12. app/main.py
```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.routers import health, api_v1

# Create FastAPI application
app = FastAPI(
    title=settings.project_name,
    description="3spread regulatory filings API - works with APISIX gateway",
    version="1.0.0",
    docs_url="/docs" if settings.debug else None,
    redoc_url="/redoc" if settings.debug else None
)

# CORS middleware (APISIX may handle this, but keeping for development)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure properly for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(health.router)
app.include_router(api_v1.router, prefix=settings.api_v1_str)

@app.get("/")
async def root():
    return {
        "message": "3spread Dagobah API",
        "docs": "/docs",
        "health": "/health"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

## APISIX Integration

### 13. Update APISIX docker-compose.yml
Add this service to `/3spread/apisix-dagobah/docker-compose.yml`:

```yaml
services:
  # ... existing services ...

  apisix-dagobah-api:
    build: ./fastapi-backend
    container_name: apisix-dagobah-api
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql://postgres:${POSTGRES_PASSWORD}@postgres:5432/dagobah_db
      - DEBUG=true
    depends_on:
      - postgres
    networks:
      - apisix
    volumes:
      - ./fastapi-backend/app:/app/app  # For hot reloading in development
    restart: unless-stopped
```

### 14. APISIX Route Configuration
Add to your APISIX routes configuration script:

```bash
# Health check route (light rate limits)
curl -X PUT ${ADMIN_URL}/routes/health \
  -H "X-API-KEY: ${ADMIN_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "uri": "/api/health/*",
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "apisix-dagobah-api:8000": 1
      }
    },
    "plugins": {
      "prometheus": {"prefer_name": true}
    }
  }'

# Authenticated API routes
curl -X PUT ${ADMIN_URL}/routes/api-v1 \
  -H "X-API-KEY: ${ADMIN_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "uri": "/api/v1/*",
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "apisix-dagobah-api:8000": 1
      }
    },
    "plugins": {
      "key-auth": {},
      "limit-count": {
        "count": 100,
        "time_window": 60,
        "key": "consumer_name"
      },
      "prometheus": {"prefer_name": true}
    }
  }'
```

## Deployment Instructions

### 15. Initial Setup
```bash
# 1. Navigate to existing apisix-dagobah repository
cd /3spread/apisix-dagobah

# 2. Create FastAPI backend directory and files
mkdir -p fastapi-backend
# Follow the structure above to create all files

# 3. Create environment file (if using separate env for FastAPI)
cd fastapi-backend
cp .env.example .env
# Edit .env with actual database credentials (or use main .env)

# 4. Build and start the FastAPI service
cd /3spread/apisix-dagobah
docker compose up -d apisix-dagobah-api

# 5. Verify FastAPI is running
curl http://localhost:8000/health
curl http://localhost:8000/docs  # API documentation

# 6. Test through APISIX (after configuring routes)
curl http://localhost:9080/api/health/
curl -H "X-API-KEY: test-api-key-12345" http://localhost:9080/api/v1/status
```

### 16. Development Workflow
```bash
# Start development environment (all services including FastAPI)
cd /3spread/apisix-dagobah
docker compose up -d

# View FastAPI logs
docker compose logs -f apisix-dagobah-api

# Restart API after code changes
docker compose restart apisix-dagobah-api

# Access FastAPI directly (bypassing APISIX)
curl http://localhost:8000/api/v1/status

# Access via APISIX (production flow)
curl -H "X-API-KEY: your-api-key" http://localhost:9080/api/v1/status
```

## Key Integration Points

1. **Database**: FastAPI connects to the same PostgreSQL instance as APISIX
2. **Authentication**: APISIX handles all auth - FastAPI trusts incoming requests
3. **Monitoring**: All requests flow through APISIX Prometheus metrics
4. **Rate Limiting**: Handled by APISIX, not FastAPI
5. **CORS**: Can be handled by either APISIX or FastAPI
6. **Logging**: Both services log to the same Docker network

## Next Steps

1. **Create FastAPI directory structure** within `/3spread/apisix-dagobah/fastapi-backend/`
2. **Build initial structure** with the files above
3. **Update docker-compose.yml** to include the FastAPI service
4. **Test integration** with existing APISIX stack
5. **Configure APISIX routes** to proxy to FastAPI
6. **Implement business logic** for regulatory filings processing
7. **Add database models** for your specific data requirements
8. **Commit changes** to the apisix-dagobah repository

This setup provides the foundational structure for a FastAPI backend that integrates seamlessly with your existing APISIX gateway infrastructure, all contained within the same repository for easier management and deployment.