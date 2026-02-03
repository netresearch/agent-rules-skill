"""User service for business logic."""

from datetime import datetime, timezone

from src.models.user import User, UserCreate, UserUpdate


class UserService:
    """Service class for user operations."""

    def __init__(self) -> None:
        """Initialize with in-memory storage for demo."""
        self._users: dict[int, User] = {}
        self._next_id = 1

    def get_all(self, skip: int = 0, limit: int = 100) -> list[User]:
        """Get all users with pagination."""
        users = list(self._users.values())
        return users[skip : skip + limit]

    def get_by_id(self, user_id: int) -> User | None:
        """Get a user by ID."""
        return self._users.get(user_id)

    def get_by_email(self, email: str) -> User | None:
        """Get a user by email."""
        for user in self._users.values():
            if user.email == email:
                return user
        return None

    def create(self, user_data: UserCreate) -> User:
        """Create a new user."""
        user = User(
            id=self._next_id,
            email=user_data.email,
            username=user_data.username,
            full_name=user_data.full_name,
            is_active=user_data.is_active,
            created_at=datetime.now(timezone.utc),
        )
        self._users[self._next_id] = user
        self._next_id += 1
        return user

    def update(self, user_id: int, user_data: UserUpdate) -> User | None:
        """Update an existing user."""
        user = self._users.get(user_id)
        if not user:
            return None

        update_data = user_data.model_dump(exclude_unset=True)
        update_data.pop("password", None)  # Don't include password in response

        updated_user = user.model_copy(
            update={
                **update_data,
                "updated_at": datetime.now(timezone.utc),
            }
        )
        self._users[user_id] = updated_user
        return updated_user

    def delete(self, user_id: int) -> bool:
        """Delete a user."""
        if user_id not in self._users:
            return False
        del self._users[user_id]
        return True
