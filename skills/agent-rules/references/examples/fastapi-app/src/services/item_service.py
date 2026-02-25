"""Item service for business logic."""

from datetime import datetime, timezone

from src.models.item import Item, ItemCreate, ItemUpdate


class ItemService:
    """Service class for item operations."""

    def __init__(self) -> None:
        """Initialize with in-memory storage for demo."""
        self._items: dict[int, Item] = {}
        self._next_id = 1

    def get_all(self, skip: int = 0, limit: int = 100) -> list[Item]:
        """Get all items with pagination."""
        items = list(self._items.values())
        return items[skip : skip + limit]

    def get_by_id(self, item_id: int) -> Item | None:
        """Get an item by ID."""
        return self._items.get(item_id)

    def search(self, query: str, skip: int = 0, limit: int = 100) -> list[Item]:
        """Search items by name or description."""
        query_lower = query.lower()
        results = [
            item
            for item in self._items.values()
            if query_lower in item.name.lower()
            or (item.description and query_lower in item.description.lower())
        ]
        return results[skip : skip + limit]

    def get_by_owner(self, owner_id: int) -> list[Item]:
        """Get all items for a specific owner."""
        return [item for item in self._items.values() if item.owner_id == owner_id]

    def create(self, item_data: ItemCreate) -> Item:
        """Create a new item."""
        item = Item(
            id=self._next_id,
            name=item_data.name,
            description=item_data.description,
            price=item_data.price,
            quantity=item_data.quantity,
            is_available=item_data.is_available,
            owner_id=item_data.owner_id,
            created_at=datetime.now(timezone.utc),
        )
        self._items[self._next_id] = item
        self._next_id += 1
        return item

    def update(self, item_id: int, item_data: ItemUpdate) -> Item | None:
        """Update an existing item."""
        item = self._items.get(item_id)
        if not item:
            return None

        update_data = item_data.model_dump(exclude_unset=True)
        updated_item = item.model_copy(
            update={
                **update_data,
                "updated_at": datetime.now(timezone.utc),
            }
        )
        self._items[item_id] = updated_item
        return updated_item

    def delete(self, item_id: int) -> bool:
        """Delete an item."""
        if item_id not in self._items:
            return False
        del self._items[item_id]
        return True
