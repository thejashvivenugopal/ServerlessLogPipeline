resource "aws_cloudwatch_log_group" "ingest_logs" {
  name              = "/aws/lambda/${aws_lambda_function.ingest.function_name}"
  retention_in_days = 7  # keep only 7 days of logs
}

resource "aws_cloudwatch_log_group" "worker_logs" {
  name              = "/aws/lambda/${aws_lambda_function.worker.function_name}"
  retention_in_days = 7
}
