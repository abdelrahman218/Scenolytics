# API Gateway Configuration

The API Gateway is a single entry point for all client requests. It routes requests to the appropriate microservices based on the API path.

## Running the Gateway

The gateway runs in the docker-compose setup automatically. Access it at: `http://localhost:80`

## API Routes

### Authentication Service (Port 5000)
- `POST /api/v1/auth/register` - User registration
- `POST /api/v1/auth/login` - User login
- `POST /api/v1/auth/logout` - User logout
- `GET /api/v1/auth/verify-token` - Verify JWT token
- `GET /api/v1/users/profile` - Get user profile

### Audition Management Service (Port 5001)
- `POST /api/v1/auditions` - Create audition
- `GET /api/v1/auditions/:id` - Get audition details
- `PUT /api/v1/auditions/:id` - Update audition
- `DELETE /api/v1/auditions/:id` - Delete audition
- `GET /api/v1/auditions?filters=...` - Search auditions
- `GET /api/v1/portfolios/:actorId` - Get actor portfolio

### Video Processing Service (Port 5002)
- `POST /api/v1/videos/upload` - Upload video
- `GET /api/v1/videos/:id/status` - Check processing status
- `GET /api/v1/videos/:id/thumbnail` - Get thumbnail
- `DELETE /api/v1/videos/:id` - Delete video

### AI Evaluation Service (Port 5003)
- `POST /api/v1/evaluate/video/:auditionId` - Trigger evaluation
- `GET /api/v1/evaluate/results/:auditionId` - Get evaluation results
- `GET /api/v1/evaluate/status/:auditionId` - Check evaluation progress

### Casting Management Service (Port 5004)
- `POST /api/v1/casting-calls` - Create casting call
- `GET /api/v1/casting-calls` - List all casting calls
- `GET /api/v1/casting-calls/:id` - Get casting call details
- `POST /api/v1/callbacks` - Send callback request
- `POST /api/v1/decisions` - Record casting decision

### Notification Service (Port 5005)
- `GET /api/v1/notifications/user/:userId` - Get user notifications
- `PUT /api/v1/notifications/:id/read` - Mark notification as read
- `GET /api/v1/notifications/preferences/:userId` - Get notification preferences

### Search & Recommendation Service (Port 5006)
- `GET /api/v1/search/actors?q=...` - Search actors
- `GET /api/v1/search/casting-calls?q=...` - Search casting calls
- `GET /api/v1/recommendations/actors?castingCallId=...` - Get actor recommendations
- `GET /api/v1/trending` - Get trending entities

## Health Check

- `GET /health` - Returns "OK" if gateway is running
