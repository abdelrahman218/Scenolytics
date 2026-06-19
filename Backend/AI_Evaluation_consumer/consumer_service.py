import asyncio
import json
import logging
import os
import signal
import uuid

import aio_pika
import modal

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("consumer")

RABBITMQ_URL = os.environ["RABBITMQ_URL"]

AUDITION_EVENTS_QUEUE = "ai_evaluation_audition_events_queue"

# Must match app.name / class name in modal_app.py exactly
MODAL_APP_NAME = "ai-evaluation-service"
MODAL_CLASS_NAME = "AIEvaluationService"

# Look up the deployed Modal class once at import time.
# Requires MODAL_TOKEN_ID / MODAL_TOKEN_SECRET env vars to be set on Railway
# (generate via `modal token new` or from the Modal dashboard -> Settings -> API Tokens).
evaluation_cls = modal.Cls.from_name(MODAL_APP_NAME, MODAL_CLASS_NAME)
evaluation_service = evaluation_cls()


async def trigger_evaluation(evaluation_id: str, event_data: dict):
    """
    Fire off AIEvaluationService.evaluate() on Modal without blocking the
    consumer. spawn() kicks off remote execution and returns immediately
    with a FunctionCall handle — matches your existing architecture since
    Modal publishes the real result back over RabbitMQ
    (publish_evaluation_completed) when it's done.
    """
    try:
        call = await evaluation_service.evaluate.spawn.aio(evaluation_id, event_data)
        logger.info(
            "Spawned Modal evaluation %s -> call_id=%s",
            evaluation_id, call.object_id,
        )
    except Exception as e:
        logger.error(
            "Failed to spawn Modal evaluation for %s: %s",
            evaluation_id, e, exc_info=True,
        )


async def handle_audition_event(routing_key: str, data: dict):
    """
    NOTE: field names below (video_key / script_text) are guesses based on
    what evaluate() expects in modal_app.py. Confirm against your actual
    audition.submitted payload before relying on this.
    """
    if routing_key != "audition.submitted":
        logger.info("Ignoring routing key %s (not audition.submitted)", routing_key)
        return

    evaluation_id = data.get("evaluation_id") or data.get("submission_id") or str(uuid.uuid4())

    event_data = {
        "video_key": data.get("video_key") or data.get("video_url"),
        "script_text": data.get("script_text") or data.get("script"),
    }

    if not event_data["video_key"]:
        logger.warning("Skipping %s — no video_key in payload: %s", routing_key, data)
        return

    await trigger_evaluation(evaluation_id, event_data)


async def consume(queue: aio_pika.Queue):
    async with queue.iterator() as q:
        async for message in q:
            try:
                async with message.process():
                    data = json.loads(message.body.decode())
                    routing_key = message.routing_key
                    logger.info("Received: %s | %s", routing_key, data)

                    # Don't await inline — a slow Modal spawn() call (network
                    # round trip) would otherwise stall the whole consumer loop.
                    asyncio.create_task(handle_audition_event(routing_key, data))
            except Exception as e:
                logger.error("Failed to process message: %s", e, exc_info=True)


async def main():
    logger.info("Starting consumer...")

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