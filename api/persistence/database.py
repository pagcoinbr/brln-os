"""
Database connection pool and session management.

Provides SQLAlchemy engine, session factory, and utility functions
for database operations across the atomic swap system.
"""

import logging
import os
from contextlib import contextmanager
from typing import Generator

from sqlalchemy import create_engine, event, pool
from sqlalchemy.engine import Engine
from sqlalchemy.orm import sessionmaker, Session, scoped_session
from sqlalchemy.pool import QueuePool, NullPool

from api.persistence.models import Base

logger = logging.getLogger(__name__)


# Database configuration from environment variables
DATABASE_URL = os.getenv(
    'DATABASE_URL',
    'postgresql://brln_swap_user:changeme@localhost:5432/brln_swaps'
)

# Connection pool settings
POOL_SIZE = int(os.getenv('DB_POOL_SIZE', '10'))
MAX_OVERFLOW = int(os.getenv('DB_MAX_OVERFLOW', '20'))
POOL_TIMEOUT = int(os.getenv('DB_POOL_TIMEOUT', '30'))
POOL_RECYCLE = int(os.getenv('DB_POOL_RECYCLE', '3600'))  # 1 hour

# Engine instance (singleton)
_engine: Engine = None
_session_factory: sessionmaker = None
_scoped_session_factory: scoped_session = None


def get_database_url() -> str:
    """Get database URL from environment with fallback."""
    url = os.getenv('DATABASE_URL')

    if not url:
        # Build from components
        db_type = os.getenv('DB_TYPE', 'postgresql')
        db_host = os.getenv('DB_HOST', 'localhost')
        db_port = os.getenv('DB_PORT', '5432')
        db_user = os.getenv('DB_USER', 'brln_swap_user')
        db_password = os.getenv('DB_PASSWORD', 'changeme')
        db_name = os.getenv('DB_NAME', 'brln_swaps')

        if db_type == 'postgresql':
            url = f'postgresql://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}'
        elif db_type == 'sqlite':
            db_path = os.getenv('DB_PATH', '/var/lib/brln-swaps/swaps.db')
            url = f'sqlite:///{db_path}'
        else:
            raise ValueError(f"Unsupported DB_TYPE: {db_type}")

    return url


def create_db_engine(
    database_url: str = None,
    echo: bool = False,
    pool_size: int = POOL_SIZE,
    max_overflow: int = MAX_OVERFLOW,
    pool_timeout: int = POOL_TIMEOUT,
    pool_recycle: int = POOL_RECYCLE
) -> Engine:
    """
    Create SQLAlchemy engine with connection pooling.

    Args:
        database_url: Database connection string (uses env if not provided)
        echo: Enable SQL query logging
        pool_size: Size of connection pool
        max_overflow: Max connections beyond pool_size
        pool_timeout: Seconds to wait for connection
        pool_recycle: Seconds before recycling connections

    Returns:
        SQLAlchemy Engine instance
    """
    if database_url is None:
        database_url = get_database_url()

    logger.info(f"Creating database engine for: {database_url.split('@')[-1]}")  # Hide credentials

    # Determine if SQLite
    is_sqlite = database_url.startswith('sqlite')

    # Create engine with appropriate pooling
    if is_sqlite:
        # SQLite: use NullPool (no connection pooling)
        engine = create_engine(
            database_url,
            echo=echo,
            poolclass=NullPool,
            connect_args={
                'check_same_thread': False,  # Allow multi-threaded access
                'timeout': 30.0  # 30 second lock timeout
            }
        )

        # Enable WAL mode for better concurrency
        @event.listens_for(engine, "connect")
        def set_sqlite_pragma(dbapi_conn, connection_record):
            cursor = dbapi_conn.cursor()
            cursor.execute("PRAGMA journal_mode=WAL")
            cursor.execute("PRAGMA synchronous=NORMAL")
            cursor.execute("PRAGMA foreign_keys=ON")
            cursor.close()
    else:
        # PostgreSQL: use QueuePool
        engine = create_engine(
            database_url,
            echo=echo,
            poolclass=QueuePool,
            pool_size=pool_size,
            max_overflow=max_overflow,
            pool_timeout=pool_timeout,
            pool_recycle=pool_recycle,
            pool_pre_ping=True,  # Verify connections before using
            echo_pool=False
        )

    return engine


def init_db(engine: Engine = None) -> Engine:
    """
    Initialize database: create engine and all tables.

    Args:
        engine: Existing engine (creates new if not provided)

    Returns:
        Engine instance
    """
    global _engine, _session_factory, _scoped_session_factory

    if engine is None:
        engine = create_db_engine()

    _engine = engine

    # Create all tables
    logger.info("Creating database tables...")
    Base.metadata.create_all(bind=engine)
    logger.info("Database tables created successfully")

    # Create session factory
    _session_factory = sessionmaker(
        bind=engine,
        autocommit=False,
        autoflush=False,
        expire_on_commit=False
    )

    # Create scoped session for thread-safety
    _scoped_session_factory = scoped_session(_session_factory)

    return engine


def get_engine() -> Engine:
    """Get the global engine instance."""
    global _engine
    if _engine is None:
        _engine = create_db_engine()
    return _engine


def get_session_factory() -> sessionmaker:
    """Get the global session factory."""
    global _session_factory
    if _session_factory is None:
        engine = get_engine()
        _session_factory = sessionmaker(
            bind=engine,
            autocommit=False,
            autoflush=False,
            expire_on_commit=False
        )
    return _session_factory


def get_scoped_session() -> scoped_session:
    """Get the global scoped session factory (thread-safe)."""
    global _scoped_session_factory
    if _scoped_session_factory is None:
        factory = get_session_factory()
        _scoped_session_factory = scoped_session(factory)
    return _scoped_session_factory


@contextmanager
def get_db_session() -> Generator[Session, None, None]:
    """
    Context manager for database sessions.

    Usage:
        with get_db_session() as session:
            swap = session.query(Swap).filter_by(id=swap_id).first()
            # ... do work ...
            session.commit()

    Automatically handles:
    - Session creation
    - Commit on success
    - Rollback on exception
    - Session cleanup
    """
    session = get_session_factory()()
    try:
        yield session
        session.commit()
    except Exception as e:
        session.rollback()
        logger.error(f"Database session error: {e}", exc_info=True)
        raise
    finally:
        session.close()


@contextmanager
def get_db_session_no_autocommit() -> Generator[Session, None, None]:
    """
    Context manager for database sessions without auto-commit.

    Use when you need explicit commit control.

    Usage:
        with get_db_session_no_autocommit() as session:
            swap = session.query(Swap).filter_by(id=swap_id).first()
            swap.state = SwapState.CLAIMED
            # ... more work ...
            session.commit()  # Explicit commit
    """
    session = get_session_factory()()
    try:
        yield session
    except Exception as e:
        session.rollback()
        logger.error(f"Database session error: {e}", exc_info=True)
        raise
    finally:
        session.close()


def close_db():
    """Close database connections and dispose engine."""
    global _engine, _session_factory, _scoped_session_factory

    if _scoped_session_factory:
        _scoped_session_factory.remove()
        _scoped_session_factory = None

    if _session_factory:
        _session_factory = None

    if _engine:
        logger.info("Disposing database engine...")
        _engine.dispose()
        _engine = None
        logger.info("Database connections closed")


def check_db_connection() -> bool:
    """
    Check if database connection is working.

    Returns:
        True if connection successful, False otherwise
    """
    try:
        engine = get_engine()
        with engine.connect() as conn:
            result = conn.execute("SELECT 1")
            result.fetchone()
        logger.info("Database connection check: OK")
        return True
    except Exception as e:
        logger.error(f"Database connection check failed: {e}")
        return False


def get_db_stats() -> dict:
    """
    Get database connection pool statistics.

    Returns:
        Dictionary with pool stats
    """
    engine = get_engine()

    stats = {
        'database_url': str(engine.url).split('@')[-1],  # Hide credentials
        'dialect': engine.dialect.name,
        'driver': engine.driver
    }

    # Pool stats (only for pooled connections)
    if hasattr(engine.pool, 'size'):
        stats.update({
            'pool_size': engine.pool.size(),
            'checked_in': engine.pool.checkedin(),
            'checked_out': engine.pool.checkedout(),
            'overflow': engine.pool.overflow(),
            'total_connections': engine.pool.size() + engine.pool.overflow()
        })

    return stats


# Alembic migration helpers

def run_migrations():
    """Run Alembic migrations programmatically."""
    try:
        from alembic import command
        from alembic.config import Config

        # Find alembic.ini
        alembic_cfg = Config("alembic.ini")

        # Run upgrade to head
        command.upgrade(alembic_cfg, "head")
        logger.info("Database migrations completed successfully")
    except ImportError:
        logger.warning("Alembic not installed - skipping migrations")
    except Exception as e:
        logger.error(f"Migration error: {e}", exc_info=True)
        raise


# Initialize on module import (optional)
if os.getenv('AUTO_INIT_DB', '').lower() == 'true':
    logger.info("AUTO_INIT_DB enabled - initializing database")
    init_db()
