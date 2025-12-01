output "api_endpoint" {
  description = "Base URL for the HTTP API"
  value       = aws_apigatewayv2_api.http_api.api_endpoint
}

output "ingest_url" {
  description = "Full ingest endpoint"
  value       = "${aws_apigatewayv2_api.http_api.api_endpoint}/ingest"
}

output "sqs_queue_url" {
  value = aws_sqs_queue.ingest_queue.id
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.processed_logs.name
}
