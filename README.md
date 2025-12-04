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
    - Adds tenant_id, auto-generated UUID log_id, metadata
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
    - Partition key (pk): tenant_id
    - Sort key (sk): UUID-generated log_id
```

## 2. Getting Started (Local → AWS)

### 2.1 Clone the repo

```bash
git clone <your-repo-url>.git
cd <your-repo-folder>
```

### 2.2 Build the Lambda Deployment Package
```bash
# From the project root
cd services/build

# Remove old package
rm -f lambda.zip

# Create temporary packaging directory
mkdir -p lambda

# (Optional) Install Python dependencies into the package
# If requirements.txt exists, uncomment the line below:
# pip install -r ../../requirements.txt -t lambda_pkg/

# Add Lambda source code
cp ../app.py lambda/

# Build the ZIP archive
cd lambda
zip -r ../lambda.zip .
cd ..
rm -rf lambda
cd ../..


### 2.3 Terraform commands
```bash
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
curl --location '$INGEST_URL' \
--header 'Content-Type: application/json' \
--data '{
    "tenant_id": "acme_corp",
    "text": "User 555-0199 accessed system"
  }'
```

# Raw Text example
```
curl --location '$INGEST_URL' \
--header 'Content-Type: text/plain' \
--header 'X-Tenant-ID: beta_inc' \
--data 'Raw log dump with 555-0199 inside'
```
