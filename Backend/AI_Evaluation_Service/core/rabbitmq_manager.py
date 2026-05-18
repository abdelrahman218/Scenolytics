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


class RabbitMQManager:
    """Manages RabbitMQ connections and event publishing/consuming"""
    
    def __init__(self):
        self.connection: Optional[aio_pika.Connection] = None
        self.channel: Optional[aio_pika.Channel] = None
        self.evaluation_exchange: Optional[aio_pika.Exchange] = None
        self.video_exchange: Optional[aio_pika.Exchange] = None
    
    async def initialize(self, max_retries: int = 10) -> bool:
        """
        Connect to RabbitMQ and initialize exchanges/queues
        
        Args:
            max_retries: Maximum number of connection attempts
            
        Returns:
            bool: True if initialized, False if connection failed
        """
        for attempt in range(max_retries):
            try:
                self.connection = await aio_pika.connect_robust('amqp://rabbitmq/')
                self.channel = await self.connection.channel()
                
                # Declare exchanges
                self.evaluation_exchange = await self.channel.declare_exchange(
                    EVALUATION_EXCHANGE,
                    aio_pika.ExchangeType.TOPIC,
                    durable=True
                )
                
                self.video_exchange = await self.channel.declare_exchange(
                    VIDEO_SUBMITTED_EXCHANGE,
                    aio_pika.ExchangeType.TOPIC,
                    durable=True
                )
                
                # Declare video submission queue
                video_queue = await self.channel.declare_queue(
                    VIDEO_SUBMITTED_QUEUE,
                    durable=True
                )
                await video_queue.bind(self.video_exchange, routing_key=VIDEO_SUBMITTED_ROUTING_KEY)
                
                logger.info("✓ Connected to RabbitMQ")
                return True
                
            except Exception as e:
                if attempt < max_retries - 1:
                    logger.warning(f"RabbitMQ connection attempt {attempt + 1}/{max_retries} failed: {str(e)}")
                    await asyncio.sleep(3)
                else:
                    logger.error(f"Failed to connect to RabbitMQ after {max_retries} attempts")
                    return False
        
        return False
    
    async def publish_evaluation_result(
        self,
        evaluation_id: str,
        video_id: str,
        user_id: str,
        overall_score: float,
        performance_level: str,
        metrics: dict
    ):
        """
        Publish evaluation completed event
        
        Args:
            evaluation_id: Unique evaluation identifier
            video_id: Associated video ID
            user_id: User who submitted video
            overall_score: Final evaluation score (0-100)
            performance_level: Performance category
            metrics: Detailed metric scores
        """
        if not self.evaluation_exchange:
            raise RuntimeError("RabbitMQ not initialized")
        
        try:
            message_body = {
                'evaluation_id': evaluation_id,
                'video_id': video_id,
                'user_id': user_id,
                'overall_score': overall_score,
                'performance_level': performance_level,
                'metrics': metrics,
                'timestamp': __import__('datetime').datetime.utcnow().isoformat()
            }
            
            message = aio_pika.Message(
                body=json.dumps(message_body).encode(),
                content_type='application/json',
                delivery_mode=aio_pika.DeliveryMode.PERSISTENT
            )
            
            await self.evaluation_exchange.publish(message, routing_key=EVALUATION_ROUTING_KEY)
            logger.info(f"Published evaluation result for {evaluation_id}")
        except Exception as e:
            logger.error(f"Failed to publish evaluation result: {str(e)}")
            raise
    
    async def consume_video_submissions(self, callback: Callable):
        """
        Consume video submission events from queue
        
        Args:
            callback: Async function to handle each message(message)
        """
        if not self.channel:
            raise RuntimeError("RabbitMQ not initialized")
        
        try:
            queue = await self.channel.get_queue(VIDEO_SUBMITTED_QUEUE)
            
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
    
    async def close(self):
        """Close RabbitMQ connection"""
        if self.connection:
            await self.connection.close()
            logger.info("RabbitMQ connection closed")
