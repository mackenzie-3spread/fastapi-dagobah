from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from .config import settings


class Base(DeclarativeBase):
    pass


engine = None
async_session_maker = None


def init_db():
    global engine, async_session_maker

    if not settings.database_url:
        raise ValueError("DATABASE_URL must be set")

    engine = create_async_engine(
        settings.database_url,
        echo=settings.debug,
        future=True
    )

    async_session_maker = async_sessionmaker(
        engine, class_=AsyncSession, expire_on_commit=False
    )


async def get_db_session() -> AsyncSession:
    if not async_session_maker:
        raise RuntimeError("Database not initialized. Call init_db() first.")

    async with async_session_maker() as session:
        try:
            yield session
        finally:
            await session.close()