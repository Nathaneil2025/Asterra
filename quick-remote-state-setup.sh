#!/bin/bash

echo "🚀 Quick Remote State Setup"

# Step 1: Create S3 bucket manually
echo "📦 Creating S3 bucket..."
aws s3 mb s3://terraform-state-asterra-project --region eu-central-1

# Step 2: Enable versioning
echo "🔄 Enabling versioning..."
aws s3api put-bucket-versioning --bucket terraform-state-asterra-project --versioning-configuration Status=Enabled

# Step 3: Create DynamoDB table
echo "🔐 Creating DynamoDB lock table..."
aws dynamodb create-table \
    --table-name terraform-state-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region eu-central-1

# Step 4: Upload current state
echo "📤 Uploading current state..."
aws s3 cp terraform.tfstate s3://terraform-state-asterra-project/geojson-processor/terraform.tfstate

# Step 5: Initialize with backend
echo "🔄 Initializing with remote backend..."
terraform init -migrate-state

echo "✅ Done! Remote state is configured."
