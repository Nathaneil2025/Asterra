
# Security Group for GDAL Service
resource "aws_security_group" "gdal_service" {
  name        = "gdal-service-sg"
  description = "Security group for GDAL service"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow SSH access, restrict in production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "GDAL Service Security Group"
  }
}

# GDAL EC2 Instance
resource "aws_instance" "gdal_service" {
  ami           = "ami-0c55b159cbfafe1f0" # Replace with a suitable AMI
  instance_type = "t2.micro"
  subnet_id     = module.vpc.private_subnets[0] # Deploy in a private subnet
  security_groups = [aws_security_group.gdal_service.name]

  tags = {
    Name = "GDAL Service Instance"
  }

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y gdal
              # Add any additional setup or scripts here
              EOF
}