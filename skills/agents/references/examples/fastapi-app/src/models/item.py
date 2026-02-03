"""Item model schemas."""

from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, Field


class ItemBase(BaseModel):
    """Base item schema with common fields."""

    name: str = Field(..., min_length=1, max_length=200)
    description: str | None = None
    price: Decimal = Field(..., ge=0, decimal_places=2)
    quantity: int = Field(default=0, ge=0)
    is_available: bool = True


class ItemCreate(ItemBase):
    """Schema for creating a new item."""

    owner_id: int


class ItemUpdate(BaseModel):
    """Schema for updating an existing item."""

    name: str | None = Field(None, min_length=1, max_length=200)
    description: str | None = None
    price: Decimal | None = Field(None, ge=0, decimal_places=2)
    quantity: int | None = Field(None, ge=0)
    is_available: bool | None = None


class Item(ItemBase):
    """Item response schema."""

    id: int
    owner_id: int
    created_at: datetime
    updated_at: datetime | None = None

    model_config = {"from_attributes": True}
