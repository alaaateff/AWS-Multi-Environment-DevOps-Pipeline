terraform {
  backend "s3" {
    bucket         = "mys3-state-file"
    key            = "terraform/state/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock-table"
  }
}