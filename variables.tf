variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "workflow-orchestrator"
}

variable "dockerhub_username" {
  description = "Docker Hub username"
  type        = string
  sensitive   = true
}

variable "dockerhub_password" {
  description = "Docker Hub password or token"
  type        = string
  sensitive   = true
}

variable "service1_docker_image" {
  description = "Docker image for service 1 (e.g., username/image:tag)"
  type        = string
}

variable "service1_container_port" {
  description = "Container port for service 1"
  type        = number
  default     = 3000
}

variable "service2_docker_image" {
  description = "Docker image for service 2"
  type        = string
}

variable "service2_container_port" {
  description = "Container port for service 2"
  type        = number
  default     = 3000
}

variable "service3_docker_image" {
  description = "Docker image for service 3"
  type        = string
}

variable "service3_container_port" {
  description = "Container port for service 3"
  type        = number
  default     = 3000
}
