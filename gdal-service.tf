
# Security Group for GDAL Service
resource "aws_security_group" "gdal_service" {
  name        = "gdal-service-sg"
  description = "Security group for GDAL service"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["192.168.0.0/16"] # Allow SSH access from 192.168.0.0/16
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
  ami           = "ami-01c79f8fca6bc28c3" # Replace with a suitable AMI
  instance_type = "t4g.micro"
  subnet_id     = module.vpc.private_subnets[0] # Deploy in a private subnet
  vpc_security_group_ids = [aws_security_group.gdal_service.id] # Use vpc_security_group_ids

  tags = {
    Name = "GDAL Service Instance"
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install -y gdal-bin
              # Add any additional setup or scripts here
              EOF
}