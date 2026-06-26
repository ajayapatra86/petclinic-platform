#!/usr/bin/env bash
# Bootstrap Terraform remote state: S3 bucket + DynamoDB lock table.
# Run once per AWS account, before the first `terraform init`.
# Idempotent — safe to run multiple times.
#
# Usage:
#   ./scripts/bootstrap-state.sh [--region eu-central-1]

set -euo pipefail

REGION="eu-central-1"

while [[ $# -gt 0 ]]; do
  case $1 in
    --region) REGION="$2"; shift 2 ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="petclinic-terraform-state-${ACCOUNT_ID}"
TABLE="petclinic-terraform-locks"

echo "==> AWS account : ${ACCOUNT_ID}"
echo "==> Region      : ${REGION}"
echo "==> S3 bucket   : ${BUCKET}"
echo "==> DynamoDB    : ${TABLE}"
echo ""

# ── S3 bucket ────────────────────────────────────────────────────────────────

if aws s3api head-bucket --bucket "${BUCKET}" --region "${REGION}" 2>/dev/null; then
  echo "[skip] S3 bucket already exists: ${BUCKET}"
else
  echo "[create] S3 bucket: ${BUCKET}"
  # us-east-1 is the only region that must NOT specify a LocationConstraint
  if [[ "${REGION}" == "us-east-1" ]]; then
    aws s3api create-bucket \
      --bucket "${BUCKET}" \
      --region "${REGION}"
  else
    aws s3api create-bucket \
      --bucket "${BUCKET}" \
      --region "${REGION}" \
      --create-bucket-configuration LocationConstraint="${REGION}"
  fi
fi

echo "[config] Enabling versioning on ${BUCKET}"
aws s3api put-bucket-versioning \
  --bucket "${BUCKET}" \
  --versioning-configuration Status=Enabled

echo "[config] Enabling AES256 encryption on ${BUCKET}"
aws s3api put-bucket-encryption \
  --bucket "${BUCKET}" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"},
      "BucketKeyEnabled": true
    }]
  }'

echo "[config] Blocking all public access on ${BUCKET}"
aws s3api put-public-access-block \
  --bucket "${BUCKET}" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# ── DynamoDB lock table ───────────────────────────────────────────────────────

if aws dynamodb describe-table --table-name "${TABLE}" --region "${REGION}" 2>/dev/null | grep -q ACTIVE; then
  echo "[skip] DynamoDB table already exists: ${TABLE}"
else
  echo "[create] DynamoDB table: ${TABLE}"
  aws dynamodb create-table \
    --table-name "${TABLE}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${REGION}" \
    --tags \
      Key=Project,Value=petclinic \
      Key=ManagedBy,Value=bootstrap-script \
    > /dev/null

  echo "[wait] Waiting for table to become ACTIVE..."
  aws dynamodb wait table-exists --table-name "${TABLE}" --region "${REGION}"
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "Bootstrap complete. Add this backend block to each environment's versions.tf:"
echo ""
echo '  terraform {'
echo '    backend "s3" {'
echo "      bucket         = \"${BUCKET}\""
echo "      key            = \"petclinic/{dev|prod}/terraform.tfstate\""
echo "      region         = \"${REGION}\""
echo "      dynamodb_table = \"${TABLE}\""
echo '      encrypt        = true'
echo '    }'
echo '  }'
echo ""
echo "Then run: terraform init"
