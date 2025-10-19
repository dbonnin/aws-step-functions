output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.service.name
}

output "task_definition_arn" {
  description = "ARN of the task definition"
  value       = aws_ecs_task_definition.service.arn
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.service.arn
}
