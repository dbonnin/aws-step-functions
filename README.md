# AWS Workflow Orchestrator with Step Functions

This Terraform project sets up a complete workflow orchestration system using AWS Step Functions, ECS, API Gateway, and Lambda.

## Architecture

- **ECS Cluster**: Runs three microservices as Fargate tasks
- **Application Load Balancer**: Routes traffic to ECS services
- **API Gateway**: Provides HTTP endpoints for each service
- **Step Functions**: Orchestrates the workflow across all three services
- **Lambda**: Triggers the Step Functions workflow
- **SSM Parameter Store**: Stores Docker Hub credentials securely

## Workflow Flow

1. Lambda function receives a request
2. Lambda starts Step Functions execution
3. Step Functions calls Service 1 via API Gateway
4. Step Functions calls Service 2 with Service 1's response
5. Step Functions calls Service 3 with previous responses
6. Returns final payload with timestamps and metadata for each service

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- Node.js and npm (for building Lambda function)
- Docker images published to Docker Hub for your three services

## Project Structure

```
.
├── main.tf                          # Main Terraform configuration
├── variables.tf                     # Input variables
├── outputs.tf                       # Output values
├── terraform.tfvars.example         # Example variables file
├── step-function-definition.json    # Step Functions state machine
├── modules/
│   └── ecs-service/                # ECS service module
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── lambda/                          # Lambda function code
    ├── index.ts
    ├── package.json
    └── tsconfig.json
```

## Setup Instructions

### 1. Configure Variables

Copy the example variables file and fill in your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your actual values:

- Docker Hub credentials
- Docker image URLs for your three services
- AWS region
- Project name

### 2. Build Lambda Function

```bash
cd lambda
npm install
npm run build
cd ..
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Review the Plan

```bash
terraform plan
```

### 5. Apply the Configuration

```bash
terraform apply
```

Review the changes and type `yes` to proceed.

## Expected Output Payload

The workflow produces this JSON structure:

```json
{
  "start": "2025-10-19T10:00:00.000Z",
  "end": "2025-10-19T10:00:05.000Z",
  "service1": {
    "start": "2025-10-19T10:00:01.000Z",
    "end": "2025-10-19T10:00:02.000Z",
    "serviceIp": "Retrieved from ECS",
    "statusCode": 200,
    "response": {...}
  },
  "service2": {
    "start": "2025-10-19T10:00:02.500Z",
    "end": "2025-10-19T10:00:03.500Z",
    "serviceIp": "Retrieved from ECS",
    "statusCode": 200,
    "response": {...}
  },
  "service3": {
    "start": "2025-10-19T10:00:04.000Z",
    "end": "2025-10-19T10:00:05.000Z",
    "serviceIp": "Retrieved from ECS",
    "statusCode": 200,
    "response": {...}
  },
  "status": "completed"
}
```

## Usage

### Invoke the Workflow via Lambda

Using AWS CLI:

```bash
aws lambda invoke \
  --function-name workflow-orchestrator-workflow-invoker \
  --payload '{"data": "your input data"}' \
  response.json

cat response.json
```

### Direct Step Functions Execution

```bash
aws stepfunctions start-execution \
  --state-machine-arn <STATE_MACHINE_ARN> \
  --input '{"data": "your input data"}'
```

### Call Services Directly via API Gateway

```bash
# Get the API Gateway URL
API_URL=$(terraform output -raw api_gateway_url)

# Call Service 1
curl -X POST $API_URL/service1/process \
  -H "Content-Type: application/json" \
  -d '{"data": "test"}'

# Call Service 2
curl -X POST $API_URL/service2/process \
  -H "Content-Type: application/json" \
  -d '{"data": "test"}'

# Call Service 3
curl -X POST $API_URL/service3/process \
  -H "Content-Type: application/json" \
  -d '{"data": "test"}'
```

## Monitoring

### View Step Functions Execution

1. Go to AWS Console → Step Functions
2. Click on your state machine
3. View execution history and details

### View ECS Service Logs

```bash
aws logs tail /ecs/workflow-orchestrator --follow
```

### View Lambda Logs

```bash
aws logs tail /aws/lambda/workflow-orchestrator-workflow-invoker --follow
```

## Service Requirements

Each Docker service should:

1. **Listen on the configured port** (default: 3000)
2. **Expose a `/health` endpoint** for health checks
3. **Expose a `/process` endpoint** for processing requests
4. **Return JSON responses**

### Example Node.js/TypeScript Service

```typescript
import express from "express";

const app = express();
app.use(express.json());

app.get("/health", (req, res) => {
  res.json({ status: "healthy" });
});

app.post("/process", (req, res) => {
  const data = req.body;
  // Process the data
  res.json({
    processed: true,
    input: data,
    timestamp: new Date().toISOString(),
  });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Service listening on port ${PORT}`);
});
```

## Error Handling

The Step Functions workflow includes:

- **Automatic retries** for 5xx errors (3 attempts with exponential backoff)
- **Catch blocks** to handle failures gracefully
- **Failure states** that capture error details

## Cost Optimization

- ECS tasks use Fargate Spot for lower costs (optional)
- Single NAT Gateway reduces networking costs
- CloudWatch log retention set to 7 days

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

⚠️ **Warning**: This will delete all resources including logs and data.

## Troubleshooting

### ECS Tasks Not Starting

- Check Docker Hub credentials in SSM Parameter Store
- Verify Docker images exist and are accessible
- Check ECS task execution role permissions

### API Gateway 502 Errors

- Verify ECS services are running and healthy
- Check target group health checks
- Ensure services respond on the correct port

### Step Functions Failures

- View execution details in AWS Console
- Check CloudWatch Logs for detailed error messages
- Verify API Gateway endpoints are accessible

## Security Considerations

- Docker Hub credentials stored in SSM Parameter Store (encrypted)
- ECS tasks run in private subnets
- Security groups restrict traffic appropriately
- IAM roles follow least privilege principle

## Customization

### Adjust Task Resources

In `main.tf`, modify the module calls:

```hcl
module "service1" {
  ...
  cpu    = "512"   # Increase CPU
  memory = "1024"  # Increase memory
}
```

### Add More Services

1. Add a new module call in `main.tf`
2. Add API Gateway integration
3. Update Step Functions definition to include new service

### Change Retry Policy

Edit `step-function-definition.json` Retry blocks:

```json
"Retry": [{
  "ErrorEquals": ["States.Http.StatusCode.5xx"],
  "IntervalSeconds": 5,
  "MaxAttempts": 5,
  "BackoffRate": 3
}]
```

## License

MIT
