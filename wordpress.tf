# WordPress EC2 Instance
resource "aws_instance" "wordpress" {
  ami           = "ami-01c79f8fca6bc28c3" # Example AMI, replace with a suitable WordPress AMI
  instance_type = "t4g.micro"
  subnet_id     = module.vpc.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.wordpress_instance.id] # Use vpc_security_group_ids
  key_name      = "Frankfurt" # Specify the key pair
  tags = {
    Name = "WordPress Instance"
  }

  user_data=<<-EOF
#!/bin/bash
sudo dnf update -y
sudo dnf install -y httpd php php-mysqli php-json php-fpm
sudo systemctl start httpd
sudo systemctl enable httpd

cd /var/www/html
sudo wget https://wordpress.org/latest.tar.gz
sudo tar -xzf latest.tar.gz
sudo mv wordpress/* .
sudo chown -R apache:apache /var/www/html

cat << EOM | sudo tee /etc/yum.repos.d/MariaDB.repo
[mariadb]
name = MariaDB
baseurl = https://mirrors.gigenet.com/mariadb/yum/11.4/rhel/9/aarch64
gpgkey = https://mirrors.gigenet.com/mariadb/yum/RPM-GPG-KEY-MariaDB
gpgcheck = 1
EOM

sudo dnf install -y MariaDB-server MariaDB-client MariaDB-devel
sudo systemctl restart httpd
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


# Application Load Balancer for WordPress
resource "aws_lb" "wordpress" {
  name               = "wordpress-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false

  tags = {
    Name = "WordPress ALB"
  }
}

# ALB Listener
resource "aws_lb_listener" "wordpress" {
  load_balancer_arn = aws_lb.wordpress.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress.arn
  }
}

# Target Group for WordPress
resource "aws_lb_target_group" "wordpress" {
  name        = "wordpress-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200,302"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "WordPress Target Group"
  }
}

# Attach EC2 Instance to Target Group
resource "aws_lb_target_group_attachment" "wordpress" {
  target_group_arn = aws_lb_target_group.wordpress.arn
  target_id        = aws_instance.wordpress.id
  port             = 80
}
