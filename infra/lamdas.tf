resource "aws_lambda_function" "ingest" {
  function_name = "${local.name_prefix}-ingest"

  filename         = var.ingest_lambda_zip
  source_code_hash = filebase64sha256(var.ingest_lambda_zip)

  role    = aws_iam_role.ingest_lambda_role.arn
  handler = "app.lambda_handler" # adjust to your code
  runtime = "python3.12"         # or nodejs, etc.

  timeout     = 5 # API handler must be quick
  memory_size = 256

  environment {
    variables = {
      QUEUE_URL = aws_sqs_queue.ingest_queue.id
      ENV       = var.env
      PROJECT   = var.project
    }
  }

  # Let API Gateway trigger it later
}

resource "aws_lambda_function" "worker" {
  function_name = "${local.name_prefix}-worker"

  filename         = var.worker_lambda_zip
  source_code_hash = filebase64sha256(var.worker_lambda_zip)

  role    = aws_iam_role.worker_lambda_role.arn
  handler = "app.lambda_handler" # adjust to your code
  runtime = "python3.12"

  timeout     = 60 # must cover max processing time per message
  memory_size = 512


  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.processed_logs.name
      ENV        = var.env
      PROJECT    = var.project
    }
  }
}

# SQS → Worker event source mapping
resource "aws_lambda_event_source_mapping" "worker_sqs" {
  event_source_arn = aws_sqs_queue.ingest_queue.arn
  function_name    = aws_lambda_function.worker.arn

  batch_size                         = 5
  maximum_batching_window_in_seconds = 5
  enabled                            = true
}
