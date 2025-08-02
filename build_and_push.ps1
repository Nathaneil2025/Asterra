# Variables
$AWS_REGION = "eu-central-1"
$ECR_REPOSITORY = "geojson-processor"

# Get ECR repository URL from Terraform output
$ecrUrl = terraform output -raw ecr_repository_url

# Get AWS account ID and region
$accountId = aws sts get-caller-identity --query Account --output text
$region = "eu-central-1"

Write-Host "ECR Repository URL: $ecrUrl"

# Login to ECR
aws ecr get-login-password --region $region | docker login --username AWS --password-stdin $ecrUrl

# Build the Docker image
Write-Host "Building Docker image..."
docker build -t geojson-processor ./geojson-processor

# Tag image for ECR
docker tag geojson-processor:latest $ecrUrl`:latest

# Push image to ECR
Write-Host "Pushing image to ECR..."
docker push $ecrUrl`:latest

Write-Host "Docker image pushed successfully!"
Write-Host "ECR Repository: $ecrUrl"