
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

# WordPress EC2 Instance
resource "aws_instance" "wordpress" {
  ami           = "ami-01c79f8fca6bc28c3" # Example AMI, replace with a suitable WordPress AMI
  instance_type = "t3.micro"
  subnet_id     = module.vpc.private_subnets[0]
  security_groups = [aws_security_group.wordpress_instance.name]

  tags = {
    Name = "WordPress Instance"
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install -y httpd php php-mysql
              cd /var/www/html
              wget https://wordpress.org/latest.tar.gz
              tar -xzf latest.tar.gz
              mv wordpress/* .
              rm -rf wordpress latest.tar.gz
              chown -R apache:apache /var/www/html
              systemctl enable httpd
              systemctl start httpd
              EOF
}

# Attach EC2 Instance to Target Group
resource "aws_lb_target_group_attachment" "wordpress" {
  target_group_arn = aws_lb_target_group.wordpress.arn
  target_id        = aws_instance.wordpress.id
  port             = 80
}

# Create WordPress database
resource "aws_db_instance" "wordpress" {
  identifier     = "wordpress-db"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"
  
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp2"
  storage_encrypted     = false

  db_name  = "wordpress"
  username = var.db_username
  password = var.db_password

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.private.name
  
  backup_retention_period = 0
  skip_final_snapshot    = true

  tags = {
    Name = "WordPress Database"
  }
}