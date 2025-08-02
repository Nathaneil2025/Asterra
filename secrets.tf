terraform {
  # Backend configuration is now in backend.tf
  # No backend configuration here to avoid duplicates
}

variable "db_password" {
  description = "Database password"
  type        = string
  default     = "Hello123"
  sensitive   = true
}