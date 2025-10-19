# Quick Start Guide

Get your workflow orchestration system up and running in 15 minutes.

## Step-by-Step Setup

### 1. Prepare Your Docker Services (5 minutes)

```bash
# Create three services from the example template
cp -r example-service service1
cp -r example-service service2
cp -r example-service service3

# Build and push service1
cd service1
npm install
docker build -t YOUR_DOCKERHUB_USERNAME/service1:latest .
docker push YOUR_DOCKERHUB_USERNAME/service1:latest

# Build and push service2
cd ../service2
docker build -t YOUR_DOCKERHUB_USERNAME/service2:latest .
docker push YOUR_DOCKERHUB_USERNAME/service2:latest

# Build and push service3
cd ../service3
docker build -t YOUR_DOCKERHUB_USERNAME/service3:latest .
docker push YOUR_DOCKERHUB_USERNAME/service3:latest

cd ..
```

### 2. Configure Terraform (2 minutes)

```bash
# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
nano terraform.tfvars
```

Required variables:

```hcl
aws_region         = "us-east-1"
project_name       = "my-workflow"
dockerhub_username = "YOUR_DOCKERHUB_USERNAME"
dockerhub_password = "YOUR_DOCKERHUB_PASSWORD"

service1_docker_image = "YOUR_DOCKERHUB_USERNAME/service1:latest"
service2_docker_image = "YOUR_DOCKERHUB_USERNAME/service2:latest"
service3_docker_image = "YOUR_DOCKERHUB_USERNAME/service3:latest"
```

### 3. Build Lambda Function (1 minute)

```bash
cd lambda
npm install
npm run build
cd ..
```

### 4. Deploy Infrastructure (7 minutes)

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy (takes ~5-7 minutes)
terraform apply -auto-approve
```

### 5. Test Your Setup (1 minute)

```bash
# Get outputs
terraform output

# Test Lambda invocation
make invoke-lambda

# Test services directly
make test-service1
make test-service2
make test-service3
```

## Verify Deployment

### Check ECS Services

```bash
aws ecs list-services --cluster $(terraform output -raw ecs_cluster_name)
```

### Check Step Functions

```bash
aws stepfunctions list-executions \
  --state-machine-arn $(terraform output -raw step_functions_arn)
```

### View Logs

```bash
# ECS logs
make logs-ecs

# Lambda logs
make logs-lambda
```

## Test the Workflow

### Using AWS CLI

```bash
aws lambda invoke \
  --function-name $(terraform output -raw lambda_function_name) \
  --payload '{"userId": 123, "action": "process", "data": {"test": true}}' \
  response.json

cat response.json
```

### Using the Makefile

```bash
make invoke-lambda
```

### Using curl (via API Gateway)

```bash
API_URL=$(terraform output -raw api_gateway_url)

# Test individual service
curl -X POST $API_URL/service1/process \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

## Expected Response

After invoking the Lambda, you'll receive:

```json
{
  "message": "Workflow execution started successfully",
  "executionArn": "arn:aws:states:us-east-1:123456789:execution:...",
  "executionName": "execution-1729339200000-abc123",
  "startDate": "2025-10-19T10:00:00.000Z"
}
```

The Step Functions execution will produce:

```json
{
  "start": "2025-10-19T10:00:00.000Z",
  "end": "2025-10-19T10:00:05.000Z",
  "service1": {
    "start": "2025-10-19T10:00:01.000Z",
    "end": "2025-10-19T10:00:02.000Z",
    "serviceIp": "10.0.1.123",
    "statusCode": 200,
    "response": {...}
  },
  "service2": {
    "start": "2025-10-19T10:00:02.500Z",
    "end": "2025-10-19T10:00:03.500Z",
    "serviceIp": "10.0.2.234",
    "statusCode": 200,
    "response": {...}
  },
  "service3": {
    "start": "2025-10-19T10:00:04.000Z",
    "end": "2025-10-19T10:00:05.000Z",
    "serviceIp": "10.0.1.145",
    "statusCode": 200,
    "response": {...}
  },
  "status": "completed"
}
```

## Common Issues

### "Error: Docker Hub authentication failed"

- Verify your Docker Hub credentials in `terraform.tfvars`
- Make sure you're using an access token, not your password
- Check SSM parameters in AWS Console

### "ECS tasks failing to start"

```bash
# Check task logs
aws ecs describe-tasks \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --tasks $(aws ecs list-tasks --cluster $(terraform output -raw ecs_cluster_name) --query 'taskArns[0]' --output text)
```

### "502 Bad Gateway from API Gateway"

- Wait 2-3 minutes for ECS tasks to be fully healthy
- Check target group health: `aws elbv2 describe-target-health --target-group-arn <TARGET_GROUP_ARN>`

### "Lambda times out"

- Increase Lambda timeout in `main.tf`:
  ```hcl
  timeout = 60  # Increase from 30
  ```

## Clean Up

To remove all resources:

```bash
terraform destroy -auto-approve
```

This will delete:

- ECS cluster and services
- Application Load Balancer
- API Gateway
- Step Functions state machine
- Lambda function
- VPC and networking components
- SSM parameters

## Next Steps

1. **Customize Services**: Modify the example services to add your business logic
2. **Add Authentication**: Implement API Gateway authentication
3. **Set Up Monitoring**: Configure CloudWatch dashboards and alarms
4. **Add More Services**: Extend the workflow with additional microservices
5. **Implement CI/CD**: Set up automated deployments with GitHub Actions or GitLab CI

## Useful Commands

```bash
# Format Terraform files
make fmt

# Validate configuration
make validate

# Show all outputs
make outputs

# Tail logs
make logs-lambda
make logs-ecs

# Test individual services
make test-service1
make test-service2
make test-service3
```

## Architecture Diagram

```
┌─────────────┐
│   Lambda    │ Triggers
│  Function   ├────────────┐
└─────────────┘            │
                           ▼
                    ┌──────────────┐
                    │     Step     │
                    │  Functions   │
                    │  Workflow    │
                    └──────┬───────┘
                           │
                           │ Orchestrates
            ┏━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━┓
            ▼              ▼               ▼
    ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
    │      API     │ │      API     │ │      API     │
    │   Gateway    │ │   Gateway    │ │   Gateway    │
    │   /service1  │ │   /service2  │ │   /service3  │
    └──────┬───────┘ └──────┬───────┘ └──────┬───────┘
           │                │                 │
           ▼                ▼                 ▼
    ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
    │     ALB      │ │     ALB      │ │     ALB      │
    │Target Group 1│ │Target Group 2│ │Target Group 3│
    └──────┬───────┘ └──────┬───────┘ └──────┬───────┘
           │                │                 │
           ▼                ▼                 ▼
    ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
    │  ECS Service │ │  ECS Service │ │  ECS Service │
    │   (Fargate)  │ │   (Fargate)  │ │   (Fargate)  │
    │   Service 1  │ │   Service 2  │ │   Service 3  │
    └──────────────┘ └──────────────┘ └──────────────┘
```

## Cost Estimate

Approximate monthly costs (us-east-1):

- **ECS Fargate**: ~$30/month (3 tasks, 0.25 vCPU, 0.5 GB)
- **Application Load Balancer**: ~$23/month
- **API Gateway**: ~$3.50 per million requests
- **Step Functions**: ~$25 per million state transitions
- **Lambda**: Essentially free (first 1M requests free)
- **NAT Gateway**: ~$32/month
- **Data Transfer**: Variable

**Total**: ~$90-120/month for baseline infrastructure

## Support

For issues or questions:

1. Check the main [README.md](README.md)
2. Review AWS CloudWatch logs
3. Check Step Functions execution history
4. Review Terraform state: `terraform show`

## Resources

- [AWS Step Functions Documentation](https://docs.aws.amazon.com/step-functions/)
- [ECS Fargate Documentation](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [API Gateway HTTP API](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api.html)
