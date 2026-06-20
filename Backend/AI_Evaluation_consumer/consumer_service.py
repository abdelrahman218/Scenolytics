import asyncio
import json
import logging
import os
import signal
import uuid
from datetime import datetime

import aio_pika
import modal

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("consumer")

RABBITMQ_URL = os.environ["RABBITMQ_URL"]

AUDITION_EVENTS_QUEUE = "ai_evaluation_audition_events_queue"

MODAL_APP_NAME = "ai-evaluation-service"
MODAL_CLASS_NAME = "AIEvaluationService"

_evaluation_cls = modal.Cls.from_name(MODAL_APP_NAME, MODAL_CLASS_NAME)
_evaluation_service = _evaluation_cls()


# ── DB helpers ───────────────────────────────────────────────────────────────
# Mirrors audition_service.py's AuditionService / EvaluationService, but
# folded into this consumer since this is the process actually receiving
# the RabbitMQ events. Uses core.database's pooled connection.

async def create_audition(event_data: dict):
    """Persist an audition row on audition.created / audition.updated."""
    from core.database import get_db

    audition_id = event_data.get("id") or str(uuid.uuid4())
    media_id = event_data.get("media_id", "") or ""
    submission_id = event_data.get("submission_id")
    actor_id = event_data.get("actor_id")
    director_id = event_data.get("director_id")
    script = event_data.get("script")
    audio_only = (event_data.get("type", "") or "").strip().lower() != "video"

    if isinstance(script, (dict, list)):
        script = json.dumps(script)

    conn = await get_db()
    try:
        async with conn.cursor() as cursor:
            await cursor.execute(
                """
                INSERT INTO auditions
                    (audition_id, media_id, submission_id, actor_id, director_id, script, audio_only, status)
                VALUES (%s, %s, %s, %s, %s, %s, %s, 'pending')
                ON DUPLICATE KEY UPDATE
                    media_id = VALUES(media_id),
                    submission_id = VALUES(submission_id),
                    actor_id = VALUES(actor_id),
                    director_id = VALUES(director_id),
                    script = VALUES(script),
                    audio_only = VALUES(audio_only),
                    updated_at = CURRENT_TIMESTAMP
                """,
                (audition_id, media_id, submission_id, actor_id, director_id, script, audio_only),
            )
            await conn.commit()
        logger.info("✓ Audition persisted: %s", audition_id)
        return audition_id
    except Exception as e:
        logger.error("✗ Error creating audition %s: %s", audition_id, e, exc_info=True)
        return None
    finally:
        conn.close()


async def get_audition_by_id(audition_id: str):
    """Fetch an audition row by audition_id (UUID string)."""
    from core.database import get_db
    import aiomysql

    conn = await get_db()
    try:
        async with conn.cursor(aiomysql.cursors.DictCursor) as cursor:
            await cursor.execute(
                """
                SELECT id, audition_id, media_id, submission_id, actor_id,
                       director_id, script, status, audio_only
                FROM auditions
                WHERE audition_id = %s
                LIMIT 1
                """,
                (audition_id,),
            )
            return await cursor.fetchone()
    except Exception as e:
        logger.error("✗ Error fetching audition %s: %s", audition_id, e, exc_info=True)
        return None
    finally:
        conn.close()


def resolve_script_text(audition_row: dict | None) -> str | None:
    """
    Build the JSON-array script_text expected by MLPipeline._parse_script():
        '[{"content": "...", "emotion": "..."}, ...]'
    auditions.script is stored as raw JSON text from create_audition(), so
    if it's already a valid non-empty JSON array string, pass it straight
    through. No separate sentences table exists in this schema.
    """
    if not audition_row:
        return None
    script = audition_row.get("script")
    if not script:
        return None
    text = str(script).strip()
    if not text or text in ("[]", "null"):
        return None
    return text


async def create_evaluation(evaluation_id: str, media_id: str, submission_id: str | None):
    """INSERT the evaluations row with status='pending', matching modal_app.py's _write_results UPDATE target."""
    from core.database import get_db

    conn = await get_db()
    try:
        async with conn.cursor() as cursor:
            await cursor.execute(
                """
                INSERT INTO evaluations
                    (evaluation_id, media_id, submission_id, evaluation_status, created_at)
                VALUES (%s, %s, %s, 'pending', %s)
                """,
                (evaluation_id, media_id, submission_id, datetime.utcnow().isoformat()),
            )
            await conn.commit()
        logger.info("✓ Evaluation row created: %s", evaluation_id)
        return True
    except Exception as e:
        logger.error("✗ Error creating evaluation row %s: %s", evaluation_id, e, exc_info=True)
        return False
    finally:
        conn.close()


# ── Event handlers ───────────────────────────────────────────────────────────

async def handle_audition_created_or_updated(event_data: dict):
    await create_audition(event_data)


async def handle_audition_submitted(event_data: dict):
    """
    On audition.submitted:
      1. Look up the audition row (already persisted from audition.created)
         to resolve script_text and audio_only.
      2. INSERT the evaluations row.
      3. Spawn Modal's evaluate(), which downloads from MinIO, runs the
         pipeline, and writes scores back via _write_results.
    """
    submission_id = event_data.get("id")
    audition_id = event_data.get("audition_id")
    media_id = event_data.get("media_id")

    if not media_id:
        logger.warning("Skipping audition.submitted %s — no media_id", submission_id)
        return

    audition_row = await get_audition_by_id(audition_id) if audition_id else None
    if not audition_row:
        logger.warning(
            "No audition row found for audition_id=%s (submission=%s) — "
            "script score will be 0, audio_only defaults to False",
            audition_id, submission_id,
        )

    script_text = resolve_script_text(audition_row)
    audio_only = bool(audition_row.get("audio_only")) if audition_row else False

    evaluation_id = str(uuid.uuid4())
    if not await create_evaluation(evaluation_id, media_id, submission_id):
        return  # already logged


    try:
        call = await _evaluation_service.evaluate.spawn.aio(evaluation_id, event_data)
        logger.info(
            "✓ Spawned Modal evaluation %s (media_id=%s, audio_only=%s) -> call_id=%s",
            evaluation_id, media_id, audio_only, call.object_id,
        )
    except Exception as e:
        logger.error("✗ Failed to spawn Modal evaluation for %s: %s", evaluation_id, e, exc_info=True)
        from core.database import get_db
        conn = await get_db()
        try:
            async with conn.cursor() as cursor:
                await cursor.execute(
                    "UPDATE evaluations SET evaluation_status='failed', error_message=%s WHERE evaluation_id=%s",
                    (str(e), evaluation_id),
                )
                await conn.commit()
        finally:
            conn.close()


async def handle_event(routing_key: str, data: dict):
    if routing_key in ("audition.created", "audition.updated"):
        await handle_audition_created_or_updated(data)
    elif routing_key == "audition.submitted":
        await handle_audition_submitted(data)
    else:
        logger.warning("Unknown routing key: %s", routing_key)


# ── RabbitMQ plumbing ────────────────────────────────────────────────────────

async def consume(queue: aio_pika.Queue):
    async with queue.iterator() as q:
        async for message in q:
            try:
                async with message.process():
                    data = json.loads(message.body.decode())
                    routing_key = message.routing_key
                    logger.info("Received: %s | %s", routing_key, data)
                    # Don't await inline — DB writes + a Modal spawn() call
                    # shouldn't stall the whole consumer loop.
                    asyncio.create_task(handle_event(routing_key, data))
            except Exception as e:
                logger.error("Failed to process message: %s", e, exc_info=True)


async def main():
    logger.info("Starting consumer...")

    from core.database import init_db
    await init_db()

    connection = await aio_pika.connect_robust(
        RABBITMQ_URL,
        heartbeat=60,
        blocked_connection_timeout=300,
    )

    channel = await connection.channel()
    await channel.set_qos(prefetch_count=10)

    queue = await channel.declare_queue(
        AUDITION_EVENTS_QUEUE,
        durable=True,
    )

    logger.info("Consuming from queue: %s", AUDITION_EVENTS_QUEUE)

    task = asyncio.create_task(consume(queue))

    stop_event = asyncio.Event()

    def stop(*_):
        logger.info("Stopping consumer...")
        stop_event.set()

    loop = asyncio.get_event_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, stop)

    await stop_event.wait()
    task.cancel()

    await connection.close()
    logger.info("Consumer stopped")


if __name__ == "__main__":
    asyncio.run(main())