provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = "192.168.0.0/16"

  azs             = ["eu-central-1a", "eu-central-1b"]
  private_subnets = ["192.168.1.0/24", "192.168.2.0/24"]
  public_subnets  = ["192.168.101.0/24", "192.168.102.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = false

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_security_group" "rds" {
  name        = "rds-security-group"
  description = "Security group for RDS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Add security group rule to allow ECS to access RDS
resource "aws_security_group_rule" "rds_from_ecs" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_tasks.id
  security_group_id        = aws_security_group.rds.id
}

resource "aws_db_instance" "postgres" {
  identifier           = "my-postgres-db"
  engine               = "postgres"
  engine_version       = "14"
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  storage_type         = "gp2"
  db_name              = "mydb"
  username             = var.db_username
  password             = var.db_password
  parameter_group_name = aws_db_parameter_group.postgres.name
  skip_final_snapshot  = true

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.private.name
}

resource "aws_db_parameter_group" "postgres" {
  family = "postgres14"
  name   = "postgres-params"

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }
}

resource "aws_db_subnet_group" "private" {
  name       = "private-subnet-group"
  subnet_ids = module.vpc.private_subnets
}

# GeoJSON Data Bucket (this is what your app uses)
resource "aws_s3_bucket" "geojson_data" {
  bucket        = "asterra-geojson-data-${random_string.bucket_suffix.result}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "geojson_data" {
  bucket = aws_s3_bucket.geojson_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_iam_role" "s3_access" {
  name = "s3-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "s3_access" {
  name = "s3-access-policy"
  role = aws_iam_role.s3_access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.geojson_data.arn,
          "${aws_s3_bucket.geojson_data.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_security_group" "bastion" {
  name        = "bastion-security-group"
  description = "Security group for bastion host"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Bastion Security Group"
  }
}

resource "aws_instance" "bastion" {
  ami           = "ami-0767046d1677be5a0"
  instance_type = "t2.micro"
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.bastion.id]
  subnet_id              = module.vpc.public_subnets[0]
  
  associate_public_ip_address = true

  user_data_base64 = base64encode(templatefile("${path.module}/scripts/bastion_setup.sh", {
    db_host     = split(":", aws_db_instance.postgres.endpoint)[0]
    db_user     = var.db_username
    db_password = var.db_password
    db_name     = aws_db_instance.postgres.db_name
  }))

  depends_on = [
    aws_db_instance.postgres,
    aws_security_group_rule.rds_from_ecs
  ]

  tags = {
    Name = "Bastion Host"
  }
}

resource "aws_iam_role_policy" "ecs_task_s3_policy" {
  name = "ecs-task-s3-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.geojson_data.arn,
          "${aws_s3_bucket.geojson_data.arn}/*"
        ]
      }
    ]
  })
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/geojson-s3-trigger"
  retention_in_days = 7
  skip_destroy      = false
}

# Lambda execution role
resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda-s3-trigger-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda policy for ECS and S3
resource "aws_iam_role_policy" "lambda_ecs_s3_policy" {
  name = "lambda-ecs-s3-policy"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask",
          "ecs:DescribeTasks"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          aws_iam_role.ecs_execution_role.arn,
          aws_iam_role.ecs_task_role.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.geojson_data.arn}/*"
      }
    ]
  })
}

# Create ZIP file for Lambda function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

# Lambda function to trigger ECS task when GeoJSON file is uploaded
resource "aws_lambda_function" "s3_trigger" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "geojson-s3-trigger"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  timeout         = 60
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      ECS_CLUSTER_NAME     = aws_ecs_cluster.main.name
      ECS_TASK_DEFINITION  = aws_ecs_task_definition.geojson_processor.family
      ECS_SUBNETS         = join(",", module.vpc.private_subnets)
      ECS_SECURITY_GROUPS = aws_security_group.ecs_tasks.id
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_logs]
}

# S3 bucket notification
resource "aws_s3_bucket_notification" "geojson_notification" {
  bucket = aws_s3_bucket.geojson_data.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_trigger.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".geojson"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

# Lambda permission for S3
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_trigger.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.geojson_data.arn
}