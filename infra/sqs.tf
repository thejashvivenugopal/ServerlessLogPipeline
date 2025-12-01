locals {
  name_prefix = "${var.project}-${var.env}"
}

resource "aws_sqs_queue" "ingest_dlq" {
  name = "${local.name_prefix}-ingest-dlq"

  message_retention_seconds = 1209600         # 14 days
  kms_master_key_id         = "alias/aws/sqs" # AWS-managed KMS
}

resource "aws_sqs_queue" "ingest_queue" {
  name = "${local.name_prefix}-ingest-queue"

  visibility_timeout_seconds = 60      # >= worker lambda timeout
  message_retention_seconds  = 1209600 # 14 days
  receive_wait_time_seconds  = 0

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.ingest_dlq.arn
    maxReceiveCount     = 5
  })

  kms_master_key_id = "alias/aws/sqs" # encrypted at rest
}
