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

# Docker Hub Credentials in SSM Parameter Store
resource "aws_ssm_parameter" "dockerhub_username" {
  name        = "/${var.project_name}/dockerhub/username"
  description = "Docker Hub username"
  type        = "SecureString"
  value       = var.dockerhub_username
}

resource "aws_ssm_parameter" "dockerhub_password" {
  name        = "/${var.project_name}/dockerhub/password"
  description = "Docker Hub password"
  type        = "SecureString"
  value       = var.dockerhub_password
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
        "ssm:GetParameters",
        "ssm:GetParameter"
      ]
      Resource = [
        aws_ssm_parameter.dockerhub_username.arn,
        aws_ssm_parameter.dockerhub_password.arn
      ]
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

# Service 1
module "service1" {
  source = "./modules/ecs-service"

  project_name             = var.project_name
  service_name             = "service1"
  cluster_id               = aws_ecs_cluster.main.id
  vpc_id                   = module.vpc.vpc_id
  subnets                  = module.vpc.private_subnets
  security_group_id        = aws_security_group.ecs_tasks.id
  task_execution_role_arn  = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn
  docker_image             = var.service1_docker_image
  dockerhub_username_param = aws_ssm_parameter.dockerhub_username.arn
  dockerhub_password_param = aws_ssm_parameter.dockerhub_password.arn
  log_group_name           = aws_cloudwatch_log_group.ecs.name
  alb_arn                  = aws_lb.main.arn
  alb_listener_port        = 80
  container_port           = var.service1_container_port
  desired_count            = 1
  cpu                      = "256"
  memory                   = "512"
}

# Service 2
module "service2" {
  source = "./modules/ecs-service"

  project_name             = var.project_name
  service_name             = "service2"
  cluster_id               = aws_ecs_cluster.main.id
  vpc_id                   = module.vpc.vpc_id
  subnets                  = module.vpc.private_subnets
  security_group_id        = aws_security_group.ecs_tasks.id
  task_execution_role_arn  = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn
  docker_image             = var.service2_docker_image
  dockerhub_username_param = aws_ssm_parameter.dockerhub_username.arn
  dockerhub_password_param = aws_ssm_parameter.dockerhub_password.arn
  log_group_name           = aws_cloudwatch_log_group.ecs.name
  alb_arn                  = aws_lb.main.arn
  alb_listener_port        = 80
  container_port           = var.service2_container_port
  desired_count            = 1
  cpu                      = "256"
  memory                   = "512"
}

# Service 3
module "service3" {
  source = "./modules/ecs-service"

  project_name             = var.project_name
  service_name             = "service3"
  cluster_id               = aws_ecs_cluster.main.id
  vpc_id                   = module.vpc.vpc_id
  subnets                  = module.vpc.private_subnets
  security_group_id        = aws_security_group.ecs_tasks.id
  task_execution_role_arn  = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn
  docker_image             = var.service3_docker_image
  dockerhub_username_param = aws_ssm_parameter.dockerhub_username.arn
  dockerhub_password_param = aws_ssm_parameter.dockerhub_password.arn
  log_group_name           = aws_cloudwatch_log_group.ecs.name
  alb_arn                  = aws_lb.main.arn
  alb_listener_port        = 80
  container_port           = var.service3_container_port
  desired_count            = 1
  cpu                      = "256"
  memory                   = "512"
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
  integration_uri  = module.service1.target_group_arn

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
  integration_uri  = module.service2.target_group_arn

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
  integration_uri  = module.service3.target_group_arn

  integration_method = "ANY"
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.main.id
}

resource "aws_apigatewayv2_route" "service3" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /service3/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.service3.id}"
}

# Step Functions
resource "aws_sfn_state_machine" "workflow" {
  name     = "${var.project_name}-workflow"
  role_arn = aws_iam_role.step_functions.arn

  definition = templatefile("${path.module}/step-function-definition.json", {
    api_endpoint = aws_apigatewayv2_stage.main.invoke_url
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
          "states:InvokeHTTPEndpoint"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "events:RetrieveConnectionCredentials"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda Function to Invoke Workflow
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"
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
