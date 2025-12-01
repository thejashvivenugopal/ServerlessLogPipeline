# ---------- Lambda execution role base (logs) ----------
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ingest_lambda_role" {
  name               = "${local.name_prefix}-ingest-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role" "worker_lambda_role" {
  name               = "${local.name_prefix}-worker-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ingest_logging" {
  role       = aws_iam_role.ingest_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "worker_logging" {
  role       = aws_iam_role.worker_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ---------- Ingest Lambda permissions: only send to our queue ----------
data "aws_iam_policy_document" "ingest_lambda_policy" {
  statement {
    sid    = "AllowSendToIngestQueue"
    effect = "Allow"
    actions = [
      "sqs:SendMessage",
      "sqs:GetQueueAttributes"
    ]
    resources = [aws_sqs_queue.ingest_queue.arn]
  }
}

resource "aws_iam_policy" "ingest_lambda_policy" {
  name   = "${local.name_prefix}-ingest-policy"
  policy = data.aws_iam_policy_document.ingest_lambda_policy.json
}

resource "aws_iam_role_policy_attachment" "ingest_policy_attach" {
  role       = aws_iam_role.ingest_lambda_role.name
  policy_arn = aws_iam_policy.ingest_lambda_policy.arn
}

# ---------- Worker Lambda permissions: SQS + DynamoDB ----------
data "aws_iam_policy_document" "worker_lambda_policy" {
  statement {
    sid    = "AllowReadFromIngestQueue"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ChangeMessageVisibility"
    ]
    resources = [aws_sqs_queue.ingest_queue.arn]
  }

  statement {
    sid    = "AllowWriteToProcessedLogs"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:GetItem"
    ]
    resources = [aws_dynamodb_table.processed_logs.arn]
  }
}

resource "aws_iam_policy" "worker_lambda_policy" {
  name   = "${local.name_prefix}-worker-policy"
  policy = data.aws_iam_policy_document.worker_lambda_policy.json
}

resource "aws_iam_role_policy_attachment" "worker_policy_attach" {
  role       = aws_iam_role.worker_lambda_role.name
  policy_arn = aws_iam_policy.worker_lambda_policy.arn
}
