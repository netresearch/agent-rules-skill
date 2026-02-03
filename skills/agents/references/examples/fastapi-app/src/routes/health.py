"""Health check endpoints."""

from fastapi import APIRouter

from src.config import settings

router = APIRouter()


@router.get("/health")
async def health_check() -> dict[str, str]:
    """Basic health check endpoint."""
    return {"status": "healthy", "app": settings.app_name}


@router.get("/ready")
async def readiness_check() -> dict[str, str]:
    """Readiness check endpoint."""
    # Could add database connectivity check here
    return {"status": "ready"}
