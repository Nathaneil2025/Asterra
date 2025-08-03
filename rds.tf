
# Add this ingress rule to your existing RDS security group
resource "aws_security_group_rule" "rds_mysql_from_wordpress" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.wordpress_instance.id # Correct reference
  security_group_id        = aws_security_group.rds.id
}