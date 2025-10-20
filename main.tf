terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC and Networking
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-tasks-sg"
  description = "Allow inbound traffic for ECS tasks"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ecs-tasks-sg"
  }
}

# Additional security group rule for ECS tasks to receive traffic from ALB
resource "aws_security_group_rule" "ecs_from_alb" {
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.ecs_tasks.id
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# CloudWatch Log Group for ECS
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 7
}


# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_task_execution_ssm" {
  name = "${var.project_name}-ecs-task-execution-ssm"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "arn:aws:logs:*:*:*"
    }]
  })
}

# IAM Role for ECS Tasks
resource "aws_iam_role" "ecs_task" {
  name = "${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

# Load Balancer for ECS Services
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false
}

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Main ALB Listener
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Service not found"
      status_code  = "404"
    }
  }
}

# Service 1
module "service1" {
  source = "./modules/ecs-service"

  project_name            = var.project_name
  service_name            = "service1"
  cluster_id              = aws_ecs_cluster.main.id
  vpc_id                  = module.vpc.vpc_id
  subnets                 = module.vpc.private_subnets
  security_group_id       = aws_security_group.ecs_tasks.id
  task_execution_role_arn = aws_iam_role.ecs_task_execution.arn
  task_role_arn           = aws_iam_role.ecs_task.arn
  docker_image            = var.service1_docker_image
  log_group_name          = aws_cloudwatch_log_group.ecs.name
  alb_arn                 = aws_lb.main.arn
  alb_listener_arn        = aws_lb_listener.main.arn
  listener_priority       = 100
  container_port          = var.service1_container_port
  desired_count           = 1
  cpu                     = "256"
  memory                  = "512"
}

# Service 2
module "service2" {
  source = "./modules/ecs-service"

  project_name            = var.project_name
  service_name            = "service2"
  cluster_id              = aws_ecs_cluster.main.id
  vpc_id                  = module.vpc.vpc_id
  subnets                 = module.vpc.private_subnets
  security_group_id       = aws_security_group.ecs_tasks.id
  task_execution_role_arn = aws_iam_role.ecs_task_execution.arn
  task_role_arn           = aws_iam_role.ecs_task.arn
  docker_image            = var.service2_docker_image
  log_group_name          = aws_cloudwatch_log_group.ecs.name
  alb_arn                 = aws_lb.main.arn
  alb_listener_arn        = aws_lb_listener.main.arn
  listener_priority       = 200
  container_port          = var.service2_container_port
  desired_count           = 0
  cpu                     = "256"
  memory                  = "512"
}

# Service 3
module "service3" {
  source = "./modules/ecs-service"

  project_name            = var.project_name
  service_name            = "service3"
  cluster_id              = aws_ecs_cluster.main.id
  vpc_id                  = module.vpc.vpc_id
  subnets                 = module.vpc.private_subnets
  security_group_id       = aws_security_group.ecs_tasks.id
  task_execution_role_arn = aws_iam_role.ecs_task_execution.arn
  task_role_arn           = aws_iam_role.ecs_task.arn
  docker_image            = var.service3_docker_image
  log_group_name          = aws_cloudwatch_log_group.ecs.name
  alb_arn                 = aws_lb.main.arn
  alb_listener_arn        = aws_lb_listener.main.arn
  listener_priority       = 300
  container_port          = var.service3_container_port
  desired_count           = 0
  cpu                     = "256"
  memory                  = "512"
}

# API Gateway
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "main" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_vpc_link" "main" {
  name               = "${var.project_name}-vpc-link"
  security_group_ids = [aws_security_group.ecs_tasks.id]
  subnet_ids         = module.vpc.private_subnets
}

# API Gateway Integrations
resource "aws_apigatewayv2_integration" "service1" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "HTTP_PROXY"
  integration_uri  = aws_lb_listener.main.arn

  integration_method = "ANY"
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.main.id
}

resource "aws_apigatewayv2_route" "service1" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /service1/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.service1.id}"
}

resource "aws_apigatewayv2_integration" "service2" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "HTTP_PROXY"
  integration_uri  = aws_lb_listener.main.arn

  integration_method = "ANY"
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.main.id
}

resource "aws_apigatewayv2_route" "service2" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /service2/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.service2.id}"
}

resource "aws_apigatewayv2_integration" "service3" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "HTTP_PROXY"
  integration_uri  = aws_lb_listener.main.arn

  integration_method = "ANY"
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.main.id
}

resource "aws_apigatewayv2_route" "service3" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /service3/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.service3.id}"
}

# API Gateway integration for workflow invoker
resource "aws_apigatewayv2_integration" "workflow_invoker" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.workflow_invoker.invoke_arn
}

resource "aws_apigatewayv2_route" "workflow_invoker" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /workflow"
  target    = "integrations/${aws_apigatewayv2_integration.workflow_invoker.id}"
}

# Lambda permission for API Gateway to invoke workflow_invoker
resource "aws_lambda_permission" "api_gateway_workflow_invoker" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.workflow_invoker.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

# Step Functions
resource "aws_sfn_state_machine" "workflow" {
  name     = "${var.project_name}-workflow"
  role_arn = aws_iam_role.step_functions.arn

  definition = templatefile("${path.module}/step-function-lambda-definition.json", {
    service1_lambda_arn = aws_lambda_function.service1_proxy.arn
  })
}

resource "aws_iam_role" "step_functions" {
  name = "${var.project_name}-step-functions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "states.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "step_functions" {
  name = "${var.project_name}-step-functions-policy"
  role = aws_iam_role.step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          aws_lambda_function.service1_proxy.arn,
          aws_lambda_function.service2_proxy.arn,
          aws_lambda_function.service3_proxy.arn
        ]
      }
    ]
  })
}

# Lambda Function to Invoke Workflow  
data "archive_file" "lambda" {
  type             = "zip"
  source_dir       = "${path.module}/lambda"
  output_path      = "${path.module}/lambda.zip"
  output_file_mode = "0666"

  depends_on = [
    # Ensure lambda is built before archiving
  ]
}

resource "aws_lambda_function" "workflow_invoker" {
  filename         = data.archive_file.lambda.output_path
  function_name    = "${var.project_name}-workflow-invoker"
  role             = aws_iam_role.lambda.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime          = "nodejs20.x"
  timeout          = 30

  environment {
    variables = {
      STATE_MACHINE_ARN = aws_sfn_state_machine.workflow.arn
    }
  }
}

resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_step_functions" {
  name = "${var.project_name}-lambda-step-functions"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "states:StartExecution",
        "states:DescribeExecution"
      ]
      Resource = [
        aws_sfn_state_machine.workflow.arn,
        "${aws_sfn_state_machine.workflow.arn}:*"
      ]
    }]
  })
}

# Create a zip file for Lambda proxy functions
data "archive_file" "lambda_proxy" {
  type        = "zip"
  source_file = "lambda-service-proxy.js"
  output_path = "lambda-service-proxy.zip"
}

# Lambda functions to proxy calls to each service
resource "aws_lambda_function" "service1_proxy" {
  filename      = "lambda-service-proxy.zip"
  function_name = "${var.project_name}-service1-proxy"
  role          = aws_iam_role.lambda_proxy.arn
  handler       = "lambda-service-proxy.handler"
  runtime       = "nodejs20.x"
  timeout       = 30

  source_code_hash = data.archive_file.lambda_proxy.output_base64sha256

  environment {
    variables = {
      SERVICE_ENDPOINT = "http://${aws_lb.main.dns_name}/service1"
      SERVICE_NAME     = "service1"
    }
  }

  vpc_config {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [aws_security_group.lambda_proxy.id]
  }
}

resource "aws_lambda_function" "service2_proxy" {
  filename      = "lambda-service-proxy.zip"
  function_name = "${var.project_name}-service2-proxy"
  role          = aws_iam_role.lambda_proxy.arn
  handler       = "lambda-service-proxy.handler"
  runtime       = "nodejs20.x"
  timeout       = 30

  source_code_hash = data.archive_file.lambda_proxy.output_base64sha256

  environment {
    variables = {
      SERVICE_ENDPOINT = "http://${aws_lb.main.dns_name}/service2"
      SERVICE_NAME     = "service2"
    }
  }

  vpc_config {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [aws_security_group.lambda_proxy.id]
  }
}

resource "aws_lambda_function" "service3_proxy" {
  filename      = "lambda-service-proxy.zip"
  function_name = "${var.project_name}-service3-proxy"
  role          = aws_iam_role.lambda_proxy.arn
  handler       = "lambda-service-proxy.handler"
  runtime       = "nodejs20.x"
  timeout       = 30

  source_code_hash = data.archive_file.lambda_proxy.output_base64sha256

  environment {
    variables = {
      SERVICE_ENDPOINT = "http://${aws_lb.main.dns_name}/service3"
      SERVICE_NAME     = "service3"
    }
  }

  vpc_config {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [aws_security_group.lambda_proxy.id]
  }
}

# IAM role for Lambda proxy functions
resource "aws_iam_role" "lambda_proxy" {
  name = "${var.project_name}-lambda-proxy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_proxy_basic" {
  role       = aws_iam_role.lambda_proxy.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_proxy_vpc" {
  role       = aws_iam_role.lambda_proxy.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Security group for Lambda proxy functions
resource "aws_security_group" "lambda_proxy" {
  name        = "${var.project_name}-lambda-proxy-sg"
  description = "Security group for Lambda proxy functions"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-lambda-proxy-sg"
  }
}
