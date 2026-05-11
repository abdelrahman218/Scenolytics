# Scenolytics Backend Infrastructure

This repository contains the backend infrastructure for the **Scenolytics** platform. The backend is built using a modern microservices architecture, orchestrated via Docker Compose, to ensure high scalability, loose coupling, and robust performance.

---

## 🏛️ Architecture Overview

The system is designed as a set of distributed microservices communicating asynchronously and synchronously:
- **API Gateway (NGINX)**: Acts as the single entry point (Port `80`) for all client-side requests, routing traffic to the internal microservices.
- **Message Broker (RabbitMQ)**: Facilitates asynchronous event-driven communication between services.
- **Database per Service**: Following the microservices design pattern, each specific service runs its independent MySQL 8.0 instance to maintain data encapsulation.
- **Object Storage (MinIO)**: Used for robust video and results storage locally (S3-compatible).

---

## 📦 Service Descriptions

| Service | Port | Description |
|---|---|---|
| **API Gateway** | `80` | Routes external HTTP requests to internal microservices via `/api/v1/*`. |
| **Identity Provider Service** | `5000-5002` | Manages user identities, authentication (JWT), login, and registration. |
| **User Management Service** | `5003-5005` | Manages expanded user profiles for actors and directors. |
| **Audition Training Service** | `5006-5008` | Handles audition submissions, records, training sessions, and actor portfolios. |
| **AI Evaluation Service** | `5012-5014` | Core ML hub that processes video streams for emotion recognition and performance scoring. |
| **Casting Management Service** | `5015-5017` | Handles casting calls, callback events, and casting decisions by directors. |
| **Notification Service** | `5018` | Routes notifications via Email (SMTP) and in-app websockets. |

---

## 🔌 All API Endpoints

Below is a comprehensive list of all implemented API endpoints grouped by their respective microservices. Note that the API Gateway prefixes `http://localhost:80/` to all routes.

### 1. Identity Provider Service
**Base Route:** `/api/v1/auth`
- `POST /api/v1/auth/signup` - Register a new user
- `POST /api/v1/auth/login` - Authenticate users and retrieve JWT
- `GET /api/v1/auth/validate/:user_id` - Verify user existence
- `DELETE /api/v1/auth/delete` - Remove user credentials

### 2. User Management Service
**Base Routes:** `/api/v1/actors`, `/api/v1/directors`, `/api/v1/profiles`
- `POST /api/v1/actors/profile` - Create an actor profile
- `GET /api/v1/actors/:user_id/profile` - Retrieve actor details
- `PATCH /api/v1/actors/profile/:profile_id` - Update actor profile
- `DELETE /api/v1/actors/profile/:profile_id` - Remove actor profile
- `POST /api/v1/actors/search` - Look up actors by criteria
- `POST /api/v1/directors/profile` - Create a director profile
- `GET /api/v1/directors/:user_id/profile` - Retrieve director details
- `PATCH /api/v1/directors/profile/:profile_id` - Update director profile
- `DELETE /api/v1/directors/profile/:profile_id` - Remove director profile

### 3. Audition Training Service
**Base Route:** `/api/v1/sessions`
- `POST /api/v1/sessions` - Launch a new training session
- `GET /api/v1/sessions/:session_id` - Retrieve training session details
- `GET /api/v1/sessions/:actor_id/sessions` - View all sessions for a specific actor
- `PATCH /api/v1/sessions/:session_id/end` - Conclude an active training session
- `POST /api/v1/sessions/:session_id/feedback` - Submit coach/peer feedback
- `GET /api/v1/sessions/:session_id/feedback` - Read session feedback
- `POST /api/v1/sessions/:session_id/recommendations` - Record system action recommendations
- `GET /api/v1/sessions/:session_id/recommendations` - Read recorded recommendations

### 4. AI Evaluation Service
**Base Route:** `/api/v1/evaluations`
- `POST /api/v1/evaluations` - Submit an audition/session for automatic ML evaluation
- `GET /api/v1/evaluations/:evaluation_id` - Retrieve processing results
- `PATCH /api/v1/evaluations/:evaluation_id/scores` - Calibrate/update generated scores
- `PATCH /api/v1/evaluations/:evaluation_id/feedback` - Append AI actionable feedback
- `GET /api/v1/evaluations/queue/pending` - Check pending evaluation models tasks
- `PATCH /api/v1/evaluations/:evaluation_id/error` - Flag an evaluation error process

### 5. Casting Management Service
**Base Route:** `/api/v1/casting`
- `GET /api/v1/casting/auditions/:audition_id` - Get public/general view of an audition
- `POST /api/v1/casting/director/auditions` - Director posts a casting call/audition opportunity
- `GET /api/v1/casting/director/auditions` - Directors review all their managed auditions
- `PATCH /api/v1/casting/director/auditions/:audition_id` - Director updates casting call info
- `DELETE /api/v1/casting/director/auditions/:audition_id` - Director deletes casting call
- `POST /api/v1/casting/director/auditions/:audition_id/invite_actors` - Send mass/direct invites
- `GET /api/v1/casting/director/auditions/:audition_id/actors` - Fetch linked/invited actors
- `GET /api/v1/casting/director/auditions/:audition_id/submissions` - Retrieve actor tape submissions
- `GET /api/v1/casting/director/invitations/pending` - Fetch unread invitations to review later
- `PATCH /api/v1/casting/director/invitations/:invitation_id` - Confirm/Alter invitation tracking link
- `PATCH /api/v1/casting/actor/invitations/:invitation_id` - Actor accepts or declines a casting invite
- `GET /api/v1/casting/actor/invitations` - Check all active opportunities an actor was invited for
- `GET /api/v1/casting/actor/auditions/submissions` - Actor reviews personal submitted tapes
- `POST /api/v1/casting/actor/auditions/:audition_id/submit` - Actor uploads video specifically against a call
- `GET /api/v1/casting/actor/auditions/:audition_id/script` - Get audition script as PDF
- `GET /api/v1/casting/actor/auditions/` - Get all auditions

### 6. Notification Service
**Base Route:** `/api/v1/notifications`
- `GET /api/v1/notifications/preferences` - User fetches their email/in-app notification toggles
- `PATCH /api/v1/notifications/preferences` - Update user notification toggles
- `GET /api/v1/notifications/` - Fetch all personal notifications
- `PATCH /api/v1/notifications/:notification_id/read` - Marks notification as read
- `DELETE /api/v1/notifications/:notification_id` - Delete notification


## 🛠️ Local Development Setup

To run the entire Scenolytics backend locally, you will need **Docker** and **Docker Compose** installed.

### 1. Environment Variables
Ensure you have a root `.env` file situated in the `Backend` directory containing necessary secrets, database credentials, and port allocations. (An example `.env.example` should typically be duplicated into `.env`).

### 2. Build and Startup
Navigate to the `Backend` directory and start the orchestration stack:

```bash
cd Backend
docker-compose up -d --build
```
*Note: The `--build` flag is crucial the first time or if you've made code changes locally.*

### 3. Verify Health
All services should now be running. You can verify their status by executing:
```bash
docker-compose ps
```
Or check the API gateway health endpoint:
```bash
curl http://localhost/health
```

### 4. Viewing Logs
To track logs across all microservices (useful for debugging asynchronous RabbitMQ events):
```bash
docker-compose logs -f
```
Or view logs for a specific service (e.g. Identity Provider):
```bash
docker-compose logs -f identity-provider-service
```

### 5. Stopping the Platform
To safely shut down the containers while preserving data within your volumes:
```bash
docker-compose stop
```
If you wish to tear down everything including the networks:
```bash
docker-compose down
```
*(Warning: Adding `-v` will delete the persistent database volumes!)*
