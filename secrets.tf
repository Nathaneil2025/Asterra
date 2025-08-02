terraform {
  # backend "s3" {
  #   bucket = "my-terraform-state-bucket"
  #   key    = "terraform.tfstate"
  #   region = "eu-central-1"
  # }
}

variable "db_password" {
  description = "Database password"
  type        = string
  default     = "Hello123"
  sensitive   = true
}