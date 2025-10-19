import express, { Request, Response } from 'express';
import os from 'os';

const app = express();
const PORT = process.env.PORT || 3000;
const SERVICE_NAME = process.env.SERVICE_NAME || 'unknown-service';

// Middleware
app.use(express.json());

// Request logging middleware
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

// Health check endpoint (required by ALB)
app.get('/health', (req: Request, res: Response) => {
  res.json({
    status: 'healthy',
    service: SERVICE_NAME,
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    hostname: os.hostname()
  });
});

// Main processing endpoint
app.post('/process', async (req: Request, res: Response) => {
  try {
    const startTime = new Date().toISOString();
    const inputData = req.body;

    console.log('Processing request:', JSON.stringify(inputData, null, 2));

    // Simulate some processing time (100-500ms)
    await new Promise(resolve => setTimeout(resolve, Math.random() * 400 + 100));

    // Get the container's IP address
    const networkInterfaces = os.networkInterfaces();
    let serviceIp = 'unknown';
    
    for (const [name, nets] of Object.entries(networkInterfaces)) {
      if (nets) {
        for (const net of nets) {
          // Skip internal and non-IPv4 addresses
          if (net.family === 'IPv4' && !net.internal) {
            serviceIp = net.address;
            break;
          }
        }
      }
      if (serviceIp !== 'unknown') break;
    }

    const endTime = new Date().toISOString();

    // Construct response
    const response = {
      service: SERVICE_NAME,
      processed: true,
      timestamp: {
        start: startTime,
        end: endTime
      },
      serviceIp,
      hostname: os.hostname(),
      input: inputData,
      result: {
        message: `Data processed successfully by ${SERVICE_NAME}`,
        itemCount: Array.isArray(inputData) ? inputData.length : 
                   typeof inputData === 'object' ? Object.keys(inputData).length : 1,
        processingTimeMs: new Date(endTime).getTime() - new Date(startTime).getTime()
      }
    };

    console.log('Response:', JSON.stringify(response, null, 2));

    res.json(response);
  } catch (error) {
    console.error('Error processing request:', error);
    res.status(500).json({
      error: 'Processing failed',
      service: SERVICE_NAME,
      message: error instanceof Error ? error.message : 'Unknown error',
      timestamp: new Date().toISOString()
    });
  }
});

// Catch-all for undefined routes
app.use((req: Request, res: Response) => {
  res.status(404).json({
    error: 'Not Found',
    path: req.path,
    service: SERVICE_NAME
  });
});

// Error handler
app.use((err: Error, req: Request, res: Response, next: Function) => {
  console.error('Unhandled error:', err);
  res.status(500).json({
    error: 'Internal Server Error',
    message: err.message,
    service: SERVICE_NAME
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`${SERVICE_NAME} listening on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Hostname: ${os.hostname()}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully...');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully...');
  process.exit(0);
});