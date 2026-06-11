"""
Service layer for AI Evaluation Service
Handles business logic for audition and evaluation management
"""

import json
import logging
import uuid
from datetime import datetime
from typing import Optional, Dict, Any
from core.database import get_db
from core.rabbitmq_manager import (
    AUDITION_CREATED_ROUTING_KEY,
    AUDITION_UPDATED_ROUTING_KEY,
    AUDITION_SUBMITTED_ROUTING_KEY,
)
logger = logging.getLogger(__name__)


class AuditionService:
    """Service for managing auditions"""
    
    @staticmethod
    async def create_audition(audition_data: Dict[str, Any]) -> Optional[int]:
        """
        Create audition record in database
        
        Args:
            audition_data: Dictionary containing audition information from event
                Expected keys: audition_id, actor_id, director_id, script (optional)
        
        Returns:
            audition_id: ID of created audition, or None if failed
        """
        try:
            conn = await get_db()
            async with conn.cursor() as cursor:
                # Extract data with defaults
                audition_id = audition_data.get('id') or str(uuid.uuid4())
                media_id = audition_data.get('media_id', '')
                submission_id = audition_data.get('submission_id')
                actor_id = audition_data.get('actor_id')
                director_id = audition_data.get('director_id')
                script = audition_data.get('script')
                audio_only = audition_data.get('type', '').strip().lower() != 'video'     
                if isinstance(script, (dict, list)):
                   script = json.dumps(script)
                query = """
                    INSERT INTO auditions 
                    (audition_id, media_id, submission_id, actor_id, director_id, script, audio_only ,status)
                    VALUES (%s, %s, %s, %s, %s, %s, %s,'pending')
                    ON DUPLICATE KEY UPDATE
                    media_id = VALUES(media_id),
                    submission_id = VALUES(submission_id),
                    actor_id = VALUES(actor_id),
                    director_id = VALUES(director_id),
                    script = VALUES(script),
                    audio_only = VALUES(audio_only),
                    updated_at = CURRENT_TIMESTAMP
                """
                
                await cursor.execute(
                    query,
                    (audition_id, media_id, submission_id, actor_id, director_id, script, audio_only)
                )
                await conn.commit()
                
                logger.info(f"✓ Audition created: {audition_id}")
                return audition_id
                
        except Exception as e:
            logger.error(f"✗ Error creating audition: {str(e)}")
            return None
    
    @staticmethod
    async def update_audition(audition_data: Dict[str, Any]) -> bool:
        """
        Update audition record in database
        
        Args:
            audition_data: Dictionary containing audition information
                Expected keys: audition_id, and any fields to update
        
        Returns:
            bool: True if successful, False otherwise
        """
        try:
            conn = await get_db()
            async with conn.cursor() as cursor:
                audition_id = audition_data.get('id')
                
                if not audition_id:
                    logger.warning("No audition_id provided for update")
                    return False
                
                # Build dynamic update query based on provided fields
                update_fields = []
                values = []
                
                if 'script' in audition_data:
                    update_fields.append('script = %s')
                    values.append(audition_data['script'])
                
                if 'submission_id' in audition_data:
                    update_fields.append('submission_id = %s')
                    values.append(audition_data['submission_id'])
                
                if 'status' in audition_data:
                    update_fields.append('status = %s')
                    values.append(audition_data['status'])
                
                if not update_fields:
                    logger.warning(f"No update fields provided for audition {audition_id}")
                    return False
                
                # Add updated_at and audition_id to values
                update_fields.append('updated_at = CURRENT_TIMESTAMP')
                values.append(audition_id)
                
                query = f"UPDATE auditions SET {', '.join(update_fields)} WHERE audition_id = %s"
                
                await cursor.execute(query, values)
                await conn.commit()
                
                logger.info(f"✓ Audition updated: {audition_id}")
                return True
                
        except Exception as e:
            logger.error(f"✗ Error updating audition: {str(e)}")
            return False


class SentenceService:
    """Service for managing script sentences"""
    
    @staticmethod
    async def create_sentences_for_audition(audition_id_int: int, sentences_data: list) -> bool:
        """
        Create sentence records for an audition
        
        Args:
            audition_id_int: The internal audition ID (INT primary key)
            sentences_data: List of dictionaries with keys: content, emotion, sentence_order
        
        Returns:
            bool: True if successful, False otherwise
        """
        if not sentences_data or not isinstance(sentences_data, list):
            logger.debug("No sentences to create")
            return True
        
        try:
            conn = await get_db()
            async with conn.cursor() as cursor:
                for idx, sentence in enumerate(sentences_data):
                    query = """
                        INSERT INTO sentences 
                        (audition_id, content, emotion, sentence_order)
                        VALUES (%s, %s, %s, %s)
                    """
                    
                    sentence_order = sentence.get('sentence_order', idx + 1)
                    emotion = sentence.get('emotion', 'neutral')
                    content = sentence.get('content', '')
                    
                    await cursor.execute(
                        query,
                        (audition_id_int, content, emotion, sentence_order)
                    )
                
                await conn.commit()
                logger.info(f"✓ Created {len(sentences_data)} sentences for audition {audition_id_int}")
                return True
                
        except Exception as e:
            logger.error(f"✗ Error creating sentences: {str(e)}")
            return False
    
    @staticmethod
    async def get_sentences_by_audition_id(audition_id_int: int) -> Optional[list]:
        """
        Fetch all sentences for an audition
        
        Args:
            audition_id_int: The internal audition ID (INT primary key)
        
        Returns:
            List of sentence dictionaries or None if error
        """
        try:
            conn = await get_db()
            async with conn.cursor() as cursor:
                query = """
                    SELECT id, audition_id, emotion, content, sentence_order, created_at, updated_at 
                    FROM sentences 
                    WHERE audition_id = %s 
                    ORDER BY sentence_order ASC
                """
                await cursor.execute(query, (audition_id_int,))
                results = await cursor.fetchall()
                
                if results:
                    columns = [desc[0] for desc in cursor.description]
                    return [dict(zip(columns, row)) for row in results]
                
                return []
                
        except Exception as e:
            logger.error(f"✗ Error fetching sentences: {str(e)}")
            return None


class EvaluationService:
    """Service for managing evaluations"""

    @staticmethod
    async def resolve_script_for_submission(
        submission_data: Dict[str, Any],
    ) -> Optional[str]:
        """
        Load expected script for alignment scoring.

        Auditions are keyed by casting ``audition_id``; ``submission_id`` on the
        auditions row is usually unset until much later, so submission-only
        lookup often misses the script entirely.
        """
        audition_id = submission_data.get("audition_id")
        submission_id = submission_data.get("id")

        audition = None
        if audition_id:
            audition = await EvaluationService.get_audition_by_id(str(audition_id))
        if audition is None and submission_id:
            audition = await EvaluationService.get_audition_by_submission_id(
                str(submission_id)
            )

        if not audition:
            logger.warning(
                "No audition row for submission %s (audition_id=%s) — script score will be 0",
                submission_id,
                audition_id,
            )
            return None
        logger.info(f"Audition row: {audition}")
        logger.info(f"Script field raw value: {repr(audition.get('script'))}")
        script = audition.get("script")
        if script is not None:
            if isinstance(script, (dict, list)):
                if script:
                    return json.dumps(script)
            else:
                text = str(script).strip()
                if text and text not in ("[]", "null"):
                    return text

        internal_id = audition.get("id")
        if internal_id:
            sentences = await SentenceService.get_sentences_by_audition_id(internal_id)
            if sentences:
                payload = [
                    {
                        "content": s.get("content", ""),
                        "emotion": s.get("emotion", "neutral"),
                    }
                    for s in sentences
                    if s.get("content")
                ]
                if payload:
                    logger.info(
                        "Built script JSON from %d sentences for audition %s",
                        len(payload),
                        audition_id,
                    )
                    return json.dumps(payload)

        logger.warning(
            "Audition %s has no script or sentences — script score will be 0",
            audition_id or submission_id,
        )
        return None

    @staticmethod
    async def create_evaluation_for_submission(submission_data: Dict[str, Any], pipeline=None,rabbitmq_manager=None) -> Optional[str]:
        """
        Create evaluation record when audition is submitted and queue ML pipeline processing
        
        NOTE: There may be a delay for the video to appear in minio storage
        as the frontend handles video upload asynchronously. The evaluation
        will be created with 'pending' status and updated once processing completes.
        
        Args:
            submission_data: Dictionary containing submission information from event
                Expected keys: id (submission_id), media_id, audition_id, actor_id, director_id
            pipeline: MLPipeline instance for background processing (optional)
        
        Returns:
            evaluation_id: ID of created evaluation, or None if failed
        """
        try:
            conn = await get_db()
            async with conn.cursor() as cursor:
                # Extract data from submission event
                submission_id = submission_data.get('id')
                media_id = submission_data.get('media_id')
                evaluation_id = str(uuid.uuid4())
                audition = await EvaluationService.get_audition_by_id(
                    submission_data.get("audition_id")
                )
                audio_only = bool(audition.get("audio_only"))
                now = datetime.utcnow().isoformat()
                
                script = await EvaluationService.resolve_script_for_submission(
                    submission_data
                )
                
                query = """
                    INSERT INTO evaluations
                    (evaluation_id, media_id, submission_id, evaluation_status, created_at)
                    VALUES (%s, %s, %s, 'pending', %s)
                """
                
                await cursor.execute(query, (evaluation_id, media_id, submission_id, now))

                from api.routes.evaluation import run_ml_pipeline
                import asyncio
                    
                async def queue_pipeline_with_retry(eval_id, media_id, pipe, script_text,audio_only,submission_id):
                    """Queue pipeline with exponential backoff retry"""
                    max_retries = 10
                    retry_delay = 5
                    
                    for attempt in range(max_retries):
                        try:
                            asyncio.create_task(
                                run_ml_pipeline(
                                    eval_id,
                                    media_id,
                                    pipe,
                                    script_text,
                                    rabbitmq_manager,
                                    submission_id,
                                    audio_only
                                )
                            )
                            logger.debug(f"✓ ML pipeline task created for evaluation {eval_id}")
                            return
                        except Exception as e:
                            if attempt < max_retries - 1:
                                logger.warning(
                                    f"Failed to queue ML pipeline (attempt {attempt + 1}/{max_retries}): {str(e)}\n"
                                    f"Retrying in {retry_delay}s..."
                                )
                                await asyncio.sleep(retry_delay)
                                retry_delay *= 2  
                            else:
                                logger.error( 
                                    f"✗ Failed to queue ML pipeline after {max_retries} attempts: {str(e)}"
                                )
                    
                asyncio.create_task(queue_pipeline_with_retry(evaluation_id, media_id, pipeline, script, audio_only, submission_id))
                conn.commit()
                logger.info(
                    f"✓ Evaluation created for submission {submission_id}: {evaluation_id}\n"
                    f"  Note: Video may still be uploading to storage. "
                    f"Processing will begin once video is available."
                )
                return evaluation_id
                
        except Exception as e:
            logger.error(f"✗ Error creating evaluation: {str(e)}")
            return None
    
    @staticmethod
    async def get_audition_by_submission_id(submission_id: str) -> Optional[Dict[str, Any]]:
        """
        Fetch audition details by submission ID
        
        Args:
            submission_id: The submission ID to lookup
        
        Returns:
            Dictionary with audition data or None if not found
        """
        try:
            conn = await get_db()
            async with conn.cursor() as cursor:
                query = """
                    SELECT id, audition_id, media_id, submission_id, actor_id, director_id, script, status 
                    FROM auditions 
                    WHERE submission_id = %s 
                    LIMIT 1
                """
                await cursor.execute(query, (submission_id,))
                result = await cursor.fetchone()
                
                if result:
                    # Convert tuple to dict
                    columns = [desc[0] for desc in cursor.description]
                    return dict(zip(columns, result))
                
                return result
                
        except Exception as e:
            logger.error(f"✗ Error fetching audition by submission: {str(e)}")
            return None
    
    @staticmethod
    async def get_audition_by_id(audition_uuid: str) -> Optional[Dict[str, Any]]:
        """
        Fetch audition details by audition_id (UUID)
        
        Args:
            audition_uuid: The audition_id UUID to lookup
        
        Returns:
            Dictionary with audition data or None if not found
        """
        try:
            conn = await get_db()
            async with conn.cursor() as cursor:
                query = """
                    SELECT id, audition_id, media_id, submission_id, actor_id, director_id, script, status 
                    FROM auditions 
                    WHERE audition_id = %s 
                    LIMIT 1
                """
                await cursor.execute(query, (audition_uuid,))
                result = await cursor.fetchone()
                
                if result:
                    # Convert tuple to dict
                    columns = [desc[0] for desc in cursor.description]
                    return dict(zip(columns, result))
                
                return result
                
        except Exception as e:
            logger.error(f"✗ Error fetching audition by ID: {str(e)}")
            return None


async def handle_audition_event(routing_key: str, event_data: Dict[str, Any], pipeline=None,rabbitmq_manager=None):
    """
    Route and handle audition events based on routing key
    
    Args:
        routing_key: The event routing key (audition.created, audition.updated, audition.submitted)
        event_data: The event payload data
        pipeline: Optional MLPipeline instance for background processing
    """
    try:
        if routing_key == AUDITION_CREATED_ROUTING_KEY:
            audition_id = await AuditionService.create_audition(event_data)
            
            # If audition created and sentences provided, create them
            if audition_id and 'sentences' in event_data:
                audition = await AuditionService.get_audition_by_id(audition_id)
                if audition:
                    await SentenceService.create_sentences_for_audition(
                        audition['id'],  # Use INT id for foreign key
                        event_data.get('sentences', [])
                    )
            
        elif routing_key == AUDITION_UPDATED_ROUTING_KEY:
            success = await AuditionService.update_audition(event_data)
            
            # If audition updated and sentences provided, create/update them
            if success and 'sentences' in event_data:
                audition = await AuditionService.get_audition_by_id(event_data.get('id'))
                if audition:
                    # For now, we'll just add new sentences. In the future, 
                    # consider implementing sentence update/delete logic
                    await SentenceService.create_sentences_for_audition(
                        audition['id'],  # Use INT id for foreign key
                        event_data.get('sentences', [])
                    )
            
        elif routing_key == AUDITION_SUBMITTED_ROUTING_KEY:
            evaluation_id = await EvaluationService.create_evaluation_for_submission(event_data, pipeline,rabbitmq_manager)
            if evaluation_id:
                logger.info(f"✓ Evaluation queued for processing: {evaluation_id}")
            
        else:
            logger.warning(f"Unknown audition event routing key: {routing_key}")
            
    except Exception as e:
        logger.error(f"✗ Error handling audition event ({routing_key}): {str(e)}")
 