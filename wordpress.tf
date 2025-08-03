# WordPress EC2 Instance
resource "aws_instance" "wordpress" {
  ami           = "ami-01c79f8fca6bc28c3" # Example AMI, replace with a suitable WordPress AMI
  instance_type = "t4g.micro"
  subnet_id     = module.vpc.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.wordpress_instance.id] # Use vpc_security_group_ids

  tags = {
    Name = "WordPress Instance"
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo systemctl enable ssh
              sudo systemctl start ssh
              sudo apt install -y httpd php php-mysqlnd php-fpm php-json php-gd php-mbstring
              cd /var/www/html
              sudo wget https://wordpress.org/latest.tar.gz
              sudo tar -xzf latest.tar.gz
              sudo mv wordpress/* .
              sudo rm -rf wordpress latest.tar.gz
              sudo chown -R www-data:www-data /var/www/html
              sudo systemctl enable apache2
              sudo systemctl start apache2
              EOF
}


# Security Group for WordPress EC2 Instance
resource "aws_security_group" "wordpress_instance" {
  name        = "wordpress-instance-sg"
  description = "Security group for WordPress EC2 instance"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["192.168.0.0/16"] # Allow SSH from 192.168.0.0/16
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["192.168.0.0/16"] # Allow ICMP (ping) from 192.168.0.0/16
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "WordPress Instance Security Group"
  }
}

# Security Group for ALB
resource "aws_security_group" "alb" {
  name        = "wordpress-alb-sg"
  description = "Security group for WordPress ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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
    Name = "WordPress ALB Security Group"
  }
}