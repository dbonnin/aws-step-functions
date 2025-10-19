# Example Service

This is a template Node.js/TypeScript service that can be used as a starting point for your three ECS services.

## Features

- Express.js HTTP server
- TypeScript support
- Health check endpoint (`/health`)
- Processing endpoint (`/process`)
- Automatic IP address detection
- Request logging
- Graceful shutdown
- Docker support with multi-stage builds

## Local Development

### Install Dependencies

```bash
npm install
```

### Run in Development Mode

```bash
# Run with default service name
npm run dev

# Or specify a service name
SERVICE_NAME=service1 npm run dev
SERVICE_NAME=service2 npm run dev
SERVICE_NAME=service3 npm run dev
```

The service will start on port 3000.

### Test the Service Locally

```bash
# In one terminal - start the service
SERVICE_NAME=service1 npm run dev

# In another terminal - run tests
npm test
```

The test will simulate the complete Step Functions workflow:

1. Call the service as service1 (first in chain)
2. Call the service as service2 (middle in chain)
3. Call the service as service3 (final in chain)
4. Validate the payload structure matches your requirements

### Build TypeScript

```bash
npm run build
```

### Run Production Build

```bash
npm start
```

## API Endpoints

### Health Check

```bash
curl http://localhost:3000/health
```

Response:

```json
{
  "status": "healthy",
  "service": "service1",
  "timestamp": "2025-10-19T10:00:00.000Z",
  "uptime": 123.45,
  "hostname": "container-id"
}
```

### Process Data

```bash
curl -X POST http://localhost:3000/process \
  -H "Content-Type: application/json" \
  -d '{"data": "test"}'
```

Response:

```json
{
  "service": "service1",
  "processed": true,
  "timestamp": {
    "start": "2025-10-19T10:00:00.000Z",
    "end": "2025-10-19T10:00:00.250Z"
  },
  "serviceIp": "10.0.1.123",
  "hostname": "container-id",
  "input": { "data": "test" },
  "result": {
    "message": "Data processed successfully by service1",
    "itemCount": 1,
    "processingTimeMs": 250
  }
}
```

## Docker

### Build Image

```bash
docker build -t your-username/service1:latest .
```

### Run Locally

```bash
docker run -p 3000:3000 \
  -e SERVICE_NAME=service1 \
  your-username/service1:latest
```

### Push to Docker Hub

```bash
# Login to Docker Hub
docker login

# Tag the image
docker tag your-username/service1:latest your-username/service1:v1.0.0

# Push to Docker Hub
docker push your-username/service1:latest
docker push your-username/service1:v1.0.0
```

## Creating Multiple Services

To create service2 and service3:

1. Copy this directory three times:

   ```bash
   cp -r example-service service1
   cp -r example-service service2
   cp -r example-service service3
   ```

2. Build and push each service:

   ```bash
   # Service 1
   cd service1
   docker build -t your-username/service1:latest .
   docker push your-username/service1:latest

   # Service 2
   cd ../service2
   docker build -t your-username/service2:latest .
   docker push your-username/service2:latest

   # Service 3
   cd ../service3
   docker build -t your-username/service3:latest .
   docker push your-username/service3:latest
   ```

3. Update `terraform.tfvars` with your image URLs

## Customization

### Change Port

Update the `PORT` environment variable:

```typescript
const PORT = process.env.PORT || 3000;
```

And in the Dockerfile:

```dockerfile
ENV PORT=3000
EXPOSE 3000
```

### Add Business Logic

Modify the `/process` endpoint in `index.ts`:

```typescript
app.post("/process", async (req: Request, res: Response) => {
  const inputData = req.body;

  // Add your custom processing logic here
  const processedData = await yourCustomFunction(inputData);

  res.json({
    processed: true,
    result: processedData,
  });
});
```

### Add Database Connection

Install your database client:

```bash
npm install pg  # PostgreSQL
# or
npm install mysql2  # MySQL
# or
npm install mongodb  # MongoDB
```

Add connection logic:

```typescript
import { Pool } from "pg";

const pool = new Pool({
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});
```

## Environment Variables

- `PORT`: Server port (default: 3000)
- `SERVICE_NAME`: Name of the service (default: "unknown-service")
- `NODE_ENV`: Environment (development/production)

## Testing

Test the service with curl:

```bash
# Health check
curl http://localhost:3000/health

# Process data
curl -X POST http://localhost:3000/process \
  -H "Content-Type: application/json" \
  -d '{
    "userId": 123,
    "action": "process",
    "data": {"key": "value"}
  }'
```

## Troubleshooting

### Container Exits Immediately

Check logs:

```bash
docker logs <container-id>
```

### Port Already in Use

Change the port:

```bash
docker run -p 3001:3000 your-username/service1:latest
```

### Build Fails

Clear Docker cache:

```bash
docker build --no-cache -t your-username/service1:latest .
```

## Production Considerations

1. **Environment Variables**: Use AWS Secrets Manager or Parameter Store for sensitive data
2. **Logging**: Consider using structured logging (e.g., Winston, Pino)
3. **Monitoring**: Add metrics collection (e.g., Prometheus, CloudWatch)
4. **Error Handling**: Implement comprehensive error handling
5. **Rate Limiting**: Add rate limiting for production use
6. **Authentication**: Implement authentication if needed

## License

MIT
