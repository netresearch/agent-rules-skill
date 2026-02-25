"""User model schemas."""

from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


class UserBase(BaseModel):
    """Base user schema with common fields."""

    email: EmailStr
    username: str = Field(..., min_length=3, max_length=50)
    full_name: str | None = None
    is_active: bool = True


class UserCreate(UserBase):
    """Schema for creating a new user."""

    password: str = Field(..., min_length=8)


class UserUpdate(BaseModel):
    """Schema for updating an existing user."""

    email: EmailStr | None = None
    username: str | None = Field(None, min_length=3, max_length=50)
    full_name: str | None = None
    is_active: bool | None = None
    password: str | None = Field(None, min_length=8)


class User(UserBase):
    """User response schema."""

    id: int
    created_at: datetime
    updated_at: datetime | None = None

    model_config = {"from_attributes": True}
