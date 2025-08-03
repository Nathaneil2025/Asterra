terraform {
  backend "s3" {
    bucket = "terraform-state-asterra-project"
    key    = "geojson-processor/terraform.tfstate"
    region = "eu-central-1"
    
    # State locking with DynamoDB table
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}