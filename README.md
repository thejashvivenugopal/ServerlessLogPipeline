# Serverless Log Ingestion Pipeline

This project implements a **scalable, multi-tenant, event-driven backend** on **AWS**.

The system exposes a single **`POST /ingest`** endpoint that:

- Accepts both **JSON** and **raw text** logs
- Normalizes them into a unified internal format
- Enqueues them to a **managed message broker (SQS)**
- Processes them asynchronously via a **worker Lambda**
- Stores results in **DynamoDB** with **strict tenant isolation**

All core infrastructure is provisioned via **Terraform**.

---

## 1. High-Level Architecture

**Data flow:**

```text
Client (JSON / TXT)
    |
    v
AWS API Gateway (HTTP API)  -- public /ingest
    |
    v
Ingest Lambda (Python)
    - Validates request
    - Normalizes JSON + text/plain
    - Adds tenant_id, log_id, metadata
    - Publishes to SQS
    - Returns 202 Accepted (non-blocking)
    |
    v
AWS SQS (Ingest Queue)  -- buffered, durable, DLQ attached
    |
    v
Worker Lambda (Python)
    - Pulls messages from SQS
    - Simulates heavy CPU work (sleep 0.05s per char)
    - Applies simple redaction
    - Writes to DynamoDB
    |
    v
DynamoDB (PAY_PER_REQUEST)
    - Partition key: tenant_id
    - Sort key: log_id
    - Tenant isolation at storage
```

## 2. Getting Started (Local → AWS)

### 2.1 Clone the repo

```bash
git clone <your-repo-url>.git
cd <your-repo-folder>
```

### 2.2 Build the zip files

#$ Ingest Lambda
```
cd services/ingest-api
mkdir -p build
zip -r build/ingest.zip . -x "build/*"
```
## Worker Lambda
```
cd ../worker
mkdir -p build
zip -r build/worker.zip . -x "build/*"
```
### make sure infra/terraform/env/dev.tfvars points to these zips:
```
aws_region        = "us-east-1"
project           = "serverless-log-pipeline"
env               = "dev"

ingest_lambda_zip = "../../services/ingest-api/build/ingest.zip"
worker_lambda_zip = "../../services/worker/build/worker.zip"
worker_reserved_concurrency = 2
```

### 2.3 Terraform commands
```
cd infra/

# (optional) use your AWS profile
export AWS_PROFILE=dev
export AWS_DEFAULT_REGION=us-east-1

terraform init
terraform plan  -var-file=env/dev.tfvars
terraform apply -var-file=env/dev.tfvars

```

### Get the live endpoint and test
INGEST_URL=$(terraform output -raw ingest_url)

# JSON example
```
curl -X POST "$INGEST_URL" \
-H "Content-Type: application/json" \
-d '{"tenant_id":"acme","log_id":"123","text":"hello"}'
```


