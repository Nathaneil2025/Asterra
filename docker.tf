# ECR Repository for the container image
resource "aws_ecr_repository" "geojson_processor" {
  name                 = "geojson-processor"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Generate a unique tag based on content hash
locals {
  image_tag = substr(sha256(join("", [
    filemd5("${path.module}/geojson-processor/Dockerfile"),
    filemd5("${path.module}/geojson-processor/app.py"),
    filemd5("${path.module}/geojson-processor/requirements.txt")
  ])), 0, 8)
}

resource "null_resource" "docker_build_and_push" {
  depends_on = [aws_ecr_repository.geojson_processor]

  triggers = {
    image_tag = local.image_tag
    repository_url = aws_ecr_repository.geojson_processor.repository_url
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Building image with tag: ${local.image_tag}"
      
      # Check if Docker is running
      if ! docker info > /dev/null 2>&1; then
        echo "Error: Docker is not running. Please start Docker and try again."
        exit 1
      fi
      
      # ECR login
      aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.geojson_processor.repository_url}
      
      # Build with specific tag
      cd ${path.module}/geojson-processor
      docker build -t geojson-processor:${local.image_tag} .
      
      # Tag for ECR
      docker tag geojson-processor:${local.image_tag} ${aws_ecr_repository.geojson_processor.repository_url}:${local.image_tag}
      docker tag geojson-processor:${local.image_tag} ${aws_ecr_repository.geojson_processor.repository_url}:latest
      
      # Push both tags
      docker push ${aws_ecr_repository.geojson_processor.repository_url}:${local.image_tag}
      docker push ${aws_ecr_repository.geojson_processor.repository_url}:latest
      
      echo "Image pushed with tags: ${local.image_tag} and latest"
    EOT

    interpreter = ["bash", "-c"]
  }

  # Clean up local images on destroy
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      docker rmi geojson-processor:${self.triggers.image_tag} || true
      docker rmi ${self.triggers.repository_url}:${self.triggers.image_tag} || true
      docker rmi ${self.triggers.repository_url}:latest || true
    EOT
    interpreter = ["bash", "-c"]
  }
}

# Data source to get the image URI after build
data "aws_ecr_image" "geojson_processor_image" {
  depends_on      = [null_resource.docker_build_and_push]
  repository_name = aws_ecr_repository.geojson_processor.name
  image_tag       = local.image_tag
}