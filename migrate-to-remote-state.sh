#!/bin/bash

echo "🚀 Migrating to Remote State Management"

# Step 1: Remove duplicate backend temporarily
echo "🔧 Preparing configuration..."
if [ -f "backend.tf" ]; then
    mv backend.tf backend.tf.backup
fi

# Step 2: Create state infrastructure first
echo "📦 Creating S3 bucket and DynamoDB table..."
terraform apply -target=aws_s3_bucket.terraform_state -target=aws_s3_bucket_versioning.terraform_state -target=aws_s3_bucket_encryption.terraform_state -target=aws_s3_bucket_public_access_block.terraform_state -target=aws_dynamodb_table.terraform_state_lock -auto-approve

# Step 3: Restore backend configuration
echo "🔄 Restoring backend configuration..."
if [ -f "backend.tf.backup" ]; then
    mv backend.tf.backup backend.tf
fi

# Step 4: Copy current state to S3
echo "📤 Uploading current state to S3..."
aws s3 cp terraform.tfstate s3://terraform-state-asterra-project/geojson-processor/terraform.tfstate

# Step 5: Initialize with backend
echo "🔄 Reinitializing with remote backend..."
terraform init -migrate-state

# Step 6: Verify
echo "✅ Verifying remote state..."
terraform state list

echo "🎉 Migration complete! State is now stored remotely."