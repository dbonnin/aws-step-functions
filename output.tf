output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "api_gateway_url" {
  description = "API Gateway invoke URL"
  value       = aws_apigatewayv2_stage.main.invoke_url
}

output "service1_endpoint" {
  description = "Service 1 endpoint"
  value       = "${aws_apigatewayv2_stage.main.invoke_url}/service1"
}

output "service2_endpoint" {
  description = "Service 2 endpoint"
  value       = "${aws_apigatewayv2_stage.main.invoke_url}/service2"
}

output "service3_endpoint" {
  description = "Service 3 endpoint"
  value       = "${aws_apigatewayv2_stage.main.invoke_url}/service3"
}

output "step_functions_arn" {
  description = "ARN of the Step Functions state machine"
  value       = aws_sfn_state_machine.workflow.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function that invokes the workflow"
  value       = aws_lambda_function.workflow_invoker.function_name
}

output "workflow_endpoint" {
  description = "API Gateway endpoint to trigger the Step Functions workflow"
  value       = "${aws_apigatewayv2_stage.main.invoke_url}workflow"
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}
