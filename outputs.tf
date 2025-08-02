
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "geojson_bucket_name" {
  description = "Name of the GeoJSON S3 bucket"
  value       = aws_s3_bucket.geojson_data.bucket
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host"
  value       = aws_instance.bastion.public_ip
}

output "ecr_repository_url" {
  description = "The URL of the ECR repository"
  value       = aws_ecr_repository.geojson_processor.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.s3_trigger.function_name
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "The IDs of the private subnets"
  value       = module.vpc.private_subnets
}

output "ecr_image_uri" {
  description = "Full ECR image URI"
  value       = "${aws_ecr_repository.geojson_processor.repository_url}:latest"
}