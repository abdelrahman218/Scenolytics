"""
Evaluation API routes for AI Evaluation Service (FastAPI)

Endpoints for managing audition video evaluations with 4 metrics:
  - emotional_expression_score (40%): Video emotion detection
  - vocal_tone_score (35%): Audio quality and tone
  - script_alignment_score (25%): Script adherence
  - overall_performance_score: Calculated weighted average
"""

import logging
import uuid
import json
import random
from datetime import datetime
from typing import Optional, Dict, Any, List
import os
import tempfile
from core.storage import get_s3_client
from core.rabbitmq_manager import RabbitMQManager
from fastapi import APIRouter, HTTPException, BackgroundTasks, Request
from pydantic import BaseModel, Field

logger = logging.getLogger(__name__)
router = APIRouter(prefix='/api/evaluations', tags=['evaluations'])


# ==================== Request Models ====================

from pydantic import BaseModel, Field, field_validator

class CreateEvaluationRequest(BaseModel):
    """Request model for creating a new evaluation"""
    media_id: str = Field(..., description="Video media identifier")
    submission_id: Optional[str] = Field(None, description="Audition submission ID")
    audio_only: bool = Field(False, description="Run audio-only evaluation (no video model)")
    script_text: Optional[str] = Field(
        None,
        description=(
            "Expected script for alignment and emotion scoring. "
            "Send as a JSON-encoded string or a raw JSON array: "
            '[{"content": "sentence text", "emotion": "angry"}, ...]'
        ),
    )

    @field_validator("script_text", mode="before")
    @classmethod
    def coerce_script_text(cls, v):
        if isinstance(v, list):
            return json.dumps(v)
        return v

    class Config:
        json_schema_extra = {
            "example": {
                "media_id": "video-actor-001",
                "submission_id": "submission-audition-001",
                "script_text": '[{"content": "i don\'t understand my feelings", "emotion": "angry"}, {"content": "how no matter how much i\'d like not to hate you", "emotion": "fearful"}]'
            }
        }

# ==================== Pydantic Models ====================

class DetectedEmotions(BaseModel):
    """Detected emotions from analysis"""
    primary: str
    secondary: str
    confidence: float = Field(ge=0.0, le=1.0)
    timestamp: Optional[str] = None


class EvaluationResponse(BaseModel):
    """Complete evaluation response"""
    id: str
    media_id: str
    submission_id: Optional[str]
    emotional_expression_score: Optional[float]
    vocal_tone_score: Optional[float]
    script_alignment_score: Optional[float]
    overall_performance_score: Optional[float]
    eye_expression_score: Optional[Dict[str, Any]]
    tone_analysis: Optional[Dict[str, Any]]
    detected_emotions: Optional[Dict[str, Any]]
    detected_emotions_vocal: Optional[Dict[str, Any]]
    detected_emotions_video: Optional[Dict[str, Any]]
    script_alignment_details: Optional[Dict[str, Any]]
    ai_feedback: Optional[str]
    evaluation_status: str
    error_message: Optional[str]
    created_at: str
    completed_at: Optional[str]

    class Config:
        json_schema_extra = {
            "example": {
                "id": "550e8400-e29b-41d4-a716-446655440000",
                "media_id": "video-001",
                "submission_id": "submission-001",
                "emotional_expression_score": 85.5,
                "vocal_tone_score": 78.25,
                "script_alignment_score": 92.0,
                "overall_performance_score": 83.58,
                "detected_emotions": {
                    "primary": "happy",
                    "secondary": "neutral",
                    "confidence": 0.92
                },
                "detected_emotions_vocal": {
                    "primary": "happy",
                    "confidence": 0.88,
                    "all_emotions": {
                        "happy": 0.88,
                        "neutral": 0.07,
                        "sad": 0.05
                    }
                },
                "detected_emotions_video": {
                    "primary": "happy",
                    "confidence": 0.85,
                    "score": 85.0,
                    "accuracy": 0.9,
                    "sentence_results": [
                        {
                            "sentence": "What did you do yesterday?",
                            "expected_emotion": "curious",
                            "detected_emotion": "curious",
                            "confidence": 0.92,
                            "score": 92.0,
                            "time_range": "5.2s-7.5s",
                            "status": "ok"
                        }
                    ]
                },
                "eye_expression_score": 88.0,
                "ai_feedback": "Excellent performance!",
                "evaluation_status": "completed",
                "error_message": None,
                "created_at": "2026-04-13T10:30:00",
                "completed_at": "2026-04-13T10:31:45"
            }
        }


# ==================== Helper ====================

def _row_to_response(row: dict) -> EvaluationResponse:
    """Convert a DB row dict to EvaluationResponse. Centralises the mapping
    so it doesn't have to be copy-pasted across every endpoint."""
    detected_emotions = None
    if row.get("detected_emotions"):
        try:
            detected_emotions = (
                json.loads(row["detected_emotions"])
                if isinstance(row["detected_emotions"], str)
                else row["detected_emotions"]
            )
        except Exception:
            detected_emotions = None
    
    detected_emotions_vocal = None
    if row.get("detected_emotions_vocal"):
        try:
            detected_emotions_vocal = (
                json.loads(row["detected_emotions_vocal"])
                if isinstance(row["detected_emotions_vocal"], str)
                else row["detected_emotions_vocal"]
            )
        except Exception:
            detected_emotions_vocal = None
    detected_emotions_video = None
    if row.get("detected_emotions_video"):
        try:
            detected_emotions_video = (
                json.loads(row["detected_emotions_video"])
                if isinstance(row["detected_emotions_video"], str)
                else row["detected_emotions_video"]
            )
        except Exception:
            detected_emotions_video = None
    script_alignment_details = None
    if row.get("script_alignment_details"):
        try:
            script_alignment_details = (
                json.loads(row["script_alignment_details"])
                if isinstance(row["script_alignment_details"], str)
                else row["script_alignment_details"]
            )
        except Exception:
            script_alignment_details = None

    def _iso(val):
        if val is None:
            return None
        return val.isoformat() if hasattr(val, "isoformat") else str(val)

    return EvaluationResponse(
        id=row["evaluation_id"],
        media_id=row["media_id"],
        submission_id=row.get("submission_id"),
        emotional_expression_score=float(row["emotional_expression_score"]) if row.get("emotional_expression_score") is not None else None,
        vocal_tone_score=float(row["vocal_tone_score"]) if row.get("vocal_tone_score") is not None else None,
        script_alignment_score=float(row["script_alignment_score"]) if row.get("script_alignment_score") is not None else None,
        overall_performance_score=float(row["overall_performance_score"]) if row.get("overall_performance_score") is not None else None,
        tone_analysis=(
            json.loads(row["tone_analysis"])            if isinstance(row["tone_analysis"], str) 
            else row["tone_analysis"]
        ) if row.get("tone_analysis") is not None else None,
        detected_emotions=detected_emotions,
        detected_emotions_vocal=detected_emotions_vocal,
        detected_emotions_video=detected_emotions_video,
        script_alignment_details=script_alignment_details,
        eye_expression_score=(
            json.loads(row["eye_expression_score"])
            if isinstance(row["eye_expression_score"], str)
            else row["eye_expression_score"]
        ) if row.get("eye_expression_score") is not None else None,
        ai_feedback=row.get("ai_feedback"),
        evaluation_status=row["evaluation_status"],
        error_message=row.get("error_message"),
        created_at=_iso(row["created_at"]),
        completed_at=_iso(row.get("completed_at")),
    )


# ==================== Background ML Pipeline ====================

async def run_ml_pipeline(evaluation_id: str, media_id: str, pipeline, script_text: Optional[str] = None, rabbitmq_manager: Optional[RabbitMQManager] = None, submission_id: Optional[str] = None,audio_only: bool = False,):
    """Runs all 3 ML models and writes scores back to DB.

    Parameters
    ----------
    evaluation_id : UUID of the evaluation row to update
    media_id      : used to locate the video file at VIDEO_STORAGE_PATH/<media_id>.mp4
    pipeline      : MLPipeline instance for running evaluations
    script_text   : optional expected script — passed to WhisperX alignment.
                    If None, script_alignment_score will be 0.
    rabbitmq_manager : RabbitMQManager instance for publishing evaluation completion events
    submission_id : Optional submission ID for tracking audition submissions
    """
    from core.database import Database
    import os
    from pathlib import Path
    
    db = Database()
    video_path = None
    try:
        # Let callers distinguish "queued" from "actively running"
        await db.execute(
            "UPDATE evaluations SET evaluation_status = 'processing' WHERE evaluation_id = %s",
            (evaluation_id,),
        )

        s3 = get_s3_client()
        bucket = os.getenv('S3_BUCKET_VIDEOS', 'videos')
        s3_key = f"uploads/{media_id}.mp4"

        with tempfile.NamedTemporaryFile(suffix='.mp4', delete=False) as tmp:
            video_path = tmp.name

        try:
            s3.download_file(bucket, s3_key, video_path)
        except Exception as e:
            error_msg = f"Failed to download video '{s3_key}' from MinIO bucket '{bucket}': {e}"
            logger.error(error_msg)
            await db.execute(
                "UPDATE evaluations SET evaluation_status = 'failed', error_message = %s WHERE evaluation_id = %s",
                (error_msg, evaluation_id),
            )
            return


        # evaluate_video() returns:
        #   emotional_expression_score, vocal_tone_score, script_alignment_score,
        #   overall_performance_score, detected_emotions (dict), ai_feedback (str)
        scores = await pipeline.evaluate_video(video_path, script_text=script_text,audio_only=audio_only)
        # overall is already calculated inside evaluate_video() using the
        # correct 40/35/25 weights — no need to recalculate here.
        overall = scores["overall_performance_score"]
        eye_expression_score = scores.get("eye_expression")
        if isinstance(eye_expression_score, dict):
            eye_expression_score = json.dumps(eye_expression_score)
        elif eye_expression_score is not None:
            eye_expression_score = json.dumps(eye_expression_score)
        detected_emotions_vocal = scores.get("detected_emotions_vocal")
        if isinstance(tone_result := scores.get("tone_analysis"), dict):
            tone_result = json.dumps(tone_result)
        if isinstance(detected_emotions_vocal, dict):
            detected_emotions_vocal = json.dumps(detected_emotions_vocal)
        detected_emotions_video = scores.get("detected_emotions_video")
        if isinstance(detected_emotions_video, dict):
            detected_emotions_video = json.dumps(detected_emotions_video)      
        script_alignment_details = None
        alignment_data = scores.get("script_alignment_data")  # you need to add this to evaluate_video's return
        if alignment_data:
            script_alignment_details = {
                "transcript":       alignment_data.get("transcript", ""),
                "matched_words":     alignment_data.get("matched_words", []),
                "added_words":       alignment_data.get("added_words", []),
                "changed_words":     alignment_data.get("changed_words", []),
                "skipped_words":     alignment_data.get("skipped_words", []),
                "comparison_rows":  alignment_data.get("comparison_rows", []),
                "coverage":         alignment_data.get("coverage", 0.0),
                "sentences_aligned": alignment_data.get("sentences_aligned", []),
            }
        
        await db.execute(
            """
            UPDATE evaluations
            SET emotional_expression_score = %s,
                vocal_tone_score           = %s,
                script_alignment_score     = %s,
                overall_performance_score  = %s,
                eye_expression_score       = %s,
                tone_analysis              = %s,
                detected_emotions          = %s,
                detected_emotions_vocal    = %s,
                detected_emotions_video    = %s,
                script_alignment_details   = %s,
                ai_feedback                = %s,
                evaluation_status          = 'completed',
                completed_at               = NOW()
            WHERE evaluation_id = %s
            """,
            (
                scores.get("emotional_expression_score"),
                scores["vocal_tone_score"],
                scores["script_alignment_score"],
                overall,
                eye_expression_score,
                tone_result,
                json.dumps(scores.get("detected_emotions")),
                detected_emotions_vocal if detected_emotions_vocal else None,
                detected_emotions_video if detected_emotions_video else None,
                json.dumps(script_alignment_details) if script_alignment_details else None,
                scores.get("ai_feedback"),
                evaluation_id,
            ),
        )
        logger.info(f"ML pipeline completed for evaluation {evaluation_id}")
        
        # Publish evaluation completed event to RabbitMQ
        if rabbitmq_manager:
            logger.info(f"Publishing evaluation completed event for {evaluation_id}...")
            try:
                await rabbitmq_manager.publish_evaluation_completed(
                    evaluation_id=evaluation_id,
                    media_id=media_id,
                    submission_id=submission_id,
                    emotional_expression_score=scores["emotional_expression_score"],
                    vocal_tone_score=scores["vocal_tone_score"],
                    script_alignment_score=scores["script_alignment_score"],
                    overall_performance_score=overall,
                    ai_feedback=scores.get("ai_feedback"),
                    evaluation_status="completed"
                )
            except Exception as e:
                logger.error(f"Failed to publish evaluation completed event: {e}", exc_info=True)
        else:
            logger.warning(f"rabbitmq_manager is None — skipping publish for {evaluation_id}")

    except Exception as e:
        logger.error(f"ML pipeline failed for evaluation {evaluation_id}: {e}", exc_info=True)
        try:
            await db.execute(
                "UPDATE evaluations SET evaluation_status = 'failed', error_message = %s WHERE evaluation_id = %s",
                (str(e), evaluation_id),
            )
        except Exception as db_err:
            logger.error(f"Could not update failure status for {evaluation_id}: {db_err}", exc_info=True)

    finally:
        # Always clean up the temp file regardless of success or failure
        if video_path:
            try:
                os.unlink(video_path)
            except Exception:
                pass
# ==================== Endpoints ====================

@router.post("/", response_model=EvaluationResponse, status_code=201)
async def create_evaluation(request: CreateEvaluationRequest, background_tasks: BackgroundTasks, http_request: Request):
    """
    Create a new evaluation and immediately kick off ML processing.
    """
    try:
        from core.database import Database
        db = Database()

        evaluation_id = str(uuid.uuid4())
        now = datetime.utcnow().isoformat()

        await db.execute(
            """
            INSERT INTO evaluations
                (evaluation_id, media_id, submission_id, evaluation_status, created_at)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (evaluation_id, request.media_id, request.submission_id or None, "pending", now),
        )

        # Pass the pipeline instance directly — avoids any import-time resolution issues
        pipeline = http_request.app.state.ml_pipeline
        background_tasks.add_task(run_ml_pipeline, evaluation_id, request.media_id, pipeline, request.script_text, http_request.app.state.rabbitmq_manager, request.submission_id, request.audio_only)

        logger.info(f"Created evaluation {evaluation_id} and queued ML pipeline")

        return EvaluationResponse(
            id=evaluation_id,
            media_id=request.media_id,
            submission_id=request.submission_id,
            emotional_expression_score=None,
            vocal_tone_score=None,
            script_alignment_score=None,
            overall_performance_score=None,
            eye_expression_score=None,
            tone_analysis=None,
            detected_emotions=None,
            detected_emotions_vocal=None,
            detected_emotions_video=None,
            script_alignment_details=None,
            ai_feedback=None,
            evaluation_status="pending",
            error_message=None,
            created_at=now,
            completed_at=None,
        )

    except Exception as e:
        logger.error(f"Error creating evaluation: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# FIX: /pending must be declared BEFORE /{evaluation_id} or FastAPI will treat
#      the literal string "pending" as an evaluation_id and return a 404.
@router.get("/pending", response_model=List[EvaluationResponse])
async def get_pending_evaluations():
    """
    Get all pending evaluations.

    Returns up to 10 pending evaluations awaiting processing.
    """
    try:
        from core.database import Database
        db = Database()

        results = await db.fetch_all(
            "SELECT * FROM evaluations WHERE evaluation_status = 'pending' LIMIT 10"
        )
        return [_row_to_response(row) for row in results]

    except Exception as e:
        logger.error(f"Error retrieving pending evaluations: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{evaluation_id}", response_model=EvaluationResponse)
async def get_evaluation(evaluation_id: str):
    """
    Retrieve a complete evaluation.

    Returns all metric scores, feedback, and status for the evaluation.
    """
    try:
        from core.database import Database
        db = Database()

        result = await db.fetch_one(
            "SELECT * FROM evaluations WHERE evaluation_id = %s", (evaluation_id,)
        )

        if not result:
            raise HTTPException(status_code=404, detail="Evaluation not found")
        return _row_to_response(result)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error retrieving evaluation {evaluation_id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/{evaluation_id}/process/mock", response_model=EvaluationResponse)
async def process_mock_evaluation(evaluation_id: str):
    """
    Process evaluation with random/mock scores (for testing).

    Generates random scores for all 4 metrics:
      - emotional_expression_score (40%)
      - vocal_tone_score (35%)
      - script_alignment_score (25%)
    Calculates overall_performance_score automatically.
    """
    try:
        from core.database import Database
        db = Database()

        emotional_expression = round(random.uniform(0, 100), 2)
        vocal_tone = round(random.uniform(0, 100), 2)
        script_alignment = round(random.uniform(0, 100), 2)
        overall = round(
            (emotional_expression * 0.40) + (vocal_tone * 0.35) + (script_alignment * 0.25), 2
        )

        if overall >= 80:
            feedback = "Excellent performance! You demonstrated strong emotional expression, clear vocal tone, and excellent script alignment."
        elif overall >= 60:
            feedback = "Good performance. You showed decent emotional range and vocal control. Consider improving your script adherence."
        elif overall >= 40:
            feedback = "Average performance. Work on emotional authenticity and vocal clarity. Studio coaching recommended."
        else:
            feedback = "Needs improvement. Focus on emotional expression, vocal clarity, and script accuracy."

        emotions_list = ["happy", "sad", "neutral", "surprised", "angry", "fearful", "disgusted"]
        detected_emotions = {
            "primary": random.choice(emotions_list),
            "secondary": random.choice(emotions_list),
            "confidence": round(random.uniform(0.5, 1.0), 2),
            "timestamp": datetime.utcnow().isoformat(),
        }

        now = datetime.utcnow().isoformat()
        await db.execute(
            """
            UPDATE evaluations
            SET emotional_expression_score = %s,
                vocal_tone_score           = %s,
                script_alignment_score     = %s,
                overall_performance_score  = %s,
                detected_emotions          = %s,
                eye_expression_score       = %s,
                ai_feedback                = %s,
                evaluation_status          = 'completed',
                completed_at               = %s
            WHERE evaluation_id = %s
            """,
            (
                emotional_expression,
                vocal_tone,
                script_alignment,
                overall,
                json.dumps(detected_emotions),
                feedback,
                now,
                evaluation_id,
            ),
        )

        logger.info(f"Mock evaluation {evaluation_id} processed with overall score {overall}")

        return await get_evaluation(evaluation_id)

    except Exception as e:
        logger.error(f"Error processing mock evaluation {evaluation_id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))