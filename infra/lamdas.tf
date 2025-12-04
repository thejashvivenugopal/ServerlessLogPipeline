resource "aws_lambda_function" "ingest" {
  function_name = "${var.project}-${var.environment}-ingest"
  handler       = "app.ingest_handler"
  runtime       = "python3.12"
  role          = aws_iam_role.lambda_role.arn
  filename      = "../services/build/lambda.zip"

  environment {
    variables = {
      QUEUE_URL     = aws_sqs_queue.ingest_queue.id
      TABLE_NAME    = aws_dynamodb_table.tenant_logs.name
    }
  }
}

resource "aws_lambda_function" "worker" {
  function_name = "${var.project}-${var.environment}-worker"
  handler       = "app.worker_handler"
  runtime       = "python3.12"
  role          = aws_iam_role.lambda_role.arn
  filename      = "../services/build/lambda.zip"
  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.tenant_logs.name
    }
  }
}

resource "aws_lambda_event_source_mapping" "worker_mapping" {
  event_source_arn  = aws_sqs_queue.ingest_queue.arn
  function_name     = aws_lambda_function.worker.arn
  batch_size        = 1
  enabled           = true
}
