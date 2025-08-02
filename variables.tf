variable "docker_build_enabled" {
  description = "Whether to enable automatic Docker build and push"
  type        = bool
  default     = true
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "dbadmin"
}


variable "key_name" {
  description = "EC2 Key Pair name"
  type        = string
  default     = "Frankfurt"
}