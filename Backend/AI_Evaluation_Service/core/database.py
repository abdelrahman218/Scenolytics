"""
Database management for AI Evaluation Service
"""

import asyncio
import logging
import os
from typing import Optional
import aiomysql
import aiomysql.cursors

logger = logging.getLogger(__name__)

# Global database pool
db_pool: Optional[aiomysql.Pool] = None


async def init_db():
    """Initialize database connection pool"""
    global db_pool

    try:
        # Get configuration from environment variables.
        # No silent fallback to 'ai-evaluation-mysql' / 'password' here —
        # that hostname is a Railway-private DNS name and is unreachable
        # from Modal. If these aren't set, fail loudly instead of retrying
        # forever against an address that can never resolve.
        db_host = os.getenv('AI_EVALUATION_SERVICE_DATABASE_HOST')
        db_port = int(os.getenv('DATABASE_PORT', 3306))
        db_user = os.getenv('DATABASE_USER')
        db_password = os.getenv('DATABASE_PASSWORD')
        db_name = os.getenv('AI_EVALUATION_SERVICE_DATABASE_NAME', 'submission_evaluation_db')

        missing = [
            name for name, val in [
                ('AI_EVALUATION_SERVICE_DATABASE_HOST', db_host),
                ('DATABASE_USER', db_user),
                ('DATABASE_PASSWORD', db_password),
            ] if not val
        ]
        if missing:
            raise RuntimeError(
                f"Missing required DB env vars: {', '.join(missing)}. "
                f"These must come from the Modal Secret attached via "
                f"secrets=[modal.Secret.from_name(...)] on AIEvaluationService "
                f"— check the secret is attached AND its key names match exactly."
            )

        logger.info(f"Connecting to database at {db_host}:{db_port}/{db_name} with user {db_user}")

        db_pool = await aiomysql.create_pool(
            host=db_host,
            port=db_port,
            user=db_user,
            password=db_password,
            db=db_name,
            minsize=5,
            maxsize=10,
            autocommit=True
        )
        logger.info("Database pool initialized successfully")
    except Exception as e:
        logger.error(f"Failed to initialize database: {str(e)}")
        raise


async def get_db():
    """Get database connection from pool"""
    if db_pool is None:
        raise RuntimeError("Database pool not initialized")
    return await db_pool.acquire()


async def close_db():
    """Close database pool"""
    global db_pool
    if db_pool:
        db_pool.close()
        await db_pool.wait_closed()
        logger.info("Database pool closed")


class Database:
    """Database OOP wrapper for connection pool"""

    def __init__(self):
        """Initialize database wrapper"""
        self.pool = db_pool

    async def execute(self, query: str, params: tuple = None):
        """Execute a query without returning results"""
        if self.pool is None:
            raise RuntimeError("Database pool not initialized")

        conn = await self.pool.acquire()
        try:
            async with conn.cursor() as cursor:
                await cursor.execute(query, params or ())
                if conn.get_autocommit():
                    await conn.commit()
            logger.debug(f"Executed query: {query}")
        except Exception as e:
            logger.error(f"Query execution error: {str(e)}")
            raise
        finally:
            self.pool.release(conn)

    async def fetch_one(self, query: str, params: tuple = None):
        """Fetch a single row from database"""
        if self.pool is None:
            raise RuntimeError("Database pool not initialized")

        conn = await self.pool.acquire()
        try:
            async with conn.cursor(aiomysql.cursors.DictCursor) as cursor:
                await cursor.execute(query, params or ())
                result = await cursor.fetchone()
            return result
        except Exception as e:
            logger.error(f"Fetch one error: {str(e)}")
            raise
        finally:
            self.pool.release(conn)

    async def fetch_all(self, query: str, params: tuple = None):
        """Fetch all rows from database"""
        if self.pool is None:
            raise RuntimeError("Database pool not initialized")

        conn = await self.pool.acquire()
        try:
            async with conn.cursor(aiomysql.cursors.DictCursor) as cursor:
                await cursor.execute(query, params or ())
                results = await cursor.fetchall()
            return results
        except Exception as e:
            logger.error(f"Fetch all error: {str(e)}")
            raise
        finally:
            self.pool.release(conn)


async def execute_query(query: str, args: tuple = ()):
    """Execute a database query"""
    conn = await get_db()
    try:
        async with conn.cursor() as cursor:
            await cursor.execute(query, args)
            return await cursor.fetchall()
    finally:
        db_pool.release(conn)


async def execute_insert(query: str, args: tuple = ()):
    """Execute an INSERT query"""
    conn = await get_db()
    try:
        async with conn.cursor() as cursor:
            await cursor.execute(query, args)
            await conn.commit()
            return cursor.lastrowid
    finally:
        db_pool.release(conn)


async def execute_update(query: str, args: tuple = ()):
    """Execute an UPDATE query"""
    conn = await get_db()
    try:
        async with conn.cursor() as cursor:
            await cursor.execute(query, args)
            await conn.commit()
            return cursor.rowcount
    finally:
        db_pool.release(conn)