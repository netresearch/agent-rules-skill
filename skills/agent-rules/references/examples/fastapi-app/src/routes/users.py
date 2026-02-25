"""User management endpoints."""

from fastapi import APIRouter, HTTPException, status

from src.models.user import User, UserCreate, UserUpdate
from src.services.user_service import UserService

router = APIRouter()
user_service = UserService()


@router.get("/", response_model=list[User])
async def list_users(skip: int = 0, limit: int = 100) -> list[User]:
    """List all users with pagination."""
    return user_service.get_all(skip=skip, limit=limit)


@router.get("/{user_id}", response_model=User)
async def get_user(user_id: int) -> User:
    """Get a specific user by ID."""
    user = user_service.get_by_id(user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User with id {user_id} not found",
        )
    return user


@router.post("/", response_model=User, status_code=status.HTTP_201_CREATED)
async def create_user(user_data: UserCreate) -> User:
    """Create a new user."""
    return user_service.create(user_data)


@router.put("/{user_id}", response_model=User)
async def update_user(user_id: int, user_data: UserUpdate) -> User:
    """Update an existing user."""
    user = user_service.update(user_id, user_data)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User with id {user_id} not found",
        )
    return user


@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_user(user_id: int) -> None:
    """Delete a user."""
    if not user_service.delete(user_id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User with id {user_id} not found",
        )
