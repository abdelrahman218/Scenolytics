# consumer_app.py — run manually before a demo/discussion:
#   modal run consumer_app.py
# Stop with Ctrl+C when the session is over. No deploy, no idle billing
# outside the window it's actually running.

import json
import os
import uuid
from datetime import datetime

import modal

app = modal.App("ai-evaluation-consumer")

image = modal.Image.debian_slim().pip_install("aio-pika", "aiomysql")

MODAL_APP_NAME = "ai-evaluation-service"
MODAL_CLASS_NAME = "AIEvaluationService"
AUDITION_EVENTS_QUEUE = "ai_evaluation_audition_events_queue"


@app.function(
    image=image,
    secrets=[modal.Secret.from_name("ai-evaluation-secrets")],
    timeout=60 * 60 * 4,  # 4 hours — adjust to however long a session might run
)
async def run_consumer():
    import asyncio
    import logging

    import aio_pika
    import aiomysql

    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger("consumer")

    RABBITMQ_URL = os.environ["RABBITMQ_URL"]

    # ── inline DB pool (self-contained, no cross-service imports) ──────────
    db_pool = await aiomysql.create_pool(
        host=os.environ["AI_EVALUATION_SERVICE_DATABASE_HOST"],
        port=int(os.environ.get("DATABASE_PORT", 3306)),
        user=os.environ["DATABASE_USER"],
        password=os.environ["DATABASE_PASSWORD"],
        db=os.environ.get("AI_EVALUATION_SERVICE_DATABASE_NAME", "submission_evaluation_db"),
        minsize=1,
        maxsize=5,
        autocommit=True,
    )
    logger.info("✓ DB pool ready")

    evaluation_cls = modal.Cls.from_name(MODAL_APP_NAME, MODAL_CLASS_NAME)
    evaluation_service = evaluation_cls()

    async def create_audition(event_data: dict):
        audition_id = event_data.get("id") or str(uuid.uuid4())
        media_id = event_data.get("media_id", "") or ""
        submission_id = event_data.get("submission_id")
        actor_id = event_data.get("actor_id")
        director_id = event_data.get("director_id")
        script = event_data.get("script")
        audio_only = (event_data.get("type", "") or "").strip().lower() != "video"
        if isinstance(script, (dict, list)):
            script = json.dumps(script)

        async with db_pool.acquire() as conn:
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
        logger.info("✓ Audition persisted: %s", audition_id)

    async def get_audition_by_id(audition_id: str):
        async with db_pool.acquire() as conn:
            async with conn.cursor(aiomysql.cursors.DictCursor) as cursor:
                await cursor.execute(
                    """
                    SELECT id, audition_id, media_id, submission_id, actor_id,
                           director_id, script, status, audio_only
                    FROM auditions WHERE audition_id = %s LIMIT 1
                    """,
                    (audition_id,),
                )
                return await cursor.fetchone()

    def resolve_script_text(row):
        if not row:
            return None
        script = row.get("script")
        if not script:
            return None
        text = str(script).strip()
        return text if text and text not in ("[]", "null") else None

    async def create_evaluation(evaluation_id, media_id, submission_id):
        async with db_pool.acquire() as conn:
            async with conn.cursor() as cursor:
                await cursor.execute(
                    """
                    INSERT INTO evaluations
                        (evaluation_id, media_id, submission_id, evaluation_status, created_at)
                    VALUES (%s, %s, %s, 'pending', %s)
                    """,
                    (evaluation_id, media_id, submission_id, datetime.utcnow().isoformat()),
                )
        logger.info("✓ Evaluation row created: %s", evaluation_id)

    async def handle_submitted(event_data: dict):
        submission_id = event_data.get("id")
        media_id = event_data.get("media_id")
        if not media_id:
            logger.warning("Skipping %s — no media_id", submission_id)
            return

        evaluation_id = str(uuid.uuid4())
        await create_evaluation(evaluation_id, media_id, submission_id)

        call = await evaluation_service.evaluate.spawn.aio(evaluation_id, event_data)
        logger.info("✓ Spawned evaluation %s -> call_id=%s", evaluation_id, call.object_id)

    async def handle_event(routing_key: str, data: dict):
        if routing_key in ("audition.created", "audition.updated"):
            await create_audition(data)
        elif routing_key == "audition.submitted":
            await handle_submitted(data)
        else:
            logger.warning("Unknown routing key: %s", routing_key)

    connection = await aio_pika.connect_robust(RABBITMQ_URL, heartbeat=60)
    channel = await connection.channel()
    await channel.set_qos(prefetch_count=10)
    queue = await channel.declare_queue(AUDITION_EVENTS_QUEUE, durable=True)

    logger.info("Listening on %s — leave this running during your session, Ctrl+C to stop.", AUDITION_EVENTS_QUEUE)

    async with queue.iterator() as q:
        async for message in q:
            try:
                async with message.process():
                    data = json.loads(message.body.decode())
                    logger.info("Received: %s | %s", message.routing_key, data)
                    asyncio.create_task(handle_event(message.routing_key, data))
            except Exception as e:
                logger.error("Failed to process message: %s", e, exc_info=True)


@app.local_entrypoint()
def main():
    run_consumer.remote()