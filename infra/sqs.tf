resource "aws_sqs_queue" "ingest_queue" {
  name                      = "${var.project}-${var.environment}-ingest"
  visibility_timeout_seconds = 120
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 1
  redrive_policy = jsonencode({
    maxReceiveCount     = 5
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
  })
}

resource "aws_sqs_queue" "dlq" {
  name = "${var.project}-${var.environment}-dlq"
}
