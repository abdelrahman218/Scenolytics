"""
AI Evaluation Service - FastAPI
Processes audition videos using integrated ML models for:
- Video emotion recognition
- Voice/audio analysis
- Script alignment
- Body language analysis
"""

from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import os
from dotenv import load_dotenv
import logging
import asyncio

from api.routes import evaluation, health
from core.database import init_db
from core.rabbitmq_manager import RabbitMQManager
from core.ml_pipeline import MLPipeline
from core.service import handle_audition_event


# Configure logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()


async def start_event_consumers(rabbitmq_manager: RabbitMQManager, pipeline=None):
    """
    Start consuming RabbitMQ events in background
    
    This function runs indefinitely, consuming events from:
    - Audition events (create, update, submit)
    
    Args:
        rabbitmq_manager: RabbitMQManager instance
        pipeline: MLPipeline instance for background processing
    """
    try:
        logger.info("Starting event consumers...")
        
        # Create a wrapper callback that includes the pipeline
        async def audition_event_callback(routing_key, event_data):
            await handle_audition_event(routing_key, event_data, pipeline,rabbitmq_manager)
        
        await rabbitmq_manager.consume_audition_events(audition_event_callback)
    except Exception as e:
        logger.error(f"Event consumer error: {str(e)}")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage service lifecycle - startup and shutdown"""

    # Startup
    logger.info("Initializing AI Evaluation Service...")

    # Initialize database
    await init_db()
    logger.info("Database initialized")

    # Initialize ML Pipeline and store on app.state so any route can access it
    # via `http_request.app.state.ml_pipeline` without a global variable.
    app.state.ml_pipeline = MLPipeline()
    await app.state.ml_pipeline.initialize()
    logger.info("ML Pipeline initialized")

    # Initialize RabbitMQ with retry logic
    app.state.rabbitmq_manager = RabbitMQManager()
    rabbitmq_initialized = False
    retries = 10
    for attempt in range(1, retries + 1):
        try:
            await app.state.rabbitmq_manager.initialize()
            logger.info("RabbitMQ connected successfully")
            rabbitmq_initialized = True
            break
        except Exception as e:
            logger.warning(f"RabbitMQ connection attempt {attempt}/{retries} failed: {str(e)}")
            if attempt < retries:
                await asyncio.sleep(3)
            else:
                logger.error("Failed to connect to RabbitMQ after all retries - will continue without RabbitMQ")
                app.state.rabbitmq_manager = None
    
    # Start event consumers as background task (only if RabbitMQ initialized successfully)
    if rabbitmq_initialized and hasattr(app.state, 'rabbitmq_manager') and app.state.rabbitmq_manager:
        app.state.event_consumer_task = asyncio.create_task(
            start_event_consumers(app.state.rabbitmq_manager, app.state.ml_pipeline)
        )
        logger.info("Event consumer task started")
    else:
        logger.warning("RabbitMQ not initialized - event consumers will not be started")

    yield

    # Shutdown
    logger.info("Shutting down AI Evaluation Service...")
    
    # Cancel event consumer task
    if hasattr(app.state, 'event_consumer_task'):
        app.state.event_consumer_task.cancel()
        try:
            await app.state.event_consumer_task
        except asyncio.CancelledError:
            logger.info("Event consumer task cancelled")
    
    if app.state.rabbitmq_manager:
        await app.state.rabbitmq_manager.close()
    logger.info("Service shutdown complete")


# Create FastAPI app
app = FastAPI(
    title="AI Evaluation Service",
    description="ML-powered audition video evaluation service",
    version="1.0.0",
    lifespan=lifespan
)

# Setup CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routes
app.include_router(health.router, tags=["Health"])
app.include_router(evaluation.router, tags=["Evaluations"])


@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    """Global exception handler for unhandled errors"""
    logger.error(f"Unhandled exception: {str(exc)}", exc_info=exc)
    return {
        "detail": "Internal server error",
        "error": str(exc) if os.getenv("NODE_ENV") == "development" else None
    }


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("AI_EVALUATION_SERVICE_PORT", 5003))
    uvicorn.run(app, host="0.0.0.0", port=port)