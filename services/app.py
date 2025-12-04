import json
import os
import time
import uuid
import boto3

# AWS clients
sqs = boto3.client("sqs")
dynamodb = boto3.client("dynamodb")

# Environment variables
QUEUE_URL = os.environ.get("QUEUE_URL")
TABLE_NAME = os.environ.get("TABLE_NAME")


# ============================================================
#  INGEST HANDLER  (API Gateway → Lambda)
# ============================================================
def ingest_handler(event, context):
    """
    /ingest endpoint
    Accepts:
      - JSON payload with tenant_id, text
      - text/plain payload with X-Tenant-ID header

    Automatically generates:
      - log_id = UUID4

    Normalizes into: "tenant_id|log_id|source|text"
    Sends to SQS.
    Returns 202 immediately (non-blocking)
    """

    headers = event.get("headers", {})
    content_type = headers.get("content-type") or headers.get("Content-Type")

    # Case 1 — JSON payload
    if content_type == "application/json":
        body = json.loads(event["body"])
        tenant_id = body["tenant_id"]
        text = body["text"]
        log_id = str(uuid.uuid4())   # auto-generate unique ID
        source = "json"

    # Case 2 — text/plain payload
    elif content_type == "text/plain":
        tenant_id = headers.get("x-tenant-id") or headers.get("X-Tenant-ID")
        if not tenant_id:
            return {"statusCode": 400, "body": "Missing X-Tenant-ID header"}

        text = event["body"]
        log_id = str(uuid.uuid4())   # auto-generate unique ID
        source = "text"

    else:
        return {"statusCode": 400, "body": "Unsupported content-type"}

    # Normalize into TXT format: tenant|log_id|source|text
    normalized = f"{tenant_id}|{log_id}|{source}|{text}"

    # Publish to SQS
    sqs.send_message(
        QueueUrl=QUEUE_URL,
        MessageBody=normalized
    )

    return {"statusCode": 202, "body": "Accepted"}


# ============================================================
#  WORKER HANDLER (SQS → Lambda)
# ============================================================
def worker_handler(event, context):
    """
    Processes messages from SQS.

    Expected format:
        tenant_id | log_id | source | text

    Safe parsing:
      - Handles text containing '|' characters
      - Skips malformed messages instead of crashing
    """

    for record in event["Records"]:
        body = record["body"]

        # Split with unlimited segments; join remaining text safely
        parts = body.split("|")

        # SAFETY CHECK: Must have at least 4 parts
        if len(parts) < 4:
            print("Malformed message, skipping:", body)
            continue

        tenant_id = parts[0]
        log_id = parts[1]
        source = parts[2]
        text = "|".join(parts[3:])  # handles pipes in text correctly

        # Heavy processing simulation
        time.sleep(len(text) * 0.05)

        # Save into DynamoDB
        dynamodb.put_item(
            TableName=TABLE_NAME,
            Item={
                "pk": {"S": tenant_id},
                "sk": {"S": log_id},
                "source": {"S": source},
                "text": {"S": text},
                "processed_at": {
                    "S": time.strftime("%Y-%m-%dT%H:%M:%SZ")
                }
            }
        )

    return {"status": "ok"}
