output "api_endpoint" {
  description = "URL endpoint API (buka di browser / curl)"
  value       = aws_apigatewayv2_api.this.api_endpoint
}

output "function_name" {
  value = aws_lambda_function.this.function_name
}

output "function_arn" {
  value = aws_lambda_function.this.arn
}

output "dlq_url" {
  description = "Dead-letter queue holding invocations that exhausted their retries"
  value       = aws_sqs_queue.dlq.url
}
