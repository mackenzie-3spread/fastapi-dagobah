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

**Prerequisites:** APISIX stack must be running first.

```bash
# Start APISIX (in separate terminal)
cd /3spread/apisix-dagobah
docker-compose up -d

# Start FastAPI Dagobah
cd /3spread/fastapi-dagobah
./deploy.sh start
```

**API Documentation:**
- Swagger UI: http://localhost:8001/api/v1/docs
- ReDoc: http://localhost:8001/api/v1/redoc

## Deployment

### Using the Deploy Script

The `deploy.sh` script provides simple management of the FastAPI service:

```bash
# Start service (checks APISIX dependencies)
./deploy.sh start

# Stop service
./deploy.sh stop

# Restart service (skips dependency checks)
./deploy.sh restart

# Interactive debug mode
./deploy.sh debug

# View logs
./deploy.sh logs

# Live monitoring dashboard
./deploy.sh watch

# Interactive shell
./deploy.sh shell

# Show service status
./deploy.sh status

# Check health endpoint
./deploy.sh health

# Clean up everything
./deploy.sh clean
```

### Prerequisites

The script requires APISIX stack to be running:
- Docker network: `apisix-network`
- APISIX gateway: `apisix-gateway`
- PostgreSQL: `apisix-dagobah-postgres`

Start APISIX first:
```bash
cd /3spread/apisix-dagobah
docker-compose up -d
```

### Environment Configuration

The script automatically creates `.env` from `.env.production.example` if it doesn't exist. Review and update as needed:

```bash
# Edit environment variables
nano .env
```

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