#!/bin/bash

echo "🚀 Quick Remote State Setup"
echo "================================"

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ AWS CLI not configured. Please run 'aws configure' first."
    exit 1
fi

# Step 1: Create S3 bucket manually
echo "📦 Creating S3 bucket..."
if aws s3 ls s3://terraform-state-asterra-project > /dev/null 2>&1; then
    echo "✅ Bucket already exists: terraform-state-asterra-project"
else
    aws s3 mb s3://terraform-state-asterra-project --region eu-central-1
    echo "✅ Created bucket: terraform-state-asterra-project"
fi

# Step 2: Enable versioning
echo "🔄 Enabling versioning..."
aws s3api put-bucket-versioning --bucket terraform-state-asterra-project --versioning-configuration Status=Enabled
echo "✅ Versioning enabled"

# Step 3: Enable encryption
echo "🔐 Enabling encryption..."
aws s3api put-bucket-encryption \
    --bucket terraform-state-asterra-project \
    --server-side-encryption-configuration '{
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }
        ]
    }'
echo "✅ Encryption enabled"

# Step 4: Block public access
echo "🚫 Blocking public access..."
aws s3api put-public-access-block \
    --bucket terraform-state-asterra-project \
    --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
echo "✅ Public access blocked"

# Step 5: Create DynamoDB table
echo "🔐 Creating DynamoDB lock table..."
if aws dynamodb describe-table --table-name terraform-state-lock --region eu-central-1 > /dev/null 2>&1; then
    echo "✅ DynamoDB table already exists: terraform-state-lock"
else
    aws dynamodb create-table \
        --table-name terraform-state-lock \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region eu-central-1
    echo "✅ Created DynamoDB table: terraform-state-lock"
    
    # Wait for table to be active
    echo "⏳ Waiting for table to be active..."
    aws dynamodb wait table-exists --table-name terraform-state-lock --region eu-central-1
    echo "✅ Table is active"
fi

# Step 6: Upload current state (if exists)
echo "📤 Checking for existing state..."
if [ -f "terraform.tfstate" ]; then
    echo "📤 Uploading current state..."
    aws s3 cp terraform.tfstate s3://terraform-state-asterra-project/geojson-processor/terraform.tfstate
    echo "✅ State uploaded"
    
    # Backup local state
    cp terraform.tfstate terraform.tfstate.backup.$(date +%Y%m%d_%H%M%S)
    echo "✅ Local state backed up"
else
    echo "ℹ️  No local state file found - starting fresh"
fi

# Step 7: Initialize with backend
echo "🔄 Initializing with remote backend..."
if terraform init -migrate-state -input=false; then
    echo "✅ Remote backend initialized successfully"
else
    echo "❌ Failed to initialize remote backend"
    exit 1
fi

# Step 8: Verify setup
echo "🔍 Verifying setup..."
echo ""
echo "=== Remote State Verification ==="
aws s3 ls s3://terraform-state-asterra-project/geojson-processor/ || echo "No state file yet (normal for new setup)"
echo ""
echo "=== DynamoDB Lock Table ==="
aws dynamodb describe-table --table-name terraform-state-lock --region eu-central-1 --query 'Table.[TableName,TableStatus]' --output table
echo ""

echo "🎯 REMOTE STATE SETUP COMPLETED!"
echo "================================="
echo "📦 S3 Bucket: terraform-state-asterra-project"
echo "🔒 DynamoDB Table: terraform-state-lock"
echo "📍 State Key: geojson-processor/terraform.tfstate"
echo "🌍 Region: eu-central-1"
echo ""
echo "✅ You can now run 'terraform plan' and 'terraform apply'"
echo "✅ Your CI/CD pipeline will automatically use this remote state"
echo ""
echo "⚠️  IMPORTANT: Keep this bucket and DynamoDB table!"
echo "⚠️  They contain your infrastructure state and should not be deleted"
