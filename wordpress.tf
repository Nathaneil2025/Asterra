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
              sudo apt update -y
              sudo apt install -y apache2 php php-mysql libapache2-mod-php
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
