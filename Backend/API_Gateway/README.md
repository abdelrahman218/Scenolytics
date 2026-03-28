# API Gateway - Scenolytics

The API Gateway is the single entry point for all client requests. It routes requests to appropriate microservices based on the API path using NGINX reverse proxy.

## Gateway Access

- **URL:** `http://localhost`
- **Port:** 80
- **Health Check:** `GET /health` → Returns "OK" if gateway is running

## Starting the Gateway

The gateway runs automatically as part of the docker-compose setup:

```bash
cd Backend
docker-compose up -d
```

All 8 microservices and infrastructure components will start together.

## Architecture

The gateway routes all `/api/v1/*` requests to the appropriate service:

```
Client → API Gateway (Port 80) → Microservices (Ports 5000-5009)
```

## API Routes

### Identity Provider Service (Port 5000)
Authentication and user identity management.

- `POST /api/v1/auth/register` - User registration
- `POST /api/v1/auth/login` - User login
- `POST /api/v1/auth/logout` - User logout
- `GET /api/v1/auth/validate/:user_id` - Validate user exists

### Audition Training Service (Port 5001)
Audition submission and training management for acting auditions.

- `POST /api/v1/auditions` - Submit audition
- `GET /api/v1/auditions/:id` - Get audition details
- `PUT /api/v1/auditions/:id` - Update audition
- `DELETE /api/v1/auditions/:id` - Delete audition
- `GET /api/v1/auditions` - List auditions with filters
- `GET /api/v1/portfolios/:actorId` - Get actor portfolio

### Video Processing Service (Port 5002)
Video upload, storage, and processing.

- `POST /api/v1/videos/upload` - Upload video
- `GET /api/v1/videos/:id` - Get video details
- `GET /api/v1/videos/:id/status` - Check processing status
- `GET /api/v1/videos/:id/thumbnail` - Get video thumbnail
- `DELETE /api/v1/videos/:id` - Delete video

### AI Evaluation Service (Port 5003)
Machine learning evaluation and emotion recognition on audition videos.

- `POST /api/v1/evaluate/video/:auditionId` - Trigger video evaluation
- `GET /api/v1/evaluate/results/:auditionId` - Get evaluation results
- `GET /api/v1/evaluate/status/:auditionId` - Check evaluation progress

### Casting Management Service (Port 5004)
Casting calls, callbacks, and casting decisions.

- `POST /api/v1/casting-calls` - Create casting call
- `GET /api/v1/casting-calls` - List all casting calls
- `GET /api/v1/casting-calls/:id` - Get casting call details
- `POST /api/v1/callbacks` - Send callback to actor
- `GET /api/v1/callbacks/:id` - Get callback details
- `POST /api/v1/decisions` - Record casting decision

### Notification Service (Port 5005)
Email, push, and in-app notifications.

- `POST /api/v1/notifications` - Send notification
- `GET /api/v1/notifications/user/:userId` - Get user notifications
- `PUT /api/v1/notifications/:id/read` - Mark notification as read
- `GET /api/v1/notifications/preferences/:userId` - Get notification preferences
- `PUT /api/v1/notifications/preferences/:userId` - Update notification preferences

### User Management Service (Port 5009)
Actor and director profiles, account management.

- `GET /api/v1/users/:userId/profile` - Get user profile
- `PUT /api/v1/users/:userId/profile` - Update user profile
- `GET /api/v1/users/:userId/portfolios` - Get user portfolios
- `POST /api/v1/users/:userId/portfolios` - Create portfolio

## Microservices Status

All services are containerized and managed by Docker Compose. Run the command below to check status:

```bash
docker-compose ps
```

Expected services:
- ✅ api-gateway (NGINX)
- ✅ identity-provider-service
- ✅ audition-training-service
- ✅ video-processing-service
- ✅ ai-evaluation-service
- ✅ casting-management-service
- ✅ notification-service
- ✅ user-management-service

Plus infrastructure services:
- ✅ MySQL databases (6 instances)
- ✅ RabbitMQ (message broker)
- ✅ Redis (cache/job queue)

## Configuration

The gateway configuration is defined in `nginx.conf` which includes:
- Upstream service definitions
- Route mappings
- Proxy settings
- CORS headers (if applicable)
- Health check endpoint

## Testing the Gateway

**Via API Gateway (recommended for production):**
```bash
# Health check
curl http://localhost/health

# Authentication
curl -X POST http://localhost/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password"}'
```

**Direct to Services (for testing):**
```bash
# Identity Provider (Port 5000)
curl -X POST http://localhost:5000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password"}'

# Casting Management Service (Port 5004)
curl -X POST http://localhost:5004/callbacks \
  -H "Content-Type: application/json" \
  -d '{"actor_id":"actor123","director_id":"dir456","audition_id":"aud789"}'

# Notification Service (Port 5005)
curl -X GET http://localhost:5005/notifications/user/user123

# User Management Service (Port 5009)
curl -X GET http://localhost:5009/users/user123/profile
```

## Logs

View gateway logs:
```bash
docker-compose logs api-gateway -f
```

View all service logs:
```bash
docker-compose logs -f
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Gateway not responding | Check if docker containers are running: `docker-compose ps` |
| 502 Bad Gateway | Check if upstream services are running and healthy |
| CORS errors | Verify nginx.conf has proper headers configured |
| Service unreachable | Check port mappings and service names in docker-compose.yml |

## Environment Variables

Port configuration is managed through `.env` file:

```
IDENTITY_PROVIDER_SERVICE_PORT=5000
AUDITION_TRAINING_SERVICE_PORT=5001
VIDEO_PROCESSING_SERVICE_PORT=5002
AI_EVALUATION_SERVICE_PORT=5003
CASTING_MANAGEMENT_SERVICE_PORT=5004
NOTIFICATION_SERVICE_PORT=5005
USER_MANAGEMENT_SERVICE_PORT=5009
```

## Related Documentation

- See `docker-compose.yml` for complete infrastructure setup
- See `nginx.conf` for detailed route configuration
- See individual service README files in their respective directories
