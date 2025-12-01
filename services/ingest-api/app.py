import json
import os
import base64
import boto3
from datetime import datetime
from uuid import uuid4

sqs = boto3.client("sqs")
QUEUE_URL = os.environ["QUEUE_URL"]  # set by Terraform


def _parse_body(event):
    """Return (tenant_id, log_id, text, source) or raise ValueError."""
    headers = event.get("headers") or {}
    # Normalize header keys to lowercase
    headers = {k.lower(): v for k, v in headers.items()}

    content_type = headers.get("content-type", "").split(";")[0].strip()
    raw_body = event.get("body") or ""

    if event.get("isBase64Encoded"):
        raw_body = base64.b64decode(raw_body).decode("utf-8")

    if content_type == "application/json":
        try:
            data = json.loads(raw_body)
        except json.JSONDecodeError:
            raise ValueError("Invalid JSON body")

        tenant_id = data.get("tenant_id")
        log_id = data.get("log_id") or str(uuid4())
        text = data.get("text")
        source = "json_upload"

        if not tenant_id or not text:
            raise ValueError("tenant_id and text are required in JSON body")

        return tenant_id, log_id, text, source

    elif content_type == "text/plain":
        tenant_id = headers.get("x-tenant-id")
        if not tenant_id:
            raise ValueError("X-Tenant-ID header is required for text/plain")

        log_id = str(uuid4())
        text = raw_body
        source = "text_upload"

        if not text:
            raise ValueError("Empty text body")

        return tenant_id, log_id, text, source

    else:
        raise ValueError(f"Unsupported Content-Type: {content_type}")


def lambda_handler(event, context):
    try:
        tenant_id, log_id, text, source = _parse_body(event)

        message = {
            "tenant_id": tenant_id,
            "log_id": log_id,
            "text": text,
            "source": source,
            "received_at": datetime.utcnow().isoformat() + "Z",
        }

        sqs.send_message(
            QueueUrl=QUEUE_URL,
            MessageBody=json.dumps(message),
        )

        # Non-blocking: immediately return 202
        return {
            "statusCode": 202,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps(
                {"status": "accepted", "tenant_id": tenant_id, "log_id": log_id}
            ),
        }

    except ValueError as e:
        # Client error (bad payload / missing headers)
        return {
            "statusCode": 400,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": str(e)}),
        }
    except Exception as e:
        # Server error
        print("Unexpected error:", repr(e))
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "internal_server_error"}),
        }
