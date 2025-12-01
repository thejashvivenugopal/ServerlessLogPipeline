import json
import os
import time
from datetime import datetime

import boto3

TABLE_NAME = os.environ["TABLE_NAME"]  # set by Terraform
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE_NAME)


def _mask_text(text: str) -> str:
    """
    Very simple 'redaction' example: replace digits with X.
    You can describe this as PII redaction in your video.
    """
    return "".join("X" if ch.isdigit() else ch for ch in text)


def lambda_handler(event, context):
    records = event.get("Records") or []
    print(f"Worker invoked with {len(records)} records")

    for record in records:
        try:
            body = json.loads(record["body"])
            tenant_id = body["tenant_id"]
            log_id = body["log_id"]
            text = body["text"]
            source = body.get("source", "unknown")
            received_at = body.get("received_at")

            # Simulate heavy CPU work
            sleep_seconds = 0.05 * len(text)
            print(
                f"Processing tenant={tenant_id}, log_id={log_id}, "
                f"text_len={len(text)}, sleeping={sleep_seconds:.2f}s"
            )
            time.sleep(sleep_seconds)

            modified = _mask_text(text)

            item = {
                "tenant_id": tenant_id,  # partition key
                "log_id": log_id,        # sort key
                "source": source,
                "original_text": text,
                "modified_data": modified,
                "received_at": received_at,
                "processed_at": datetime.utcnow().isoformat() + "Z",
            }

            table.put_item(Item=item)
            print(f"Wrote item for tenant={tenant_id}, log_id={log_id}")

        except Exception as e:
            # Let SQS redrive to DLQ on repeated failure
            print("Error processing record:", json.dumps(record))
            print("Exception:", repr(e))
            # Do NOT raise here if you want partial success;
            # for the challenge it's okay to raise so SQS retries the whole batch.
            raise

    return {"statusCode": 200}
