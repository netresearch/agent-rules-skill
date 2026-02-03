"""Item management endpoints."""

from fastapi import APIRouter, HTTPException, Query, status

from src.models.item import Item, ItemCreate, ItemUpdate
from src.services.item_service import ItemService

router = APIRouter()
item_service = ItemService()


@router.get("/", response_model=list[Item])
async def list_items(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    search: str | None = None,
) -> list[Item]:
    """List all items with pagination and optional search."""
    if search:
        return item_service.search(search, skip=skip, limit=limit)
    return item_service.get_all(skip=skip, limit=limit)


@router.get("/{item_id}", response_model=Item)
async def get_item(item_id: int) -> Item:
    """Get a specific item by ID."""
    item = item_service.get_by_id(item_id)
    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Item with id {item_id} not found",
        )
    return item


@router.post("/", response_model=Item, status_code=status.HTTP_201_CREATED)
async def create_item(item_data: ItemCreate) -> Item:
    """Create a new item."""
    return item_service.create(item_data)


@router.put("/{item_id}", response_model=Item)
async def update_item(item_id: int, item_data: ItemUpdate) -> Item:
    """Update an existing item."""
    item = item_service.update(item_id, item_data)
    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Item with id {item_id} not found",
        )
    return item


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_item(item_id: int) -> None:
    """Delete an item."""
    if not item_service.delete(item_id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Item with id {item_id} not found",
        )
