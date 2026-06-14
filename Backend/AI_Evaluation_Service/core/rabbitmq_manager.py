"""
RabbitMQ connection and event management for AI Evaluation Service
"""

import asyncio
import json
import logging
from typing import Optional, Callable
import aio_pika

logger = logging.getLogger(__name__)

# Exchange and queue configuration
EVALUATION_EXCHANGE = 'evaluation_events'
EVALUATION_RESULTS_QUEUE = 'evaluation_results_queue'
EVALUATION_ROUTING_KEY = 'evaluation.completed'

# Topics for consuming events
VIDEO_SUBMITTED_EXCHANGE = 'video_events'
VIDEO_SUBMITTED_QUEUE = 'video_submitted_for_evaluation'
VIDEO_SUBMITTED_ROUTING_KEY = 'video.submitted'

AUDITION_EVENTS_EXCHANGE = 'auditions_exchange'
AUDITION_EVENTS_QUEUE = 'ai_evaluation_audition_events_queue'
AUDITION_CREATED_ROUTING_KEY = 'audition.created'
AUDITION_UPDATED_ROUTING_KEY = 'audition.updated'
AUDITION_SUBMITTED_ROUTING_KEY = 'audition.submitted'


class RabbitMQManager:
    """Manages RabbitMQ connections and event publishing/consuming"""
    def __init__(self):
        self.connection: Optional[aio_pika.RobustConnection] = None
        self.consumer_channel: Optional[aio_pika.Channel] = None   # dedicated to consuming
        self.publisher_channel: Optional[aio_pika.Channel] = None  # dedicated to publishing
        self.evaluation_exchange: Optional[aio_pika.Exchange] = None
        self.video_exchange: Optional[aio_pika.Exchange] = None
        self.audition_exchange: Optional[aio_pika.Exchange] = None
        
    async def initialize(self, max_retries: int = 10) -> bool:
        """
        Connect to RabbitMQ and initialize exchanges/queues.

        Uses two separate channels:
          - publisher_channel: used only for publishing evaluation results.
          - consumer_channel:  used only for consuming audition/video events.

        This prevents a long-running consumer iterator from poisoning the
        publisher channel, which was the root cause of ChannelInvalidStateError.

        Args:
            max_retries: Maximum number of connection attempts

        Returns:
            bool: True if initialized, False if connection failed
        """
        for attempt in range(max_retries):
            try:
                self.connection = await aio_pika.connect_robust(
                    'amqp://rabbitmq/',
                    heartbeat=60,                    # keep-alive ping every 60 s so the
                                                     # broker never closes an idle connection
                                                     # during long ML pipeline runs
                    blocked_connection_timeout=300,  # allow up to 5 min of back-pressure
                )

                # ── Publisher channel (publishing only) ──────────────────────
                self.publisher_channel = await self.connection.channel()
                self.evaluation_exchange = await self.publisher_channel.declare_exchange(
                    EVALUATION_EXCHANGE,
                    aio_pika.ExchangeType.TOPIC,
                    durable=True,
                )

                # ── Consumer channel (consuming only) ────────────────────────
                self.consumer_channel = await self.connection.channel()

                self.video_exchange = await self.consumer_channel.declare_exchange(
                    VIDEO_SUBMITTED_EXCHANGE,
                    aio_pika.ExchangeType.TOPIC,
                    durable=True,
                )

                self.audition_exchange = await self.consumer_channel.declare_exchange(
                    AUDITION_EVENTS_EXCHANGE,
                    aio_pika.ExchangeType.TOPIC,
                    durable=True,
                )

                # Declare video submission queue
                video_queue = await self.consumer_channel.declare_queue(
                    VIDEO_SUBMITTED_QUEUE,
                    durable=True,
                )
                await video_queue.bind(self.video_exchange, routing_key=VIDEO_SUBMITTED_ROUTING_KEY)

                # Declare audition events queue (bound to all three routing keys)
                audition_queue = await self.consumer_channel.declare_queue(
                    AUDITION_EVENTS_QUEUE,
                    durable=True,
                )
                await audition_queue.bind(self.audition_exchange, routing_key=AUDITION_CREATED_ROUTING_KEY)
                await audition_queue.bind(self.audition_exchange, routing_key=AUDITION_UPDATED_ROUTING_KEY)
                await audition_queue.bind(self.audition_exchange, routing_key=AUDITION_SUBMITTED_ROUTING_KEY)

                logger.info("✓ Connected to RabbitMQ")
                return True

            except Exception as e:
                if attempt < max_retries - 1:
                    logger.warning(
                        f"RabbitMQ connection attempt {attempt + 1}/{max_retries} failed: {str(e)}"
                    )
                    await asyncio.sleep(3)
                else:
                    logger.error(f"Failed to connect to RabbitMQ after {max_retries} attempts")
                    return False

        return False

    # ── Publisher helpers ────────────────────────────────────────────────────

    async def _get_evaluation_exchange(self) -> aio_pika.Exchange:
        """
        Return a live evaluation exchange, transparently reopening the
        publisher channel if it has been closed (e.g. after a long ML run).
        """
        if self.publisher_channel is None or self.publisher_channel.is_closed:
            logger.warning("Publisher channel closed — reopening...")
            self.publisher_channel = await self.connection.channel()
            self.evaluation_exchange = await self.publisher_channel.declare_exchange(
                EVALUATION_EXCHANGE,
                aio_pika.ExchangeType.TOPIC,
                durable=True,
            )
            logger.info("✓ Publisher channel reopened")
        return self.evaluation_exchange

    async def publish_evaluation_completed(self, evaluation_id: str, **kwargs):
        """
        Publish evaluation completed event with flexible parameters.

        Args:
            evaluation_id: Unique evaluation identifier
            **kwargs: Additional message fields (e.g. media_id, overall_score,
                      submission_id, etc.)
        """
        logger.debug(f"publish_evaluation_completed called for {evaluation_id}")

        try:
            exchange = await self._get_evaluation_exchange()

            message_body = {
                'evaluation_id': evaluation_id,
                'eventType': 'EVALUATION_COMPLETED',
                'timestamp': __import__('datetime').datetime.utcnow().isoformat(),
                **kwargs,
            }

            message = aio_pika.Message(
                body=json.dumps(message_body).encode(),
                content_type='application/json',
                delivery_mode=aio_pika.DeliveryMode.PERSISTENT,
            )

            await exchange.publish(message, routing_key=EVALUATION_ROUTING_KEY)
            logger.info(f"✓ Published evaluation completed event for {evaluation_id}")

        except Exception as e:
            logger.error(
                f"✗ Failed to publish evaluation completed event for {evaluation_id}: {str(e)}",
                exc_info=True,
            )

    async def publish_evaluation_result(
        self,
        evaluation_id: str,
        video_id: str,
        user_id: str,
        overall_score: float,
        performance_level: str,
        metrics: dict,
        submission_id: Optional[str] = None,
        director_id: Optional[str] = None,
        actor_id: Optional[str] = None,
    ):
        """
        Publish a detailed evaluation result event.

        Args:
            evaluation_id: Unique evaluation identifier
            video_id: Associated video ID
            user_id: User who submitted video
            overall_score: Final evaluation score (0-100)
            performance_level: Performance category
            metrics: Detailed metric scores
            submission_id: Audition submission ID
            director_id: Director ID
            actor_id: Actor ID
        """
        try:
            exchange = await self._get_evaluation_exchange()

            message_body = {
                'evaluation_id': evaluation_id,
                'video_id': video_id,
                'user_id': user_id,
                'overall_score': overall_score,
                'performance_level': performance_level,
                'metrics': metrics,
                'submission_id': submission_id,
                'director_id': director_id,
                'actor_id': actor_id,
                'timestamp': __import__('datetime').datetime.utcnow().isoformat(),
            }

            message = aio_pika.Message(
                body=json.dumps(message_body).encode(),
                content_type='application/json',
                delivery_mode=aio_pika.DeliveryMode.PERSISTENT,
            )

            await exchange.publish(message, routing_key=EVALUATION_ROUTING_KEY)
            logger.info(f"✓ Published evaluation result for {evaluation_id}")

        except Exception as e:
            logger.error(f"✗ Failed to publish evaluation result: {str(e)}")
            raise

    # ── Consumer helpers ─────────────────────────────────────────────────────

    async def consume_video_submissions(self, callback: Callable):
        """
        Consume video submission events from queue.

        Args:
            callback: Async function to handle each message with signature:
                      async def callback(message_body: dict)
        """
        if not self.consumer_channel:
            raise RuntimeError("RabbitMQ not initialized")

        try:
            queue = await self.consumer_channel.get_queue(VIDEO_SUBMITTED_QUEUE)

            async with queue.iterator() as queue_iter:
                async for message in queue_iter:
                    try:
                        async with message.process():
                            body = json.loads(message.body.decode())
                            await callback(body)
                    except Exception as e:
                        logger.error(f"Error processing video submission message: {str(e)}")
                        await message.nack(requeue=True)

        except Exception as e:
            logger.error(f"Error consuming video submissions: {str(e)}")

    async def consume_audition_events(self, callback: Callable):
        """
        Consume audition events (created, updated, submitted).

        Args:
            callback: Async function with signature:
                      async def callback(routing_key: str, message_body: dict)
        """
        if not self.consumer_channel:
            raise RuntimeError("RabbitMQ not initialized")

        try:
            queue = await self.consumer_channel.get_queue(AUDITION_EVENTS_QUEUE)

            async with queue.iterator() as queue_iter:
                async for message in queue_iter:
                    try:
                        async with message.process():
                            body = json.loads(message.body.decode())
                            routing_key = message.routing_key
                            await callback(routing_key, body)
                    except Exception as e:
                        logger.error(f"Error processing audition event message: {str(e)}")
                        await message.nack(requeue=True)

        except Exception as e:
            logger.error(f"Error consuming audition events: {str(e)}")

    # ── Lifecycle ────────────────────────────────────────────────────────────

    async def close(self):
        """Close RabbitMQ connection (both channels are closed automatically)."""
        if self.connection:
            await self.connection.close()
            logger.info("RabbitMQ connection closed")