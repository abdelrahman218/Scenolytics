"""
Health check endpoints for AI Evaluation Service
"""

import logging
from fastapi import APIRouter, Response

from core import database, rabbitmq_manager
from core.ml_pipeline import MLPipeline

logger = logging.getLogger(__name__)
router = APIRouter(prefix='/api/health', tags=['health'])


@router.get('/')
async def health_check():
    """
    Service health check endpoint
    Returns status of all service dependencies
    """
    try:
        # Check database
        db_status = 'healthy'
        db_error = None
        try:
            # Simple query to verify database connectivity
            results = await database.execute_query('SELECT 1')
            if not results:
                db_status = 'unhealthy'
        except Exception as e:
            db_status = 'unhealthy'
            db_error = str(e)
        
        # Check RabbitMQ
        rabbitmq_status = 'healthy' if rabbitmq_manager.channel else 'unhealthy'
        
        # Check ML models
        ml_status = 'degraded'  # Models initialized but not fully loaded until first use
        model_errors = {}
        
        try:
            pipeline = MLPipeline()
            # Check if models are loaded
            if pipeline.emotion_model is None:
                model_errors['emotion'] = 'Not loaded'
            if pipeline.audio_model is None:
                model_errors['audio'] = 'Not loaded'
            if pipeline.script_model is None:
                model_errors['script_alignment'] = 'Not loaded'
            
            if not model_errors:
                ml_status = 'healthy'
        except Exception as e:
            ml_status = 'unhealthy'
            model_errors['pipeline_init'] = str(e)
        
        # Determine overall status
        overall_status = 'healthy'
        if db_status != 'healthy' or rabbitmq_status != 'healthy':
            overall_status = 'unhealthy'
        elif ml_status == 'unhealthy':
            overall_status = 'degraded'
        elif ml_status == 'degraded':
            overall_status = 'degraded'
        
        status_code = 200 if overall_status == 'healthy' else (503 if overall_status == 'unhealthy' else 200)
        
        return {
            'status': overall_status,
            'timestamp': __import__('datetime').datetime.utcnow().isoformat(),
            'dependencies': {
                'database': {
                    'status': db_status,
                    'error': db_error
                },
                'rabbitmq': {
                    'status': rabbitmq_status
                },
                'ml_models': {
                    'status': ml_status,
                    'errors': model_errors if model_errors else None
                }
            }
        }
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        return {
            'status': 'unhealthy',
            'error': str(e)
        }


@router.get('/ready')
async def readiness_check():
    """
    Readiness probe for Kubernetes/orchestration
    Returns 200 only if service is fully ready to accept requests
    """
    try:
        # Check all critical dependencies
        db_ready = await database.execute_query('SELECT 1')
        rabbitmq_ready = rabbitmq_manager.channel is not None
        
        if db_ready and rabbitmq_ready:
            return {
                'ready': True,
                'timestamp': __import__('datetime').datetime.utcnow().isoformat()
            }
        else:
            return Response(
                content='{"ready": false}',
                status_code=503,
                media_type='application/json'
            )
    except Exception as e:
        logger.error(f"Readiness check failed: {str(e)}")
        return Response(
            content='{"ready": false}',
            status_code=503,
            media_type='application/json'
        )


@router.get('/live')
async def liveness_check():
    """
    Liveness probe for Kubernetes/orchestration
    Returns 200 if service is alive and responsive
    """
    try:
        return {
            'live': True,
            'timestamp': __import__('datetime').datetime.utcnow().isoformat()
        }
    except Exception as e:
        logger.error(f"Liveness check failed: {str(e)}")
        return Response(
            content='{"live": false}',
            status_code=500,
            media_type='application/json'
        )
